import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings.dart';
import 'employee_form_dialog.dart';
import 'employee_model.dart';
import 'employee_repository.dart';

class EmployeeQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void setQuery(String q) => state = q;
}

final employeeQueryProvider = NotifierProvider<EmployeeQueryNotifier, String>(
  EmployeeQueryNotifier.new,
);

class EmployeeActiveFilterNotifier extends Notifier<bool?> {
  @override
  bool? build() => null;
  void setFilter(bool? f) => state = f;
}

final employeeActiveFilterProvider =
    NotifierProvider<EmployeeActiveFilterNotifier, bool?>(
      EmployeeActiveFilterNotifier.new,
    );

final employeeListProvider = FutureProvider.autoDispose<List<Employee>>((
  ref,
) async {
  final repo = ref.watch(employeeRepositoryProvider);
  final query = ref.watch(employeeQueryProvider);
  final activeOnly = ref.watch(employeeActiveFilterProvider);
  return repo.getEmployees(query: query, activeOnly: activeOnly);
});

class EmployeeListPage extends ConsumerWidget {
  const EmployeeListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(employeeListProvider);
    final activeFilter = ref.watch(employeeActiveFilterProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: S.searchEmployees,
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      ref.read(employeeQueryProvider.notifier).setQuery(val);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text(S.active),
                  selected: activeFilter == true,
                  onSelected: (selected) {
                    ref
                        .read(employeeActiveFilterProvider.notifier)
                        .setFilter(selected ? true : null);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: employeesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('${S.error}: $err')),
              data: (employees) {
                if (employees.isEmpty) {
                  return const Center(
                    child: Text(
                      'Không có nhân viên nào',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(employeeListProvider);
                  },
                  child: ListView.builder(
                    itemCount: employees.length,
                    itemBuilder: (context, index) {
                      final emp = employees[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: emp.active
                              ? theme.colorScheme.primaryContainer
                              : Colors.grey[300],
                          child: Text(
                            emp.code,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: emp.active
                                  ? theme.colorScheme.onPrimaryContainer
                                  : Colors.grey[700],
                            ),
                          ),
                        ),
                        title: Text(
                          emp.fullName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            decoration: emp.active
                                ? null
                                : TextDecoration.lineThrough,
                          ),
                        ),
                        subtitle: Text(
                          'Mã: ${emp.code} • ${emp.active ? S.active : S.inactive}',
                          style: TextStyle(
                            color: emp.active ? Colors.green[700] : Colors.red,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          context.go('/admin/employees/${emp.id}');
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final repo = ref.read(employeeRepositoryProvider);
          final created = await EmployeeFormDialog.show(
            context,
            repository: repo,
          );
          if (created == true) {
            ref.invalidate(employeeListProvider);
          }
        },
        icon: const Icon(Icons.person_add),
        label: const Text(S.addEmployee),
      ),
    );
  }
}
