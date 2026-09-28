import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';
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

class SupabaseCardRepository implements CardRepository {
  final SupabaseClient _client;

  SupabaseCardRepository(this._client);

  @override
  Future<List<CardModel>> getCardsForEmployee(String employeeId) async {
    final res = await _client
        .from('cards')
        .select()
        .eq('employee_id', employeeId)
        .order('created_at', ascending: false);

    final list = res as List;
    return list
        .map((c) => CardModel.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<bool> isCardExists(String rawUid) async {
    final uid = normalizeUid(rawUid);
    final res = await _client
        .from('cards')
        .select('uid')
        .eq('uid', uid)
        .maybeSingle();

    return res != null;
  }

  @override
  Future<CardModel> assignCard({
    required String uid,
    required String employeeId,
  }) async {
    final normalized = normalizeUid(uid);
    final res = await _client
        .from('cards')
        .insert({'uid': normalized, 'employee_id': employeeId, 'active': true})
        .select()
        .single();

    return CardModel.fromJson(res);
  }

  @override
  Future<void> toggleCardStatus({
    required String uid,
    required bool active,
  }) async {
    final normalized = normalizeUid(uid);
    await _client
        .from('cards')
        .update({'active': active})
        .eq('uid', normalized);
  }
}

final cardRepositoryProvider = Provider<CardRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseCardRepository(client);
});
