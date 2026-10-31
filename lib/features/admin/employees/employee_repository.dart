import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import 'employee_model.dart';

abstract class EmployeeRepository {
  Future<List<Employee>> getEmployees({String? query, bool? activeOnly});
  Future<Employee?> getEmployeeById(String id);
  Future<Employee> createEmployee({
    required String code,
    required String fullName,
    bool active = true,
    double hourlyRate = 0,
  });
  Future<Employee> updateEmployee({
    required String id,
    required String code,
    required String fullName,
    required bool active,
    double? hourlyRate,
  });
}

class ApiEmployeeRepository implements EmployeeRepository {
  ApiEmployeeRepository(this.client);
  final ApiClient client;
  @override
  Future<List<Employee>> getEmployees({
    String? query,
    bool? activeOnly,
  }) async => (await client.list(
    '/employees',
    query: {'query': query, 'active': activeOnly?.toString()},
  )).map(Employee.fromJson).toList();
  @override
  Future<Employee?> getEmployeeById(String id) async {
    final row = await client.request('GET', '/employees/$id');
    return row == null
        ? null
        : Employee.fromJson(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<Employee> createEmployee({
    required String code,
    required String fullName,
    bool active = true,
    double hourlyRate = 0,
  }) async => Employee.fromJson(
    Map<String, dynamic>.from(
      await client.request(
        'POST',
        '/employees',
        body: {
          'code': code.trim(),
          'full_name': fullName.trim(),
          'active': active,
          'hourly_rate': hourlyRate,
        },
      ) as Map,
    ),
  );
  @override
  Future<Employee> updateEmployee({
    required String id,
    required String code,
    required String fullName,
    required bool active,
    double? hourlyRate,
  }) async => Employee.fromJson(
    Map<String, dynamic>.from(
      await client.request(
        'PUT',
        '/employees/$id',
        body: {
          'code': code.trim(),
          'full_name': fullName.trim(),
          'active': active,
          'hourly_rate': ?hourlyRate,
        },
      ) as Map,
    ),
  );
}

final employeeRepositoryProvider = Provider<EmployeeRepository>(
  (ref) => ApiEmployeeRepository(ref.watch(apiClientProvider)),
);
