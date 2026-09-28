import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';

class AssignCardPage extends ConsumerWidget {
  final String employeeId;

  const AssignCardPage({super.key, required this.employeeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.assignCard)),
      body: Center(child: Text('${S.assignCard} for employee: $employeeId')),
    );
  }
}
