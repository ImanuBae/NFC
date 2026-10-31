import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'business_repository.dart';
import 'report_period.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});
  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  ReportPeriod _period = ReportPeriod.month;
  DateTime _date = DateTime.now();
  late Future<List<Map<String, dynamic>>> _report;
  bool _busy = false;
  final _money = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );
  ReportRange get _range => ReportRange.forDate(_date, _period);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final range = _range;
    _report = ref
        .read(businessRepositoryProvider)
        .report(range.startDate, range.endDate);
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _email(List<Map<String, dynamic>> rows) async {
    final range = _range;
    setState(() => _busy = true);
    var sent = 0;
    final errors = <String>[];
    try {
      for (final row in rows) {
        try {
          await ref.read(businessRepositoryProvider).action('email_report', {
            'employee_id': row['employee_id'],
            'start': range.startDate,
            'end': range.endDate,
          });
          sent++;
        } catch (e) {
          errors.add('${row['code']}: $e');
        }
        if (!mounted) break;
      }
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Đã xử lý $sent/${rows.length} báo cáo'),
            content: SingleChildScrollView(
              child: Text(
                errors.isEmpty
                    ? 'Báo cáo đã gửi hoặc đã được gửi trước đó.'
                    : errors.join('\n'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _closePayroll() async {
    final range = _range;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chốt bảng lương?'),
        content: Text(
          'Kỳ ${range.label}. Số giờ và đơn giá hiện tại sẽ được lưu cố định. '
          'Sau khi chốt không thể sửa chấm công thuộc kỳ này. Chỉ chốt sau khi đối soát đầy đủ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Chốt lương'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(businessRepositoryProvider)
          .closePayroll(range.startDate, _period.name);
      _message('Đã lưu bảng lương kỳ ${range.label}.');
    } catch (e) {
      _message('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _payrollHistory() async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(businessRepositoryProvider);
      final runs = await repo.payrollRuns();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Bảng lương đã chốt'),
          content: SizedBox(
            width: 600,
            child: runs.isEmpty
                ? const Text('Chưa có bảng lương.')
                : ListView(
                    shrinkWrap: true,
                    children: runs
                        .map(
                          (run) => ListTile(
                            title: Text(
                              '${run['start_date']} → ${run['end_date']} (không gồm ngày cuối)',
                            ),
                            subtitle: Text(
                              run['period'] == 'week'
                                  ? 'Theo tuần'
                                  : 'Theo tháng',
                            ),
                            onTap: () async {
                              try {
                                final items = await repo.payrollItems(
                                  runId: run['id'] as String,
                                );
                                if (!context.mounted) return;
                                await showDialog<void>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Chi tiết lương đã chốt'),
                                    content: SizedBox(
                                      width: 600,
                                      child: SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: items
                                              .map(
                                                (i) => ListTile(
                                                  title: Text(
                                                    '${i['employee_code']} · ${i['employee_name']}',
                                                  ),
                                                  subtitle: Text(
                                                    '${(num.parse('${i['worked_minutes']}') / 60).toStringAsFixed(2)} giờ × ${_money.format(num.parse('${i['hourly_rate']}'))}/giờ',
                                                  ),
                                                  trailing: Text(
                                                    _money.format(
                                                      num.parse(
                                                        '${i['gross_pay']}',
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Đóng'),
                                      ),
                                    ],
                                  ),
                                );
                              } catch (e) {
                                _message('$e');
                              }
                            },
                          ),
                        )
                        .toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    } catch (e) {
      _message('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Thống kê & tính lương'),
      actions: [
        IconButton(
          onPressed: _busy ? null : _payrollHistory,
          icon: const Icon(Icons.receipt_long),
          tooltip: 'Lương đã chốt',
        ),
        IconButton(
          onPressed: _busy ? null : () => setState(_reload),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<ReportPeriod>(
                value: _period,
                items: const [
                  DropdownMenuItem(
                    value: ReportPeriod.week,
                    child: Text('Tuần'),
                  ),
                  DropdownMenuItem(
                    value: ReportPeriod.month,
                    child: Text('Tháng'),
                  ),
                  DropdownMenuItem(
                    value: ReportPeriod.quarter,
                    child: Text('Quý'),
                  ),
                  DropdownMenuItem(
                    value: ReportPeriod.year,
                    child: Text('Năm'),
                  ),
                ],
                onChanged: _busy
                    ? null
                    : (v) {
                        if (v != null) {
                          setState(() {
                            _period = v;
                            _reload();
                          });
                        }
                      },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.date_range),
                label: Text(_range.label),
                onPressed: _busy
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null && mounted) {
                          setState(() {
                            _date = picked;
                            _reload();
                          });
                        }
                      },
              ),
              if (_period == ReportPeriod.week || _period == ReportPeriod.month)
                FilledButton.icon(
                  onPressed: _busy ? null : _closePayroll,
                  icon: const Icon(Icons.lock),
                  label: const Text('Chốt lương'),
                ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Giờ Việt Nam · Lương gộp dự kiến = giờ đủ vào/ra × đơn giá hiện tại. '
            'Không trừ thuế, bảo hiểm hoặc giờ nghỉ. Lương đã chốt nằm trong lịch sử.',
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _report,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Không tải được báo cáo: ${snapshot.error}'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final rows = snapshot.data!;
              if (rows.isEmpty) {
                return const Center(child: Text('Chưa có nhân viên trong kỳ.'));
              }
              final total = rows.fold<num>(
                0,
                (sum, row) => sum + num.parse('${row['gross_pay']}'),
              );
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ListTile(
                    title: Text(
                      '${rows.length} nhân viên · Tổng lương dự kiến: ${_money.format(total)}',
                    ),
                    trailing: IconButton(
                      onPressed: _busy ? null : () => _email(rows),
                      icon: const Icon(Icons.outgoing_mail),
                      tooltip: 'Gửi cho từng nhân viên',
                    ),
                  ),
                  ...rows.map(
                    (row) => Card(
                      child: ListTile(
                        title: Text('${row['code']} · ${row['full_name']}'),
                        subtitle: Text(
                          '${row['days_worked']} ngày · ${(num.parse('${row['worked_minutes']}') / 60).toStringAsFixed(2)} giờ\n'
                          'Trễ: ${row['late_days']} · Về sớm: ${row['early_days']} · Thiếu ra: ${row['missing_checkout']}\n'
                          'Đơn giá: ${_money.format(num.parse('${row['hourly_rate']}'))}/giờ · Lương: ${_money.format(num.parse('${row['gross_pay']}'))}',
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          onPressed: _busy ? null : () => _email([row]),
                          icon: const Icon(Icons.email_outlined),
                          tooltip: 'Gửi báo cáo qua email',
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}
