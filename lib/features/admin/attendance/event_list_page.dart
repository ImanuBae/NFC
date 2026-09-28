import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';

class EventListPage extends ConsumerWidget {
  final String? employeeId;
  final String? date;

  const EventListPage({super.key, this.employeeId, this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Center(
        child: Text(S.eventsListTitle, style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
