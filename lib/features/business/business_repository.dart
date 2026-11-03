import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

final businessRepositoryProvider = Provider(
  (ref) => BusinessRepository(ref.watch(apiClientProvider)),
);

class BusinessRepository {
  BusinessRepository(this.client);
  final ApiClient client;
  Future<Map<String, dynamic>> action(
    String action,
    Map<String, dynamic> data,
  ) async => Map<String, dynamic>.from(
    await client.request('POST', '/business', body: {'action': action, ...data})
        as Map,
  );
  Future<List<Map<String, dynamic>>> report(String start, String end) =>
      client.list('/reports', query: {'start': start, 'end': end});
  Future<List<Map<String, dynamic>>> accounts() => client.list('/accounts');
  Future<List<Map<String, dynamic>>> faces() => client.list('/faces');
  Future<List<Map<String, dynamic>>> employees() => client.list('/employees');
  Future<List<Map<String, dynamic>>> payrollRuns() =>
      client.list('/payroll/runs');
  Future<Map<String, dynamic>> exportPayroll(String runId) async =>
      Map<String, dynamic>.from(
        await client.request('GET', '/payroll/runs/$runId/export') as Map,
      );
  Future<List<Map<String, dynamic>>> payrollItems({
    String? runId,
    String? employeeId,
  }) => client.list(
    '/payroll/items',
    query: {'runId': runId, 'employeeId': employeeId},
  );
  Future<void> closePayroll(String start, String period) async {
    await client.request(
      'POST',
      '/payroll/close',
      body: {'start': start, 'period': period},
    );
  }
}
