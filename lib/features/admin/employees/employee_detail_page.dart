import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings.dart';
import '../cards/card_model.dart';
import '../cards/card_repository.dart';
import 'employee_form_dialog.dart';
import 'employee_model.dart';
import 'employee_repository.dart';

final employeeDetailProvider = FutureProvider.family
    .autoDispose<Employee?, String>((ref, id) async {
      final repo = ref.watch(employeeRepositoryProvider);
      return repo.getEmployeeById(id);
    });

final employeeCardsProvider = FutureProvider.family
    .autoDispose<List<CardModel>, String>((ref, id) async {
      final repo = ref.watch(cardRepositoryProvider);
      return repo.getCardsForEmployee(id);
    });

class EmployeeDetailPage extends ConsumerWidget {
  final String employeeId;

  const EmployeeDetailPage({super.key, required this.employeeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empAsync = ref.watch(employeeDetailProvider(employeeId));
    final cardsAsync = ref.watch(employeeCardsProvider(employeeId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(S.employeeDetail),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: S.editEmployee,
            onPressed: () async {
              final emp = empAsync.value;
              if (emp == null) return;
              final repo = ref.read(employeeRepositoryProvider);
              final updated = await EmployeeFormDialog.show(
                context,
                employee: emp,
                repository: repo,
              );
              if (updated == true) {
                ref.invalidate(employeeDetailProvider(employeeId));
              }
            },
          ),
        ],
      ),
      body: empAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('${S.error}: $err')),
        data: (emp) {
          if (emp == null) {
            return const Center(child: Text('Không tìm thấy nhân viên'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: emp.active
                                  ? theme.colorScheme.primaryContainer
                                  : Colors.grey[300],
                              child: Text(
                                emp.code,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    emp.fullName,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('Mã nhân viên: ${emp.code}'),
                                  const SizedBox(height: 4),
                                  Chip(
                                    label: Text(
                                      emp.active ? S.active : S.inactive,
                                      style: TextStyle(
                                        color: emp.active
                                            ? Colors.green[800]
                                            : Colors.red[800],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    backgroundColor: emp.active
                                        ? Colors.green[50]
                                        : Colors.red[50],
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      S.cardsList,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        context.go('/admin/employees/$employeeId/assign-card');
                      },
                      icon: const Icon(Icons.add_card, size: 18),
                      label: const Text(S.assignCard),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                cardsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Text('${S.error}: $err'),
                  data: (cards) {
                    if (cards.isEmpty) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Center(
                            child: Text(
                              S.noCards,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cards.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final card = cards[index];
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              Icons.nfc_rounded,
                              color: card.active ? Colors.blue : Colors.grey,
                            ),
                            title: Text(
                              card.uid,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              card.active ? S.cardActive : S.cardLocked,
                              style: TextStyle(
                                color: card.active
                                    ? Colors.green[700]
                                    : Colors.red,
                              ),
                            ),
                            trailing: OutlinedButton(
                              onPressed: () async {
                                final repo = ref.read(cardRepositoryProvider);
                                await repo.toggleCardStatus(
                                  uid: card.uid,
                                  active: !card.active,
                                );
                                ref.invalidate(
                                  employeeCardsProvider(employeeId),
                                );
                              },
                              child: Text(
                                card.active ? S.lockCard : S.unlockCard,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
