import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

class EmployeeImportFile {
  const EmployeeImportFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

class EmployeeImportFiles {
  Future<EmployeeImportFile?> pick() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['xls', 'xlsx'],
      dialogTitle: 'Chọn danh sách nhân viên Excel',
    );
    if (file == null) return null;
    final size = await file.length();
    if (size != null && size > 5 * 1024 * 1024) {
      throw const ApiException('File Excel tối đa 5 MB.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw const ApiException('File trống hoặc lớn hơn 5 MB.');
    }
    return EmployeeImportFile(file.name, bytes);
  }

  Future<void> save(Map<String, dynamic> file) async {
    await FilePicker.saveFile(
      fileName: file['file_name'] as String,
      bytes: base64Decode(file['content_base64'] as String),
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }
}

final employeeImportFilesProvider = Provider((ref) => EmployeeImportFiles());
final employeeImportRepositoryProvider = Provider(
  (ref) => EmployeeImportRepository(ref.watch(apiClientProvider)),
);

class EmployeeImportRepository {
  EmployeeImportRepository(this.client);
  final ApiClient client;
  Future<Map<String, dynamic>> verifyEmail() async => Map<String, dynamic>.from(
    await client.request(
      'POST',
      '/employees/import/email-test',
      body: {},
      timeout: const Duration(seconds: 40),
    ) as Map,
  );

  Future<Map<String, dynamic>> emailSettings() async =>
      Map<String, dynamic>.from(
        await client.request('GET', '/employees/import/email-settings') as Map,
      );
  Future<Map<String, dynamic>> emailStatus(String id) async =>
      Map<String, dynamic>.from(
        await client.request('GET', '/employees/import/$id/emails') as Map,
      );
  Future<void> retryEmails(String id) async {
    await client.request(
      'POST',
      '/employees/import/$id/emails/retry',
      body: {},
    );
  }

  Future<List<Map<String, dynamic>>> recent() =>
      client.list('/employees/import/recent');

  Future<Map<String, dynamic>> template() async => Map<String, dynamic>.from(
    await client.request('GET', '/employees/import/template') as Map,
  );

  Future<Map<String, dynamic>> preview(
    EmployeeImportFile file,
    String department,
  ) => _upload('/employees/import/preview', file, department);

  Future<Map<String, dynamic>> commit(
    EmployeeImportFile file,
    String department,
    String importId,
  ) =>
      _upload('/employees/import/commit', file, department, importId: importId);

  Future<Map<String, dynamic>> credentials(String importId) async =>
      Map<String, dynamic>.from(
        await client.request('GET', '/employees/import/$importId/credentials')
            as Map,
      );

  Future<Map<String, dynamic>> _upload(
    String path,
    EmployeeImportFile file,
    String department, {
    String? importId,
  }) async => Map<String, dynamic>.from(
    await client.request(
      'POST',
      path,
      body: {
        'file_name': file.name,
        'content_base64': base64Encode(file.bytes),
        'department': department.trim(),
        'import_id': importId,
      },
      timeout: const Duration(minutes: 5),
    ) as Map,
  );
}
