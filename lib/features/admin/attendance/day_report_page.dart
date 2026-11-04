import '../../../core/widgets/page_header.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/strings.dart';
import '../../../core/widgets/work_summary_card.dart';
import 'attendance_models.dart';
import 'attendance_repository.dart';
import 'ticket_overview.dart';

class SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();
  void setDate(DateTime date) => state = date;
}

final selectedDateProvider = NotifierProvider<SelectedDateNotifier, DateTime>(
  SelectedDateNotifier.new,
);

final dayReportProvider = FutureProvider.autoDispose<List<DayReportItem>>((
  ref,
) async {
  final repo = ref.watch(attendanceRepositoryProvider);
  final date = ref.watch(selectedDateProvider);
  Timer? refresh;
  ref.onDispose(() => refresh?.cancel());
  try {
    return await repo.getDayReport(date);
  } finally {
    // Schedule after completion so slow connections never overlap requests.
    if (ref.mounted) {
      refresh = Timer(const Duration(seconds: 2), ref.invalidateSelf);
    }
  }
}, retry: (_, _) => null); // The polling timer also handles failed requests.

class DayReportPage extends ConsumerStatefulWidget {
  const DayReportPage({super.key});
  @override
  ConsumerState<DayReportPage> createState() => _DayReportPageState();
}

class _DayReportPageState extends ConsumerState<DayReportPage> {
  final Set<String> _seen = {};
  final Map<String, DateTime> _latestAt = {};
  String? _baselineDate;
  final List<DayReportItem> _notices = [];
  final Map<String, Timer> _noticeTimers = {};
  bool _initialized = false;
  String _filter = 'Tất cả';
  String _query = '';
  final _search = TextEditingController();

  @override
  void dispose() {
    _clearNotices();
    _search.dispose();
    super.dispose();
  }

  void _clearNotices() {
    for (final timer in _noticeTimers.values) {
      timer.cancel();
    }
    _noticeTimers.clear();
    _notices.clear();
  }

  void _dismissNotice(String id) {
    _noticeTimers.remove(id)?.cancel();
    setState(() => _notices.removeWhere((item) => item.lastEventId == id));
  }

  void _showNotices(List<DayReportItem> items) {
    setState(() {
      _notices.insertAll(0, items);
      while (_notices.length > 3) {
        _noticeTimers.remove(_notices.removeLast().lastEventId)?.cancel();
      }
      for (final item in _notices) {
        final id = item.lastEventId!;
        _noticeTimers.putIfAbsent(
          id,
          () => Timer(const Duration(seconds: 8), () => _dismissNotice(id)),
        );
      }
    });
  }

  String _time(DateTime? value) =>
      value == null ? '--:--' : DateFormat('HH:mm').format(value);

  @override
  Widget build(BuildContext context) {
    final date = ref.watch(selectedDateProvider);
    final key = DateFormat('yyyy-MM-dd').format(date);
    if (_baselineDate != key) {
      _baselineDate = key;
      _seen.clear();
      _latestAt.clear();
      _initialized = false;
      _clearNotices();
    }
    ref.listen(dayReportProvider, (_, next) {
      if (next.isLoading || next.hasError || !next.hasValue) return;
      final items = next.requireValue;
      final fresh =
          items
              .where(
                (i) =>
                    i.lastEventId != null &&
                    !_seen.contains(i.lastEventId) &&
                    (i.lastEventAt == null ||
                        _latestAt[i.employeeId] == null ||
                        !i.lastEventAt!.isBefore(_latestAt[i.employeeId]!)),
              )
              .toList()
            ..sort(
              (a, b) => (b.lastEventAt ?? DateTime(2000)).compareTo(
                a.lastEventAt ?? DateTime(2000),
              ),
            );
      if (_initialized && fresh.isNotEmpty) {
        _showNotices(fresh);
      }
      _seen.addAll(items.map((i) => i.lastEventId).whereType<String>());
      for (final item in items) {
        final at = item.lastEventAt;
        if (at != null &&
            (_latestAt[item.employeeId] == null ||
                at.isAfter(_latestAt[item.employeeId]!))) {
          _latestAt[item.employeeId] = at;
        }
      }
      _initialized = true;
    });
    final report = ref.watch(dayReportProvider);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                if (report.isRefreshing)
                  const LinearProgressIndicator(minHeight: 2),
                if (report.hasError && report.hasValue)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Chưa cập nhật được. Đang hiển thị dữ liệu lần tải trước.',
                    ),
                  ),
                Expanded(
                  child: report.when(
                    skipError: true,
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_outlined, size: 40),
                          const SizedBox(height: 12),
                          Text('${S.error}: $e'),
                          TextButton(
                            onPressed: () => ref.invalidate(dayReportProvider),
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
                    data: (items) {
                      final filtered = items.where((i) {
                        final textMatches =
                            '${i.employeeCode} ${i.employeeName}'
                                .toLowerCase()
                                .contains(_query.toLowerCase());
                        final statusMatches = switch (_filter) {
                          'Đang làm' => i.isInShift,
                          'Đi trễ' => i.isLate,
                          'Cần kiểm tra' => i.needsReview || i.missingCheckout,
                          'Chưa vào ca' => i.firstIn == null,
                          _ => true,
                        };
                        return textMatches && statusMatches;
                      }).toList();
                      final latest =
                          items.where((i) => i.lastEventAt != null).toList()
                            ..sort(
                              (a, b) =>
                                  b.lastEventAt!.compareTo(a.lastEventAt!),
                            );
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 1000;
                          final padding = constraints.maxWidth < 600
                              ? 16.0
                              : 28.0;
                          final scheme = Theme.of(context).colorScheme;
                          return RefreshIndicator(
                            onRefresh: () =>
                                ref.refresh(dayReportProvider.future),
                            child: ListView(
                              padding: EdgeInsets.all(padding),
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                PageHeader(
                                  title: 'Tổng quan chấm công',
                                  description: 'Theo dõi ca làm và các lượt chấm công mới.',
                                  action: OutlinedButton.icon(
                                    icon: const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 18,
                                    ),
                                    label: Text(
                                      DateFormat('dd/MM/yyyy').format(date),
                                    ),
                                    onPressed: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: date,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2035),
                                      );
                                      if (picked != null && mounted) {
                                        ref
                                            .read(selectedDateProvider.notifier)
                                            .setDate(picked);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const TicketOverview(),
                                const SizedBox(height: 20),
                                LayoutBuilder(
                                  builder: (context, box) {
                                    final columns = box.maxWidth < 650 ? 2 : 4;
                                    final width =
                                        (box.maxWidth - (columns - 1) * 12) /
                                        columns;
                                    return Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        SizedBox(
                                          width: width,
                                          child: MetricCard(
                                            label: 'Đang trong ca',
                                            value:
                                                '${items.where((i) => i.isInShift).length}',
                                            icon: Icons.work_outline,
                                            color: const Color(0xFF16805D),
                                          ),
                                        ),
                                        SizedBox(
                                          width: width,
                                          child: MetricCard(
                                            label: 'Đi trễ',
                                            value:
                                                '${items.where((i) => i.isLate).length}',
                                            icon: Icons.schedule_outlined,
                                            color: const Color(0xFFB46B13),
                                          ),
                                        ),
                                        SizedBox(
                                          width: width,
                                          child: MetricCard(
                                            label: 'Chưa vào ca',
                                            value:
                                                '${items.where((i) => i.firstIn == null).length}',
                                            icon: Icons.person_outline,
                                          ),
                                        ),
                                        SizedBox(
                                          width: width,
                                          child: MetricCard(
                                            label: 'Cần kiểm tra',
                                            value:
                                                '${items.where((i) => i.needsReview || i.missingCheckout).length}',
                                            icon: Icons.rule_outlined,
                                            color: scheme.error,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Bảng công trong ngày',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    Tooltip(
                                      message: 'Tự cập nhật khoảng 2 giây sau mỗi lần tải',
                                      child: Icon(
                                        Icons.sync,
                                        color: scheme.primary,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _search,
                                  onChanged: (value) =>
                                      setState(() => _query = value.trim()),
                                  decoration: const InputDecoration(
                                    prefixIcon: Icon(Icons.search),
                                    hintText: 'Tìm mã hoặc tên nhân viên',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children:
                                      [
                                            'Tất cả',
                                            'Đang làm',
                                            'Đi trễ',
                                            'Cần kiểm tra',
                                            'Chưa vào ca',
                                          ]
                                          .map(
                                            (value) => ChoiceChip(
                                              label: Text(value),
                                              selected: _filter == value,
                                              onSelected: (_) => setState(
                                                () => _filter = value,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Hiển thị ${filtered.length}/${items.length} nhân viên',
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (items.isEmpty)
                                  _empty(S.noAttendanceData)
                                else if (filtered.isEmpty)
                                  _empty(
                                    'Không có nhân viên phù hợp. Thử đổi bộ lọc hoặc từ khóa.',
                                  )
                                else if (wide)
                                  Card(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minWidth:
                                              constraints.maxWidth -
                                              padding * 2,
                                        ),
                                        child: DataTable(
                                          showCheckboxColumn: false,
                                          headingRowColor:
                                              WidgetStatePropertyAll(
                                                scheme.surfaceContainerLow,
                                              ),
                                          columns:
                                              const [
                                                    'Nhân viên',
                                                    'Trạng thái',
                                                    'Vào đầu tiên',
                                                    'Ra gần nhất',
                                                    'Đã làm',
                                                    'Còn thiếu',
                                                    'Dự kiến đủ công',
                                                    '',
                                                  ]
                                                  .map(
                                                    (v) => DataColumn(
                                                      label: Text(v),
                                                    ),
                                                  )
                                                  .toList(),
                                          rows: filtered
                                              .map(
                                                (item) => DataRow(
                                                  onSelectChanged: (_) =>
                                                      _details(item, key),
                                                  cells: [
                                                    DataCell(
                                                      Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            item.employeeName,
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                          ),
                                                          Text(
                                                            '${item.employeeCode}${item.lateMinutes > 0 ? ' · Trễ ${item.lateMinutes}p' : ''}',
                                                            style:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .textTheme
                                                                    .bodySmall,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    DataCell(
                                                      AttendanceStatus(item),
                                                    ),
                                                    DataCell(
                                                      Text(_time(item.firstIn)),
                                                    ),
                                                    DataCell(
                                                      Text(_time(item.lastOut)),
                                                    ),
                                                    DataCell(
                                                      Text(
                                                        item.workedDurationFormatted,
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Text(
                                                        attendanceDuration(
                                                          item.remainingMinutes,
                                                        ),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Text(
                                                        item.expectedCompletion ==
                                                                null
                                                            ? '--:--'
                                                            : _time(
                                                                item.expectedCompletion,
                                                              ),
                                                      ),
                                                    ),
                                                    const DataCell(
                                                      Icon(Icons.chevron_right),
                                                    ),
                                                  ],
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  ...filtered.map(
                                    (item) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: WorkSummaryCard(
                                        item: item,
                                        onTap: () => context.go(
                                          '/admin/events?employee_id=${item.employeeId}&date=$key',
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                Text(
                                  'Giờ đang làm là tạm tính. Chỉ các khoảng vào–ra hợp lệ được tính khi chốt lương.',
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                Text(
                                  'Hoạt động gần nhất',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Lượt gần nhất của mỗi nhân viên trong ngày đã chọn.',
                                ),
                                const SizedBox(height: 12),
                                if (latest.isEmpty)
                                  _empty('Chưa có lượt chấm công trong ngày.')
                                else
                                  Card(
                                    child: Column(
                                      children: latest
                                          .take(5)
                                          .map(
                                            (i) => ListTile(
                                              leading: CircleAvatar(
                                                backgroundColor:
                                                    scheme.primaryContainer,
                                                child: Icon(
                                                  i.lastEventSource ==
                                                          'face_camera'
                                                      ? Icons.face_outlined
                                                      : i.lastEventSource ==
                                                            'nfc'
                                                      ? Icons.nfc
                                                      : Icons.edit_outlined,
                                                ),
                                              ),
                                              title: Text(
                                                '${i.employeeCode} · ${i.employeeName}',
                                              ),
                                              subtitle: Text(
                                                '${i.lastEventType == 'check_in' ? 'Vào ca' : 'Ra ca'} · ${i.lastEventSource == 'face_camera'
                                                    ? 'Khuôn mặt'
                                                    : i.lastEventSource == 'nfc'
                                                    ? 'NFC'
                                                    : 'Điều chỉnh'}',
                                              ),
                                              trailing: Text(
                                                _time(i.lastEventAt),
                                              ),
                                              onTap: () => context.go(
                                                '/admin/events?employee_id=${i.employeeId}&date=$key',
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_notices.isNotEmpty)
            Positioned(
              top: 12,
              right: 12,
              left: MediaQuery.sizeOf(context).width < 600 ? 12 : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final item in _notices) _attendanceNotice(item),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _attendanceNotice(DayReportItem item) {
    final scheme = Theme.of(context).colorScheme;
    final face = item.lastEventSource == 'face_camera';
    final nfc = item.lastEventSource == 'nfc';
    final method = face
        ? 'Khuôn mặt'
        : nfc
        ? 'NFC'
        : 'Điều chỉnh';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        liveRegion: true,
        child: Material(
          key: ValueKey('attendance-notice-${item.lastEventId}'),
          elevation: 8,
          shadowColor: Colors.black26,
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  face
                      ? Icons.face_outlined
                      : nfc
                      ? Icons.nfc
                      : Icons.edit_outlined,
                  color: scheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Chấm công mới',
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.employeeCode} · ${item.employeeName}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Vừa ${item.lastEventType == 'check_in' ? 'vào ca' : 'ra ca'} bằng ${face
                            ? 'khuôn mặt'
                            : nfc
                            ? 'NFC'
                            : 'điều chỉnh'}',
                      ),
                      Text(
                        '${item.lastEventType == 'check_in' ? 'Vào ca' : 'Ra ca'} lúc ${_time(item.lastEventAt)} · $method',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng thông báo',
                  onPressed: () => _dismissNotice(item.lastEventId!),
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty(String message) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Column(
      children: [
        Icon(
          Icons.event_note_outlined,
          size: 36,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );

  void _details(DayReportItem item, String date) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                WorkSummaryCard(item: item),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Đóng'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          this.context.go(
                            '/admin/events?employee_id=${item.employeeId}&date=$date',
                          );
                        },
                        child: const Text('Xem lịch sử'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
