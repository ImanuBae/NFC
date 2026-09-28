import 'package:demo_nfc/core/strings.dart';
import 'package:demo_nfc/features/admin/cards/assign_card_page.dart';
import 'package:demo_nfc/features/admin/cards/card_model.dart';
import 'package:demo_nfc/features/admin/cards/card_repository.dart';
import 'package:demo_nfc/features/kiosk/nfc_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCardRepository extends Mock implements CardRepository {}

class MockNfcService extends Mock implements NfcService {}

void main() {
  late MockCardRepository mockCardRepo;
  late FakeNfcService fakeNfcService;

  setUp(() {
    mockCardRepo = MockCardRepository();
    fakeNfcService = FakeNfcService();
  });

  Widget buildWidget() {
    return ProviderScope(
      overrides: [
        cardRepositoryProvider.overrideWithValue(mockCardRepo),
        nfcServiceProvider.overrideWithValue(fakeNfcService),
      ],
      child: const MaterialApp(home: AssignCardPage(employeeId: 'emp-123')),
    );
  }

  group('AssignCardPage', () {
    testWidgets('displays validation error if UID is empty', (tester) async {
      await tester.pumpWidget(buildWidget());

      await tester.tap(find.text(S.save));
      await tester.pump();

      expect(find.text(S.uidEmpty), findsOneWidget);
    });

    testWidgets('shows cardAlreadyExists error if UID is duplicate', (
      tester,
    ) async {
      when(() => mockCardRepo.isCardExists('04A1B2C3D4E501'))
          .thenAnswer((_) async => true);

      await tester.pumpWidget(buildWidget());

      await tester.enterText(
        find.widgetWithText(TextFormField, S.manualUid),
        '04:a1:b2:c3:d4:e5:01',
      );
      await tester.tap(find.text(S.save));
      await tester.pump();
      await tester.pump();

      expect(find.text(S.cardAlreadyExists), findsOneWidget);
      verify(() => mockCardRepo.isCardExists('04A1B2C3D4E501')).called(1);
      verifyNever(
        () => mockCardRepo.assignCard(
          uid: any(named: 'uid'),
          employeeId: any(named: 'employeeId'),
        ),
      );
    });

    testWidgets('calls assignCard with normalized UID on success', (
      tester,
    ) async {
      when(() => mockCardRepo.isCardExists('04A1B2C3D4E502'))
          .thenAnswer((_) async => false);
      when(
        () => mockCardRepo.assignCard(
          uid: '04A1B2C3D4E502',
          employeeId: 'emp-123',
        ),
      ).thenAnswer(
        (_) async => CardModel(
          uid: '04A1B2C3D4E502',
          employeeId: 'emp-123',
          active: true,
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(buildWidget());

      await tester.enterText(
        find.widgetWithText(TextFormField, S.manualUid),
        '04-a1-b2-c3-d4-e5-02',
      );
      await tester.tap(find.text(S.save));
      await tester.pump();
      await tester.pump();

      verify(
        () => mockCardRepo.assignCard(
          uid: '04A1B2C3D4E502',
          employeeId: 'emp-123',
        ),
      ).called(1);
    });
  });
}
