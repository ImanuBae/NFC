import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';
import 'employee_model.dart';

abstract class EmployeeRepository {
  Future<List<Employee>> getEmployees({String? query, bool? activeOnly});
  Future<Employee?> getEmployeeById(String id);
  Future<Employee> createEmployee({
    required String code,
    required String fullName,
    bool active = true,
  });
  Future<Employee> updateEmployee({
    required String id,
    required String code,
    required String fullName,
    required bool active,
  });
}

class SupabaseEmployeeRepository implements EmployeeRepository {
  final SupabaseClient _client;

  SupabaseEmployeeRepository(this._client);

  @override
  Future<List<Employee>> getEmployees({String? query, bool? activeOnly}) async {
    var req = _client.from('employees').select();

    if (activeOnly != null) {
      req = req.eq('active', activeOnly);
    }

    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim();
      req = req.or('code.ilike.%$q%,full_name.ilike.%$q%');
    }

    final res = await req.order('code', ascending: true);
    final list = res as List;
    return list
        .map((e) => Employee.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Employee?> getEmployeeById(String id) async {
    final res = await _client
        .from('employees')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (res == null) return null;
    return Employee.fromJson(res);
  }

  @override
  Future<Employee> createEmployee({
    required String code,
    required String fullName,
    bool active = true,
  }) async {
    final res = await _client
        .from('employees')
        .insert({
          'code': code.trim(),
          'full_name': fullName.trim(),
          'active': active,
        })
        .select()
        .single();

    return Employee.fromJson(res);
  }

  @override
  Future<Employee> updateEmployee({
    required String id,
    required String code,
    required String fullName,
    required bool active,
  }) async {
    final res = await _client
        .from('employees')
        .update({
          'code': code.trim(),
          'full_name': fullName.trim(),
          'active': active,
        })
        .eq('id', id)
        .select()
        .single();

    return Employee.fromJson(res);
  }
}

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseEmployeeRepository(client);
});
