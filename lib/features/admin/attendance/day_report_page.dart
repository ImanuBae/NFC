import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';

class DayReportPage extends ConsumerWidget {
  const DayReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Center(
        child: Text(S.navAttendance, style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
