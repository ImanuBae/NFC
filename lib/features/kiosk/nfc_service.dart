import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';

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
      final status = await NfcManager.instance.checkAvailability();
      return status == NfcAvailability.enabled;
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
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
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
    try {
      final androidTag = NfcTagAndroid.from(tag);
      if (androidTag != null && androidTag.id.isNotEmpty) {
        return _bytesToHex(androidTag.id);
      }
    } catch (_) {}

    try {
      final miFare = MiFareIos.from(tag);
      if (miFare != null && miFare.identifier.isNotEmpty) {
        return _bytesToHex(miFare.identifier);
      }
      final iso15693 = Iso15693Ios.from(tag);
      if (iso15693 != null && iso15693.identifier.isNotEmpty) {
        return _bytesToHex(iso15693.identifier);
      }
      final iso7816 = Iso7816Ios.from(tag);
      if (iso7816 != null && iso7816.identifier.isNotEmpty) {
        return _bytesToHex(iso7816.identifier);
      }
      final felica = FeliCaIos.from(tag);
      if (felica != null && felica.currentIDm.isNotEmpty) {
        return _bytesToHex(felica.currentIDm);
      }
    } catch (_) {}

    return null;
  }

  static String _bytesToHex(Uint8List bytes) {
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
