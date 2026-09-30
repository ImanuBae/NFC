-- ============================================================================
-- Migration 0002: Liên kết tài khoản Kiosk/Nhân viên với Employee & RLS tự xem lịch sử
-- ============================================================================

-- 1. Thêm cột employee_id vào bảng profiles
alter table profiles add column if not exists employee_id uuid references employees(id) on delete set null;

-- 2. RLS: Cho phép nhân viên xem thông tin nhân viên của chính mình
drop policy if exists employee_read_own on employees;
create policy employee_read_own on employees
  for select using (
    id in (select employee_id from profiles where id = auth.uid())
  );

-- 3. RLS: Cho phép nhân viên xem lịch sử chấm công của chính mình
drop policy if exists employee_own_events on attendance_events;
create policy employee_own_events on attendance_events
  for select using (
    employee_id in (
      select employee_id from profiles where id = auth.uid() and employee_id is not null
    )
  );

-- 4. RLS: Cho phép nhân viên xem thẻ của chính mình
drop policy if exists employee_own_cards on cards;
create policy employee_own_cards on cards
  for select using (
    employee_id in (
      select employee_id from profiles where id = auth.uid() and employee_id is not null
    )
  );

-- 5. Cho phép user cập nhật employee_id trên profile của chính mình
drop policy if exists update_own_profile on profiles;
create policy update_own_profile on profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

-- 6. Cho phép admin cập nhật cột employee_id trên profiles của mọi người
drop policy if exists admin_update_profiles on profiles;
create policy admin_update_profiles on profiles
  for all using (public.is_admin()) with check (public.is_admin());
