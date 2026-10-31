import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../strings.dart';
import '../../features/admin/attendance/attendance_models.dart';

String attendanceTime(DateTime? value) =>
    value == null ? '--:--' : DateFormat('HH:mm').format(value);
String attendanceDuration(int minutes) => '${minutes ~/ 60}h ${minutes % 60}m';
String attendanceStatus(DayReportItem item) =>
    item.needsReview || item.missingCheckout
    ? 'Cần kiểm tra'
    : item.isInShift
    ? 'Đang trong ca'
    : item.firstIn == null
    ? 'Chưa vào ca'
    : 'Đã ra ca';

class AttendanceStatus extends StatelessWidget {
  const AttendanceStatus(this.item, {super.key});
  final DayReportItem item;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final attention = item.needsReview || item.missingCheckout;
    final color = attention
        ? scheme.error
        : item.isInShift
        ? Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF73D8B4)
              : const Color(0xFF16805D)
        : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        attendanceStatus(item),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = color == null
        ? scheme.primary
        : Color.lerp(
            color,
            scheme.onSurface,
            Theme.of(context).brightness == Brightness.dark ? .55 : .15,
          )!;
    return Card(
      color: Color.alphaBlend(ink.withValues(alpha: .08), scheme.surface),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ink.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: ink, size: 20),
                ),
                const Spacer(),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700, color: ink),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class WorkSummaryCard extends StatelessWidget {
  const WorkSummaryCard({
    super.key,
    required this.item,
    this.onTap,
    this.showName = true,
  });
  final DayReportItem item;
  final VoidCallback? onTap;
  final bool showName;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = item.requiredMinutes <= 0
        ? 0.0
        : (item.workedMinutes / item.requiredMinutes).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (showName)
                  Text(
                    '${item.employeeCode} - ${item.employeeName}',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                AttendanceStatus(item),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              item.isInShift
                  ? 'Đã làm (tạm tính)'
                  : 'Đã làm từ các cặp hoàn tất',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              item.workedDurationFormatted,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 10),
            Text(
              'Còn thiếu: ${attendanceDuration(item.remainingMinutes)} / Yêu cầu: ${attendanceDuration(item.requiredMinutes)}',
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                Text('Vào đầu tiên: ${attendanceTime(item.firstIn)}'),
                Text('Ra gần nhất: ${attendanceTime(item.lastOut)}'),
              ],
            ),
            if (item.expectedCompletion != null && item.remainingMinutes > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Dự kiến đủ công lúc ${attendanceTime(item.expectedCompletion)} nếu tiếp tục làm việc',
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (item.lateMinutes > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Đến trễ ${item.lateMinutes} phút; cần làm bù thời gian thiếu.',
                ),
              ),
            if (item.isLate ||
                item.isEarlyLeave ||
                item.missingCheckout ||
                item.needsReview)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (item.isLate)
                      Chip(
                        backgroundColor: scheme.tertiaryContainer,
                        label: const Text(S.lateBadge),
                      ),
                    if (item.isEarlyLeave) const Chip(label: Text('Về sớm')),
                    if (item.missingCheckout)
                      Chip(
                        backgroundColor: scheme.errorContainer,
                        label: const Text(S.missingCheckoutBadge),
                      ),
                    if (item.needsReview)
                      const Chip(label: Text('Cần kiểm tra lượt vào–ra')),
                  ],
                ),
              ),
            if (item.sessions.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  'Các khoảng làm việc (${item.sessions.length})',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                children: [
                  if (item.isInShift)
                    Text(
                      'Các cặp đã hoàn tất: ${attendanceDuration(item.completedMinutes)}',
                    ),
                  ...item.sessions.map(
                    (s) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule, size: 18),
                      title: Text(
                        '${attendanceTime(s.start)} → ${s.end == null ? 'Chưa có giờ ra' : attendanceTime(s.end)}',
                      ),
                    ),
                  ),
                ],
              ),
            if (onTap != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('Xem lịch sử'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
