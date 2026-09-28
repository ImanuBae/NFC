import 'package:demo_nfc/app.dart';
import 'package:demo_nfc/core/strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Renders config error when Supabase credentials are missing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: NfcAttendanceApp()));

    expect(find.text(S.configErrorTitle), findsNWidgets(2));
    expect(find.text(S.configErrorMsg), findsOneWidget);
  });
}
