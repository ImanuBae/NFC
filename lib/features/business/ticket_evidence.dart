import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

class TicketEvidence {
  const TicketEvidence(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
  Map<String, dynamic> toJson() => {
    'file_name': name,
    'content_base64': base64Encode(bytes),
  };
}

void validateTicketEvidence(List<TicketEvidence> files) {
  if (files.length > 3) throw const ApiException('Tối đa 3 tệp bằng chứng.');
  var total = 0;
  for (final file in files) {
    if (!RegExp(
      r'\.(jpe?g|png|pdf)$',
      caseSensitive: false,
    ).hasMatch(file.name)) {
      throw const ApiException('Chỉ nhận ảnh JPG/PNG hoặc PDF.');
    }
    if (file.name.length > 200) {
      throw const ApiException('Tên tệp tối đa 200 ký tự.');
    }
    if (file.bytes.isEmpty || file.bytes.length > 2 * 1024 * 1024) {
      throw const ApiException('Tệp bằng chứng trống hoặc lớn hơn 2 MB.');
    }
    total += file.bytes.length;
  }
  if (total > 5 * 1024 * 1024) {
    throw const ApiException('Tổng dung lượng bằng chứng tối đa 5 MB.');
  }
}

class TicketEvidenceFiles {
  Future<TicketEvidence?> pick() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      dialogTitle: 'Chọn bằng chứng sửa công',
    );
    if (file == null) return null;
    final size = await file.length();
    if (size != null && size > 2 * 1024 * 1024) {
      throw const ApiException('Mỗi tệp bằng chứng tối đa 2 MB.');
    }
    final evidence = TicketEvidence(file.name, await file.readAsBytes());
    validateTicketEvidence([evidence]);
    return evidence;
  }

  Future<bool> save(TicketEvidence file, String contentType) async =>
      await FilePicker.saveFile(
        fileName: file.name,
        bytes: file.bytes,
        mimeType: contentType,
      ) !=
      null;
}

final ticketEvidenceFilesProvider = Provider((ref) => TicketEvidenceFiles());
