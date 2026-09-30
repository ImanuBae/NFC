-- ============================================================================
-- Migration 0003: Cấu hình ca làm việc cố định 09:00 - 18:00 & liên kết nhân viên
-- ============================================================================

-- 1. Cập nhật khung giờ cố định trong bảng settings
insert into settings (key, value) values
  ('work_start', '09:00'),
  ('work_end', '18:00')
on conflict (key) do update set value = excluded.value;

-- 2. Cho phép người dùng đọc danh sách nhân viên để liên kết
drop policy if exists allow_read_employees on employees;
create policy allow_read_employees on employees for select using (true);

-- 3. Tự động liên kết tài khoản Kiosk hiện có với nhân viên NV01 (Nguyễn Phạm Hoài Hiếu)
update profiles
set employee_id = (select id from employees where code = 'NV01' limit 1)
where role = 'kiosk' and employee_id is null;

-- 4. Cập nhật View attendance_days tính toán Đi trễ (> 09:00) và Về sớm (< 18:00)
create or replace view attendance_days with (security_invoker = true) as
select
  s.employee_id,
  (s.check_in_at at time zone tz.v)::date as work_date,
  min(s.check_in_at) as first_in,
  max(s.check_out_at) as last_out,
  coalesce(sum(extract(epoch from (s.check_out_at - s.check_in_at)) / 60)
           filter (where s.check_out_at is not null), 0)::int as worked_minutes,
  bool_or(s.check_out_at is null) as missing_checkout,
  ((min(s.check_in_at) at time zone tz.v)::time > ws.v::time) as is_late,
  coalesce(((max(s.check_out_at) at time zone tz.v)::time < we.v::time), false) as is_early_leave
from attendance_sessions s
cross join (select value as v from settings where key = 'tz') tz
cross join (select value as v from settings where key = 'work_start') ws
cross join (select value as v from settings where key = 'work_end') we
group by s.employee_id, (s.check_in_at at time zone tz.v)::date, tz.v, ws.v, we.v;
