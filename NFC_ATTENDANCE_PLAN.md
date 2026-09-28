# NFC Attendance — Kế hoạch triển khai (Flutter / Dart)

> File này là spec cho coding agent. Làm **tuần tự theo milestone (mục 7)**. Không tự thêm tính năng ngoài phạm vi (mục 1).

## 0. Quy tắc làm việc cho agent

1. Đọc toàn bộ file trước khi viết code. Khi spec mơ hồ: chọn phương án đơn giản nhất, ghi lại quyết định trong `docs/DECISIONS.md` (1–2 dòng), không dừng lại hỏi.
2. Sau **mỗi milestone**: chạy `dart format .`, `flutter analyze` (0 lỗi/0 warning), `flutter test` (pass), rồi commit với message `M<n>: <tên milestone>`.
3. Chỉ dùng các package ở mục 2. Muốn thêm package khác: ghi lý do vào `docs/DECISIONS.md`.
4. **Không** commit secret. `SUPABASE_URL`, `SUPABASE_ANON_KEY` truyền qua `--dart-define`.
5. Không dùng code generation (freezed, json_serializable, riverpod_generator, build_runner). Model viết tay `fromJson`/`toJson`.
6. Mọi chuỗi UI (tiếng Việt) đặt trong `lib/core/strings.dart` (class `S` với `static const`). Không hard-code chuỗi trong widget.
7. Mỗi file Dart ≤ ~250 dòng; widget lớn tách thành widget nhỏ trong cùng feature.
8. Kiosk chỉ chạy Android. Phải chạy được **không cần phần cứng NFC** nhờ `FakeNfcService` (mục 5.2).
9. SQL ở mục 4 là bản tham chiếu: chạy thử trong Supabase SQL editor, sửa lỗi cú pháp nếu có, lưu bản cuối vào `supabase/migrations/0001_init.sql`.

## 1. Mục tiêu và phạm vi

**Sản phẩm:** kiosk Android đặt cố định ở cửa, nhân viên quẹt thẻ NFC → hệ thống ghi check-in/check-out tự động. Admin xem bảng công, quản lý nhân viên và thẻ.

**Demo:** 1 kiosk, 4 nhân viên/4 thẻ, 1 admin. Thiết kế dữ liệu sẵn cho nhiều thiết bị/chi nhánh (`devices`, `site_id`).

**Trong phạm vi:**
- Kiosk: đọc thẻ, phản hồi < 2 giây, chống quẹt đúp, hàng đợi offline + đồng bộ.
- Admin: đăng nhập, CRUD nhân viên, gán/khóa thẻ, bảng công theo ngày, xem event, sửa công thủ công (void + thêm event tay).
- Server là nguồn logic duy nhất (RPC `record_scan`).

**Ngoài phạm vi (KHÔNG làm):** app nhân viên, iOS, ca làm/tính lương, ảnh/PIN chống quẹt hộ, thẻ chống sao chép (NTAG 424 DNA), push notification, đa ngôn ngữ, xuất Excel.

**Tiêu chí thành công demo:** 4 người dùng 5 ngày liên tục; bảng công khớp ghi tay; mất mạng vẫn không mất event.

## 2. Quyết định kỹ thuật (đã chốt)

| Hạng mục | Chọn |
|---|---|
| Ngôn ngữ / framework | Dart 3.x, Flutter stable, Material 3 |
| Nền tảng | Android (minSdk 23). Admin chạy Android hoặc web/desktop (không có NFC thì nhập UID tay) |
| State management | `flutter_riverpod` (không codegen) |
| Điều hướng | `go_router` (redirect theo trạng thái đăng nhập + role) |
| Backend | `supabase_flutter` (Auth + Postgres + RPC) |
| NFC | `nfc_manager` (pin phiên bản, đọc README của đúng phiên bản để lấy UID) |
| Hàng đợi offline | `sqflite` + `path` |
| Cấu hình cục bộ | `shared_preferences` |
| Mạng | `connectivity_plus` |
| Khác | `uuid`, `intl` (locale `vi_VN`), `wakelock_plus` |
| Test | `flutter_test`, `mocktail` |

**Quy ước UID:** chữ HEX in hoa, không dấu phân cách (ví dụ `04A1B2C3D4E5F6`). Hàm `normalizeUid()` ở `core/uid.dart`, dùng ở mọi nơi.

**Thời gian:** server quyết định `occurred_at` cho quẹt online. Quẹt replay từ hàng đợi offline dùng `device_time` (bị chặn không vượt quá giờ server). Múi giờ hiển thị/tính công: `Asia/Ho_Chi_Minh`.

## 3. Cấu trúc thư mục

```
lib/
  main.dart
  app.dart                     # MaterialApp.router, theme
  core/
    config.dart                # đọc --dart-define
    strings.dart               # class S
    uid.dart                   # normalizeUid
    result.dart                # ScanResult (sealed)
    supabase_client.dart       # provider SupabaseClient
    router.dart                # go_router + redirect
    theme.dart
  features/
    auth/
      auth_repository.dart     # signIn, signOut, currentRole
      login_page.dart
    kiosk/
      nfc_service.dart         # interface + RealNfcService + FakeNfcService
      scan_coordinator.dart    # logic xử lý 1 lần quẹt
      pending_scan_store.dart  # sqflite
      sync_service.dart        # flush hàng đợi
      kiosk_setup_page.dart
      kiosk_idle_page.dart
      kiosk_result_view.dart
    admin/
      employees/               # list, form, repository
      cards/                   # assign_card_page, repository
      attendance/              # day_report_page, event_list_page, manual_edit_sheet, repository
      admin_shell.dart         # NavigationBar
supabase/
  migrations/0001_init.sql
docs/
  DECISIONS.md
test/
  ...
```

## 4. Backend — Supabase (tham chiếu SQL)

Tạo project Supabase, tạo 2 user trong Auth (admin, kiosk), rồi chạy migration.

```sql
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
  ('max_session_hours', '16');

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
        'infinity')) as check_out_at,
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

-- ===== Seed (thay UUID bằng id user thật trong Auth) =====
-- insert into profiles(id, role) values ('<admin-uid>', 'admin'), ('<kiosk-uid>', 'kiosk');
```

**Ghi chú backend:**
- Sửa công thủ công do admin làm bằng insert/update trực tiếp (RLS cho phép): void event sai (`voided_at`, `voided_by`, `void_reason`), thêm event `source='manual'`, `created_by = auth.uid()`, `client_scan_id = null`.
- Hạn chế đã biết: replay event lệch thứ tự thời gian có thể cho kết quả check-in/out sai → admin sửa tay (chấp nhận ở demo).

## 5. App — thiết kế chi tiết

### 5.1 Core
- `config.dart`: `const supabaseUrl = String.fromEnvironment('SUPABASE_URL')` và tương tự anon key. Nếu rỗng → màn hình lỗi cấu hình rõ ràng.
- `result.dart`:
  ```dart
  sealed class ScanResult {}
  class ScanOk extends ScanResult { final bool isCheckIn; final String name, code; final DateTime at; ... }
  class ScanRejected extends ScanResult { final String reason; ... }
  class ScanIgnored extends ScanResult { final String? name; ... }
  class ScanQueuedOffline extends ScanResult {}
  ```
  (`duplicate` từ server coi như thành công đã xử lý, không hiển thị gì khi replay.)
- `router.dart`: chưa đăng nhập → `/login`. Sau đăng nhập đọc `profiles.role`: `kiosk` → `/kiosk` (nếu chưa có `device_id` local thì `/kiosk/setup`), `admin` → `/admin/days`. Không cho kiosk vào `/admin/*` và ngược lại.

### 5.2 NFC service (`features/kiosk/nfc_service.dart`)
```dart
abstract class NfcService {
  Stream<String> get uids;        // UID đã normalize
  Future<bool> isAvailable();
  Future<void> start();
  Future<void> stop();
}
```
- `RealNfcService`: dùng `nfc_manager`, tự đọc README đúng phiên bản đã pin để lấy UID từ tag; đẩy `normalizeUid(...)` vào stream; sau mỗi tag đọc xong giữ session để quẹt tiếp (restart session nếu API yêu cầu). Xử lý NFC tắt/không hỗ trợ → `isAvailable()` false.
- `FakeNfcService`: `StreamController<String>` + hàm `emit(uid)`; dùng khi chạy emulator hoặc `--dart-define=FAKE_NFC=true`. Kiosk hiện thêm nút "Giả lập quẹt" (chỉ khi fake) với dropdown UID mẫu.
- Provider `nfcServiceProvider` chọn Real/Fake theo `FAKE_NFC`.
- Android: thêm `<uses-permission android:name="android.permission.NFC"/>` và `<uses-feature android:name="android.hardware.nfc" android:required="true"/>` vào `AndroidManifest.xml`.

### 5.3 Kiosk
**`ScanCoordinator.handleUid(String uid) → Future<ScanResult?>`** (thuần Dart, dễ test bằng fake):
1. `uid = normalizeUid(uid)`.
2. Cooldown cục bộ: cùng UID trong 3 giây → trả `null` (không hiện UI).
3. `id = const Uuid().v4()`, `deviceTime = DateTime.now().toUtc()`.
4. Gọi RPC `record_scan` với `p_is_replay=false`, timeout 5 giây.
5. Map JSON: `ok` → `ScanOk`, `rejected` → `ScanRejected`, `ignored` → `ScanIgnored`, `duplicate` → `null`.
6. Mọi exception (mạng, timeout, lỗi khác) → `PendingScanStore.enqueue(id, uid, deviceTime)` → `ScanQueuedOffline`.

**`KioskIdlePage`:**
- Bật `wakelock_plus`, khóa portrait, hiện đồng hồ lớn + dòng "Quẹt thẻ để chấm công" + chấm trạng thái (xanh online / vàng offline + số event chờ đồng bộ).
- Nghe `nfcService.uids` → `coordinator.handleUid` → hiện `KioskResultView` toàn màn hình 3 giây rồi về idle.
- Màu/nội dung result: `ScanOk` check-in = xanh lá "Xin chào, {name}" + giờ; check-out = xanh dương "Tạm biệt, {name}" + giờ; `ScanRejected` = đỏ "Thẻ không hợp lệ"; `ScanIgnored` = xám "Bạn vừa quẹt xong rồi"; `ScanQueuedOffline` = vàng "Đã ghi nhận (offline), sẽ đồng bộ".
- Nếu NFC không khả dụng: banner đỏ "NFC đang tắt" + nút mở cài đặt (hoặc hướng dẫn bật).
- Long-press 3 giây vào logo → dialog PIN cục bộ (hằng số `kioskExitPin` trong `config.dart`, mặc định `1234`, ghi chú đổi trước khi chạy thật) để đăng xuất/đổi thiết bị.

**`KioskSetupPage`:** lần đầu sau đăng nhập kiosk: nhập tên thiết bị → RPC `register_device` → lưu `device_id` vào `shared_preferences` (key `device_id`).

### 5.4 Hàng đợi offline
- `PendingScanStore` (sqflite), bảng `pending_scans(client_scan_id TEXT PRIMARY KEY, uid TEXT, device_time TEXT, created_at TEXT, attempts INTEGER DEFAULT 0, last_error TEXT)`. Hàm: `enqueue`, `listOrdered()` (theo `device_time` tăng dần), `remove(id)`, `markFailed(id, err)`, `count()` (stream để UI hiển thị số chờ).
- `SyncService`: chạy khi app khởi động, khi `connectivity_plus` báo có mạng lại, và mỗi 30 giây. Với từng item theo thứ tự: gọi `record_scan(..., p_is_replay: true, p_device_time: item.deviceTime)`. Nhận được JSON hợp lệ (bất kỳ `status`) → `remove`. Exception → `markFailed` (tăng `attempts`, giữ lại), dừng vòng hiện tại nếu lỗi mạng. Không xóa item dù `attempts` lớn; chỉ hiển thị cảnh báo khi `attempts >= 10`.
- Đảm bảo chỉ một vòng flush chạy tại một thời điểm (mutex/flag).

### 5.5 Admin
- `AdminShell`: `NavigationBar` 3 tab — Bảng công / Nhân viên / Sự kiện; nút đăng xuất.
- **Nhân viên:** list (tìm theo tên/mã, cờ active), form thêm/sửa (code, full_name, active). Trong chi tiết nhân viên: danh sách thẻ + nút "Gán thẻ".
- **Gán thẻ (`AssignCardPage`):** nút "Quẹt thẻ để đọc UID" dùng `NfcService` (Android) — hoặc ô nhập UID tay (luôn có, để test/web). Kiểm tra UID chưa tồn tại trong `cards` (lỗi rõ ràng nếu trùng) → insert. Có nút khóa/mở thẻ (`active`).
- **Bảng công ngày (`DayReportPage`):** chọn ngày (mặc định hôm nay), bảng từ view `attendance_days` join `employees`: tên, giờ vào, giờ ra, tổng giờ (`worked_minutes` → `Xh Ym`), badge "Trễ" (`is_late`), badge "Thiếu check-out" (`missing_checkout`). Bấm 1 dòng → `EventListPage` của nhân viên trong ngày đó.
- **Sự kiện (`EventListPage`):** danh sách `attendance_events` (loại, giờ, nguồn nfc/manual, cờ, đã void). Nút void (nhập lý do), nút "Thêm event tay" (chọn nhân viên, loại, thời điểm, lý do) → `ManualEditSheet`. Mọi thao tác ghi `voided_by`/`created_by`.
- Toàn bộ admin chỉ đọc/ghi qua repository (`EmployeeRepository`, `CardRepository`, `AttendanceRepository`) có interface để test bằng mock.

## 6. Màn hình và routes

| Route | Màn hình | Role |
|---|---|---|
| `/login` | Đăng nhập email/password | — |
| `/kiosk/setup` | Đặt tên thiết bị | kiosk |
| `/kiosk` | Idle + kết quả quẹt | kiosk |
| `/admin/days` | Bảng công ngày | admin |
| `/admin/employees` | Danh sách nhân viên | admin |
| `/admin/employees/:id` | Chi tiết + thẻ | admin |
| `/admin/employees/:id/assign-card` | Gán thẻ | admin |
| `/admin/events` | Danh sách sự kiện + sửa tay | admin |

## 7. Milestones (làm tuần tự)

### M0 — Scaffold
- [ ] `flutter create` (org `com.example`, chỉ platform android + web), cài package mục 2, dựng cấu trúc thư mục mục 3, `core/*` rỗng khung, theme M3, `docs/DECISIONS.md`.
- **Xong khi:** app chạy, hiện trang placeholder, `flutter analyze` sạch.

### M1 — Backend
- [ ] Lưu `supabase/migrations/0001_init.sql` (từ mục 4, đã sửa nếu lỗi), chạy trên project thật, tạo 2 user + `profiles`.
- [ ] Viết `supabase/tests.sql` chứa các kịch bản T1–T7 (mục 8) chạy được bằng SQL editor.
- **Xong khi:** T1–T7 cho kết quả đúng.

### M2 — Core + Auth + Router
- [ ] `config`, `supabase_client`, `AuthRepository`, `LoginPage`, `router` với redirect theo role, `strings.dart`.
- **Xong khi:** đăng nhập admin → `/admin/days`, kiosk → `/kiosk/setup`; đăng xuất hoạt động; sai mật khẩu hiện lỗi tiếng Việt.

### M3 — NFC + Kiosk online
- [ ] `normalizeUid` + unit test; `NfcService` (Real + Fake); `ScanCoordinator` (không offline); `KioskSetupPage`, `KioskIdlePage`, `KioskResultView` đủ 5 trạng thái.
- **Xong khi:** với `FAKE_NFC=true`, giả lập quẹt cho ra đúng 5 trạng thái; trên máy thật quẹt thẻ ra check-in/check-out đúng, < 2 giây.

### M4 — Offline queue
- [ ] `PendingScanStore`, `SyncService`, cập nhật `ScanCoordinator` (bước 6), chỉ báo online/offline + số chờ trên idle.
- **Xong khi:** tắt mạng → quẹt 3 lần (thẻ khác nhau) → hiện "offline", số chờ = 3 → bật mạng → trong ≤ 30 giây số chờ về 0 và DB có đủ 3 event với `occurred_at` = `device_time`; quẹt lại sau khi replay không tạo event trùng.

### M5 — Admin: nhân viên + thẻ
- [ ] Repository + màn hình nhân viên, gán thẻ (NFC + nhập tay), khóa/mở thẻ.
- **Xong khi:** thêm 4 nhân viên, gán 4 thẻ; UID trùng bị chặn; thẻ bị khóa quẹt ở kiosk ra "Thẻ không hợp lệ".

### M6 — Admin: bảng công + sửa tay
- [ ] `DayReportPage`, `EventListPage`, void + thêm event tay.
- **Xong khi:** bảng công hôm nay khớp với các lần quẹt; void 1 event → bảng công cập nhật; người quên check-out hiện badge "Thiếu check-out".

### M7 — Hardening + bàn giao demo
- [ ] Xử lý lỗi/empty/loading ở mọi màn hình; README (cách chạy, dart-define, tạo user, build APK: `flutter build apk --release --dart-define=...`); checklist triển khai kiosk (bật NFC, tắt ngủ máy, ghim màn hình, sạc liên tục).
- **Xong khi:** toàn bộ test mục 8 pass; APK release cài được và chạy trọn luồng.

## 8. Test plan

**SQL (`record_scan`) — chạy trên DB thật, mỗi ca dùng nhân viên/thẻ riêng:**

| # | Kịch bản | Kỳ vọng |
|---|---|---|
| T1 | UID chưa đăng ký | `rejected`, có dòng trong `scan_rejections` |
| T2 | Quẹt lần đầu trong ngày | `ok`, `type = check_in` |
| T3 | Quẹt lại sau < 60 giây | `ignored`, không tạo event |
| T4 | Quẹt sau ≥ 60 giây (có check-in mở) | `ok`, `type = check_out` |
| T5 | Gọi lại cùng `client_scan_id` | `duplicate`, không tạo event mới |
| T6 | Check-in cũ > 16 giờ rồi quẹt | check-in mới; event cũ có `flag = 'missing_checkout'` |
| T7 | Nhân viên `active=false` hoặc thẻ `active=false` | `rejected` |
| T8 | Gọi bằng user không có profile | lỗi `forbidden` |

**Dart (unit/widget, mock bằng `mocktail`):**
- `normalizeUid`: chuỗi có `:`/khoảng trắng/chữ thường → HEX in hoa liền.
- `ScanCoordinator`: cooldown 3 giây trả `null`; JSON `ok/rejected/ignored/duplicate` map đúng; exception → gọi `enqueue` và trả `ScanQueuedOffline`.
- `SyncService`: flush đúng thứ tự `device_time`; lỗi mạng giữ item; thành công xóa item; không chạy 2 vòng song song.
- Widget: `KioskResultView` hiển thị đúng màu/chữ theo từng `ScanResult`.
- Router: kiosk không vào được `/admin/*`, admin không vào được `/kiosk`.

**Thủ công trên thiết bị (nhật ký ghi vào `docs/MANUAL_TEST.md`):** 4 người quẹt vào/ra trong ngày; rút wifi giữa chừng; quẹt thẻ lạ; quẹt liên tục hai lần; khóa thẻ; quên check-out; khởi động lại máy kiosk (phải tự vào lại `/kiosk`, giữ hàng đợi).

## 9. Hướng mở rộng (chỉ để thiết kế không chặn đường, chưa làm)

- Nhiều kiosk/chi nhánh: đã có `devices`/`site_id`, thêm lọc theo site ở admin.
- Thẻ chống sao chép (NTAG 424 DNA): thêm xác thực mã động trong `record_scan`.
- Chống quẹt hộ: chụp ảnh khi quẹt hoặc PIN cá nhân.
- App nhân viên (xem công của mình), ca làm việc, xuất báo cáo, thiết bị đọc ESP32 + PN532 gọi cùng RPC `record_scan`.

## 10. Rủi ro đã biết (chấp nhận ở demo)

- UID thẻ có thể bị sao chép; thẻ có thể quẹt hộ.
- Offline không hiển thị được tên nhân viên (kiosk không có danh sách thẻ cục bộ).
- Replay lệch thứ tự có thể sai loại check-in/out; admin sửa tay.
- Kiosk là điểm đơn lỗi; hàng đợi offline chỉ bảo vệ khỏi mất mạng, không bảo vệ khỏi hỏng máy.
