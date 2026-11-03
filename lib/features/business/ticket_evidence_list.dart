import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'attendance_ticket_repository.dart';
import 'ticket_evidence.dart';

class TicketEvidenceList extends ConsumerStatefulWidget {
  const TicketEvidenceList({super.key, required this.ticket});
  final Map<String, dynamic> ticket;
  @override
  ConsumerState<TicketEvidenceList> createState() => _TicketEvidenceListState();
}

class _TicketEvidenceListState extends ConsumerState<TicketEvidenceList> {
  bool _busy = false;
  bool _loading = false;
  Future<void> _open(Map<String, dynamic> metadata) async {
    setState(() {
      _busy = true;
      _loading = true;
    });
    try {
      final data = await ref
          .read(attendanceTicketRepositoryProvider)
          .evidence('${widget.ticket['id']}', '${metadata['id']}');
      final file = TicketEvidence(
        '${data['file_name']}',
        base64Decode('${data['content_base64']}'),
      );
      final type = '${data['content_type']}';
      if (!mounted) return;
      setState(() => _loading = false);
      final save = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(file.name),
          content: type.startsWith('image/')
              ? SizedBox(
                  width: 640,
                  height: 380,
                  child: InteractiveViewer(
                    child: Image.memory(
                      file.bytes,
                      fit: BoxFit.contain,
                      errorBuilder: (_, error, stack) => const Center(
                        child: Text(
                          'Không xem trước được ảnh. Có thể tải tệp để kiểm tra.',
                        ),
                      ),
                    ),
                  ),
                )
              : const Text(
                  'Tệp bằng chứng PDF. Chọn Tải tệp để lưu và mở bằng ứng dụng đọc PDF.',
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Đóng'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.download),
              label: const Text('Tải tệp'),
            ),
          ],
        ),
      );
      if (save == true && mounted) {
        final saved = await ref
            .read(ticketEvidenceFilesProvider)
            .save(file, type);
        if (saved && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Đã lưu bằng chứng.')));
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không tải được bằng chứng: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final files = (widget.ticket['attachments'] as List? ?? [])
        .map((f) => Map<String, dynamic>.from(f as Map))
        .toList();
    if (files.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Bằng chứng (${files.length})',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        for (final file in files)
          TextButton.icon(
            onPressed: _busy ? null : () => _open(file),
            icon: Icon(
              '${file['content_type']}' == 'application/pdf'
                  ? Icons.picture_as_pdf_outlined
                  : Icons.image_outlined,
            ),
            label: Text(
              '${file['file_name']} · ${((file['size_bytes'] as num) / 1024).ceil()} KB',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (_loading) const LinearProgressIndicator(),
      ],
    );
  }
}
