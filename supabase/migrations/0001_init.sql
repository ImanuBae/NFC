-- ===== Types =====
create type event_type as enum ('check_in', 'check_out');
create type user_role  as enum ('admin', 'kiosk');

-- ===== Tables =====
create table profiles (
  id   uuid primary key references auth.users(id) on delete cascade,
  role user_role not null
);

create table employees (
  id         uuid primary key default gen_random_uuid(),
  code       text unique not null,
  full_name  text not null,
  active     boolean not null default true,
  created_at timestamptz not null default now()
);

create table cards (
  uid         text primary key,               -- HEX in hoa, không dấu phân cách
  employee_id uuid not null references employees(id),
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

create table devices (
  id      uuid primary key default gen_random_uuid(),
  name    text not null,
  site_id text not null default 'main',
  active  boolean not null default true
);

create table attendance_events (
  id              uuid primary key default gen_random_uuid(),
  client_scan_id  uuid unique,                -- idempotency cho replay
  employee_id     uuid not null references employees(id),
  device_id       uuid references devices(id),
  type            event_type not null,
  occurred_at     timestamptz not null,
  device_time     timestamptz,
  received_at     timestamptz not null default now(),
  source          text not null default 'nfc' check (source in ('nfc', 'manual')),
  flag            text,                       -- ví dụ 'missing_checkout'
  created_by      uuid references auth.users(id),
  voided_at       timestamptz,
  voided_by       uuid references auth.users(id),
  void_reason     text
);
create index on attendance_events (employee_id, occurred_at desc);

create table scan_rejections (
  id          bigint generated always as identity primary key,
  uid         text not null,
  device_id   uuid references devices(id),
  reason      text not null,
  occurred_at timestamptz not null
);

create table settings (
  key   text primary key,
  value text not null
);
insert into settings(key, value) values
  ('work_start', '08:30'),
  ('tz', 'Asia/Ho_Chi_Minh'),
  ('debounce_seconds', '60'),
  ('max_session_hours', '16')
on conflict (key) do nothing;

-- ===== Helpers =====
create or replace function public.has_role(r user_role) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and role = r)
$$;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select public.has_role('admin')
$$;

-- ===== RPC: ghi một lần quẹt (logic nằm ở server) =====
create or replace function public.record_scan(
  p_uid            text,
  p_device_id      uuid,
  p_device_time    timestamptz,
  p_client_scan_id uuid,
  p_is_replay      boolean default false
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_now       timestamptz := now();
  v_at        timestamptz;
  v_emp       record;
  v_last      record;
  v_has_last  boolean := false;
  v_type      event_type;
  v_debounce  int;
  v_max_hours int;
begin
  if not (public.has_role('kiosk') or public.is_admin()) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  if exists (select 1 from attendance_events where client_scan_id = p_client_scan_id) then
    return jsonb_build_object('status', 'duplicate');
  end if;

  v_at := case when p_is_replay
               then least(coalesce(p_device_time, v_now), v_now)
               else v_now end;

  select e.id, e.code, e.full_name into v_emp
  from cards c join employees e on e.id = c.employee_id
  where c.uid = upper(p_uid) and c.active and e.active;

  if not found then
    insert into scan_rejections(uid, device_id, reason, occurred_at)
    values (upper(p_uid), p_device_id, 'unknown_or_inactive_card', v_at);
    return jsonb_build_object('status', 'rejected', 'reason', 'unknown_or_inactive_card');
  end if;

  select value::int into v_debounce  from settings where key = 'debounce_seconds';
  select value::int into v_max_hours from settings where key = 'max_session_hours';

  select id, type, occurred_at into v_last
  from attendance_events
  where employee_id = v_emp.id and voided_at is null and occurred_at <= v_at
  order by occurred_at desc limit 1;
  v_has_last := found;

  if v_has_last and (v_at - v_last.occurred_at) < make_interval(secs => v_debounce) then
    return jsonb_build_object('status', 'ignored', 'employee_name', v_emp.full_name);
  end if;

  if v_has_last and v_last.type = 'check_in' then
    if (v_at - v_last.occurred_at) <= make_interval(hours => v_max_hours) then
      v_type := 'check_out';
    else
      v_type := 'check_in';
      update attendance_events set flag = 'missing_checkout' where id = v_last.id;
    end if;
  else
    v_type := 'check_in';
  end if;

  insert into attendance_events
    (client_scan_id, employee_id, device_id, type, occurred_at, device_time, source)
  values
    (p_client_scan_id, v_emp.id, p_device_id, v_type, v_at, p_device_time, 'nfc');

  return jsonb_build_object(
    'status', 'ok',
    'type', v_type,
    'employee_name', v_emp.full_name,
    'employee_code', v_emp.code,
    'occurred_at', v_at
  );
end $$;

-- ===== RPC: kiosk tự đăng ký thiết bị lần đầu =====
create or replace function public.register_device(p_name text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if not (public.has_role('kiosk') or public.is_admin()) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  insert into devices(name) values (p_name) returning id into v_id;
  return v_id;
end $$;

-- ===== Views (security_invoker để RLS áp dụng) =====
create view attendance_sessions with (security_invoker = true) as
select
  e.id          as check_in_event_id,
  e.employee_id,
  e.occurred_at as check_in_at,
  (select min(o.occurred_at) from attendance_events o
    where o.employee_id = e.employee_id and o.type = 'check_out'
      and o.voided_at is null and o.occurred_at > e.occurred_at
      and o.occurred_at < coalesce(
        (select min(n.occurred_at) from attendance_events n
          where n.employee_id = e.employee_id and n.type = 'check_in'
            and n.voided_at is null and n.occurred_at > e.occurred_at),
        'infinity'::timestamptz)) as check_out_at,
  e.flag
from attendance_events e
where e.type = 'check_in' and e.voided_at is null;

create view attendance_days with (security_invoker = true) as
select
  s.employee_id,
  (s.check_in_at at time zone tz.v)::date as work_date,
  min(s.check_in_at)  as first_in,
  max(s.check_out_at) as last_out,
  coalesce(sum(extract(epoch from (s.check_out_at - s.check_in_at)) / 60)
           filter (where s.check_out_at is not null), 0)::int as worked_minutes,
  bool_or(s.check_out_at is null) as missing_checkout,
  ((min(s.check_in_at) at time zone tz.v)::time > w.v::time) as is_late
from attendance_sessions s
cross join (select value as v from settings where key = 'tz') tz
cross join (select value as v from settings where key = 'work_start') w
group by s.employee_id, (s.check_in_at at time zone tz.v)::date, tz.v, w.v;

-- ===== RLS: chỉ admin đụng bảng trực tiếp; kiosk chỉ gọi RPC =====
alter table profiles          enable row level security;
alter table employees         enable row level security;
alter table cards             enable row level security;
alter table devices           enable row level security;
alter table attendance_events enable row level security;
alter table scan_rejections   enable row level security;
alter table settings          enable row level security;

create policy own_profile on profiles for select using (id = auth.uid());
create policy admin_all on employees         for all using (public.is_admin()) with check (public.is_admin());
create policy admin_all on cards             for all using (public.is_admin()) with check (public.is_admin());
create policy admin_all on devices           for all using (public.is_admin()) with check (public.is_admin());
create policy admin_all on attendance_events for all using (public.is_admin()) with check (public.is_admin());
create policy admin_all on scan_rejections   for all using (public.is_admin()) with check (public.is_admin());
create policy admin_all on settings          for all using (public.is_admin()) with check (public.is_admin());
