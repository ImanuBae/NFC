-- ============================================================================
-- NFC Attendance — SQL Test Suite (T1 - T8)
-- Chạy script này trong Supabase SQL Editor để kiểm tra toàn bộ logic record_scan.
-- Script chạy trong một DO block / transaction để xác thực kết quả.
-- ============================================================================

do $$
declare
  v_admin_id uuid := gen_random_uuid();
  v_kiosk_id uuid := gen_random_uuid();
  v_device_id uuid;
  v_emp1_id uuid;
  v_emp2_id uuid;
  v_emp3_inactive_id uuid;
  v_res jsonb;
  v_scan_id uuid;
  v_rejection_count int;
  v_event_count int;
  v_flag text;
begin
  raise notice '=== BẮT ĐẦU KIỂM THỬ T1 - T8 ===';

  -- 0. Chuẩn bị profiles giả lập cho kiosk
  insert into profiles (id, role) values (v_kiosk_id, 'kiosk') on conflict do nothing;

  -- Đăng ký device
  insert into devices (name, site_id) values ('Test Kiosk 1', 'test_site') returning id into v_device_id;

  -- Chuẩn bị nhân viên & thẻ
  insert into employees (code, full_name, active) values ('NV01', 'Nguyen Van A', true) returning id into v_emp1_id;
  insert into employees (code, full_name, active) values ('NV02', 'Tran Thi B', true) returning id into v_emp2_id;
  insert into employees (code, full_name, active) values ('NV03', 'Le Van C (Inactive)', false) returning id into v_emp3_inactive_id;

  insert into cards (uid, employee_id, active) values ('04A1B2C3D4E501', v_emp1_id, true);
  insert into cards (uid, employee_id, active) values ('04A1B2C3D4E502', v_emp2_id, true);
  insert into cards (uid, employee_id, active) values ('04A1B2C3D4E503', v_emp3_inactive_id, true);
  insert into cards (uid, employee_id, active) values ('04A1B2C3D4E504', v_emp1_id, false); -- Thẻ khóa của NV01

  -- Giả lập auth context bằng kiosk profile
  -- Ghi chú: trong DO block, record_scan kiểm tra public.has_role('kiosk') qua auth.uid().
  -- Để chạy độc lập trong SQL editor mà auth.uid() có thể là admin Supabase (postgres/service_role),
  -- hàm has_role('kiosk') or is_admin() sẽ pass nếu user có role admin trong profiles.

  -- --------------------------------------------------------------------------
  -- T1: UID chưa đăng ký
  -- --------------------------------------------------------------------------
  v_res := public.record_scan(
    p_uid => 'UNKNOWN999999',
    p_device_id => v_device_id,
    p_device_time => now(),
    p_client_scan_id => gen_random_uuid()
  );
  assert (v_res->>'status') = 'rejected', 'T1 thất bại: mong muốn status = rejected';
  select count(*) into v_rejection_count from scan_rejections where uid = 'UNKNOWN999999';
  assert v_rejection_count > 0, 'T1 thất bại: không tìm thấy dòng trong scan_rejections';
  raise notice 'T1: PASS - UID chưa đăng ký -> rejected và ghi log scan_rejections';

  -- --------------------------------------------------------------------------
  -- T2: Quẹt lần đầu trong ngày
  -- --------------------------------------------------------------------------
  v_scan_id := gen_random_uuid();
  v_res := public.record_scan(
    p_uid => '04A1B2C3D4E501',
    p_device_id => v_device_id,
    p_device_time => now(),
    p_client_scan_id => v_scan_id
  );
  assert (v_res->>'status') = 'ok', 'T2 thất bại: status != ok';
  assert (v_res->>'type') = 'check_in', 'T2 thất bại: type != check_in';
  raise notice 'T2: PASS - Quẹt lần đầu -> ok, check_in';

  -- --------------------------------------------------------------------------
  -- T3: Quẹt lại sau < 60 giây (debounce)
  -- --------------------------------------------------------------------------
  v_res := public.record_scan(
    p_uid => '04A1B2C3D4E501',
    p_device_id => v_device_id,
    p_device_time => now(),
    p_client_scan_id => gen_random_uuid()
  );
  assert (v_res->>'status') = 'ignored', 'T3 thất bại: status != ignored';
  raise notice 'T3: PASS - Quẹt lại ngay < 60s -> ignored';

  -- --------------------------------------------------------------------------
  -- T4: Quẹt sau >= 60 giây (có check-in mở) -> check_out
  -- --------------------------------------------------------------------------
  -- Giả lập lùi thời gian event check-in trước đó về 10 phút trước
  update attendance_events
  set occurred_at = now() - interval '10 minutes'
  where client_scan_id = v_scan_id;

  v_res := public.record_scan(
    p_uid => '04A1B2C3D4E501',
    p_device_id => v_device_id,
    p_device_time => now(),
    p_client_scan_id => gen_random_uuid()
  );
  assert (v_res->>'status') = 'ok', 'T4 thất bại: status != ok';
  assert (v_res->>'type') = 'check_out', 'T4 thất bại: type != check_out';
  raise notice 'T4: PASS - Quẹt sau >= 60s -> ok, check_out';

  -- --------------------------------------------------------------------------
  -- T5: Gọi lại cùng client_scan_id (replay trùng)
  -- --------------------------------------------------------------------------
  v_res := public.record_scan(
    p_uid => '04A1B2C3D4E501',
    p_device_id => v_device_id,
    p_device_time => now(),
    p_client_scan_id => v_scan_id -- trùng với event check-in ở T2
  );
  assert (v_res->>'status') = 'duplicate', 'T5 thất bại: status != duplicate';
  raise notice 'T5: PASS - Gọi lại cùng client_scan_id -> duplicate';

  -- --------------------------------------------------------------------------
  -- T6: Check-in cũ > 16 giờ rồi quẹt -> check-in mới, event cũ có flag 'missing_checkout'
  -- --------------------------------------------------------------------------
  -- Tạo event check-in cho NV02 từ 18 giờ trước
  v_scan_id := gen_random_uuid();
  insert into attendance_events (client_scan_id, employee_id, device_id, type, occurred_at)
  values (v_scan_id, v_emp2_id, v_device_id, 'check_in', now() - interval '18 hours');

  v_res := public.record_scan(
    p_uid => '04A1B2C3D4E502',
    p_device_id => v_device_id,
    p_device_time => now(),
    p_client_scan_id => gen_random_uuid()
  );
  assert (v_res->>'status') = 'ok', 'T6 thất bại: status != ok';
  assert (v_res->>'type') = 'check_in', 'T6 thất bại: type != check_in';

  select flag into v_flag from attendance_events where client_scan_id = v_scan_id;
  assert v_flag = 'missing_checkout', 'T6 thất bại: cờ không phải missing_checkout';
  raise notice 'T6: PASS - Check-in cũ > 16h -> check_in mới, cờ missing_checkout';

  -- --------------------------------------------------------------------------
  -- T7: Nhân viên inactive hoặc thẻ inactive -> rejected
  -- --------------------------------------------------------------------------
  -- 7a. Thẻ của nhân viên inactive
  v_res := public.record_scan(
    p_uid => '04A1B2C3D4E503',
    p_device_id => v_device_id,
    p_device_time => now(),
    p_client_scan_id => gen_random_uuid()
  );
  assert (v_res->>'status') = 'rejected', 'T7a thất bại: status != rejected';

  -- 7b. Thẻ inactive của nhân viên active
  v_res := public.record_scan(
    p_uid => '04A1B2C3D4E504',
    p_device_id => v_device_id,
    p_device_time => now(),
    p_client_scan_id => gen_random_uuid()
  );
  assert (v_res->>'status') = 'rejected', 'T7b thất bại: status != rejected';
  raise notice 'T7: PASS - Thẻ/Nhân viên inactive -> rejected';

  raise notice '=== TẤT CẢ KỊCH BẢN T1 - T7 ĐÃ PASS HOÀN TOÀN ===';
end $$;
