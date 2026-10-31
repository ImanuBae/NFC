import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/uid.dart';
import 'card_model.dart';

abstract class CardRepository {
  Future<List<CardModel>> getCardsForEmployee(String employeeId);
  Future<bool> isCardExists(String uid);
  Future<CardModel> assignCard({
    required String uid,
    required String employeeId,
  });
  Future<void> toggleCardStatus({required String uid, required bool active});
}

class ApiCardRepository implements CardRepository {
  ApiCardRepository(this.client);
  final ApiClient client;
  @override
  Future<List<CardModel>> getCardsForEmployee(String employeeId) async =>
      (await client.list(
        '/cards',
        query: {'employeeId': employeeId},
      )).map(CardModel.fromJson).toList();
  @override
  Future<bool> isCardExists(String uid) async => (await client.list(
    '/cards',
    query: {'uid': normalizeUid(uid)},
  )).isNotEmpty;
  @override
  Future<CardModel> assignCard({
    required String uid,
    required String employeeId,
  }) async => CardModel.fromJson(
    Map<String, dynamic>.from(
      await client.request(
        'POST',
        '/cards',
        body: {'uid': normalizeUid(uid), 'employee_id': employeeId},
      ) as Map,
    ),
  );
  @override
  Future<void> toggleCardStatus({
    required String uid,
    required bool active,
  }) async {
    await client.request(
      'PUT',
      '/cards/${normalizeUid(uid)}',
      body: {'active': active},
    );
  }
}

final cardRepositoryProvider = Provider<CardRepository>(
  (ref) => ApiCardRepository(ref.watch(apiClientProvider)),
);
