import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nfc_manager/nfc_manager.dart';

import '../../core/config.dart';
import '../../core/uid.dart';

abstract class NfcService {
  Stream<String> get uids;
  Future<bool> isAvailable();
  Future<void> start();
  Future<void> stop();
}

class RealNfcService implements NfcService {
  final _uidController = StreamController<String>.broadcast();
  bool _isScanning = false;

  @override
  Stream<String> get uids => _uidController.stream;

  @override
  Future<bool> isAvailable() async {
    try {
      return await NfcManager.instance.isAvailable();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> start() async {
    if (_isScanning) return;
    final available = await isAvailable();
    if (!available) return;

    _isScanning = true;
    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          final uid = extractUidFromTag(tag);
          if (uid != null && uid.isNotEmpty) {
            _uidController.add(normalizeUid(uid));
          }
        },
      );
    } catch (_) {
      _isScanning = false;
    }
  }

  @override
  Future<void> stop() async {
    if (!_isScanning) return;
    _isScanning = false;
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
  }

  static String? extractUidFromTag(NfcTag tag) {
    final data = tag.data;
    List<int>? bytes;

    if (data['identifier'] is List) {
      bytes = (data['identifier'] as List).cast<int>();
    } else {
      const techKeys = [
        'nfca',
        'nfcb',
        'nfcf',
        'nfcv',
        'isodep',
        'mifareclassic',
        'mifareultralight',
        'ndef',
      ];
      for (final key in techKeys) {
        final tech = data[key];
        if (tech is Map && tech['identifier'] is List) {
          bytes = (tech['identifier'] as List).cast<int>();
          break;
        }
      }
    }

    if (bytes == null || bytes.isEmpty) return null;
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

class FakeNfcService implements NfcService {
  final _uidController = StreamController<String>.broadcast();
  bool _started = false;

  @override
  Stream<String> get uids => _uidController.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> start() async {
    _started = true;
  }

  @override
  Future<void> stop() async {
    _started = false;
  }

  void emit(String rawUid) {
    if (_started || kDebugMode) {
      _uidController.add(normalizeUid(rawUid));
    }
  }
}

final nfcServiceProvider = Provider<NfcService>((ref) {
  if (AppConfig.fakeNfc || kIsWeb) {
    return FakeNfcService();
  }
  return RealNfcService();
});
