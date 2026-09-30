import 'package:demo_nfc/core/result.dart';
import 'package:demo_nfc/core/strings.dart';
import 'package:demo_nfc/features/kiosk/kiosk_result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildWidget(ScanResult result) {
    return MaterialApp(home: KioskResultView(result: result));
  }

  testWidgets('displays check-in with green background and welcome message', (
    tester,
  ) async {
    final result = ScanOk(
      isCheckIn: true,
      name: 'Nguyen Van A',
      code: 'NV01',
      at: DateTime(2026, 9, 28, 8, 30, 0),
    );

    await tester.pumpWidget(buildWidget(result));

    expect(find.text('${S.welcomePrefix}Nguyen Van A'), findsOneWidget);
    expect(find.text('Vào ca: 08:30:00 (Đúng giờ)'), findsOneWidget);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, equals(const Color(0xFF2E7D32)));
  });

  testWidgets('displays check-out on time with blue background and goodbye message', (
    tester,
  ) async {
    final result = ScanOk(
      isCheckIn: false,
      name: 'Tran Thi B',
      code: 'NV02',
      at: DateTime(2026, 9, 28, 18, 30, 0),
    );

    await tester.pumpWidget(buildWidget(result));

    expect(find.text('${S.goodbyePrefix}Tran Thi B'), findsOneWidget);
    expect(find.text('Ra ca: 18:30:00 (Đúng giờ)'), findsOneWidget);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, equals(const Color(0xFF1565C0)));
  });

  testWidgets('displays check-out early leave with orange background and early leave message', (
    tester,
  ) async {
    final result = ScanOk(
      isCheckIn: false,
      name: 'Tran Thi B',
      code: 'NV02',
      at: DateTime(2026, 9, 28, 17, 30, 0),
    );

    await tester.pumpWidget(buildWidget(result));

    expect(find.text('${S.goodbyePrefix}Tran Thi B'), findsOneWidget);
    expect(find.text('Ra ca: 17:30:00 (Về sớm < 18:00)'), findsOneWidget);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, equals(const Color(0xFFE65100)));
  });

  testWidgets(
    'displays rejected with red background and invalid card message',
    (tester) async {
      const result = ScanRejected(reason: 'unknown_card');

      await tester.pumpWidget(buildWidget(result));

      expect(find.text(S.invalidCard), findsOneWidget);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(const Color(0xFFC62828)));
    },
  );

  testWidgets(
    'displays ignored with grey background and already scanned message',
    (tester) async {
      const result = ScanIgnored(name: 'Nguyen Van A');

      await tester.pumpWidget(buildWidget(result));

      expect(find.text(S.alreadyScanned), findsOneWidget);
      expect(find.text('Nguyen Van A'), findsOneWidget);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(const Color(0xFF616161)));
    },
  );

  testWidgets('displays offline queued with amber background', (tester) async {
    const result = ScanQueuedOffline();

    await tester.pumpWidget(buildWidget(result));

    expect(find.text(S.scanQueuedOffline), findsOneWidget);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, equals(const Color(0xFFF57F17)));
  });
}
