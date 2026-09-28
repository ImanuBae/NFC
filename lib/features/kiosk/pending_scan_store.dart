import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'scan_coordinator.dart';

class PendingScan {
  final String clientScanId;
  final String uid;
  final DateTime deviceTime;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;

  PendingScan({
    required this.clientScanId,
    required this.uid,
    required this.deviceTime,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
  });

  Map<String, dynamic> toMap() => {
    'client_scan_id': clientScanId,
    'uid': uid,
    'device_time': deviceTime.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'attempts': attempts,
    'last_error': lastError,
  };

  factory PendingScan.fromMap(Map<String, dynamic> map) => PendingScan(
    clientScanId: map['client_scan_id'] as String,
    uid: map['uid'] as String,
    deviceTime: DateTime.parse(map['device_time'] as String),
    createdAt: DateTime.parse(map['created_at'] as String),
    attempts: (map['attempts'] as num?)?.toInt() ?? 0,
    lastError: map['last_error'] as String?,
  );
}

abstract class PendingScanStore implements OfflineScanQueue {
  Stream<int> get pendingCountStream;
  Future<int> count();
  Future<List<PendingScan>> listOrdered();
  @override
  Future<void> enqueue({
    required String clientScanId,
    required String uid,
    required DateTime deviceTime,
  });
  Future<void> remove(String clientScanId);
  Future<void> markFailed(String clientScanId, String error);
}

class SqflitePendingScanStore implements PendingScanStore {
  Database? _db;
  final _countController = StreamController<int>.broadcast();

  @override
  Stream<int> get pendingCountStream => _countController.stream;

  Future<Database> _getDb() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'nfc_attendance.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pending_scans(
            client_scan_id TEXT PRIMARY KEY,
            uid TEXT,
            device_time TEXT,
            created_at TEXT,
            attempts INTEGER DEFAULT 0,
            last_error TEXT
          )
        ''');
      },
    );
    await _notifyCount();
    return _db!;
  }

  Future<void> _notifyCount() async {
    final c = await count();
    _countController.add(c);
  }

  @override
  Future<int> count() async {
    try {
      final db = await _getDb();
      final res = await db.rawQuery(
        'SELECT COUNT(*) as count FROM pending_scans',
      );
      return Sqflite.firstIntValue(res) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> enqueue({
    required String clientScanId,
    required String uid,
    required DateTime deviceTime,
  }) async {
    final db = await _getDb();
    final scan = PendingScan(
      clientScanId: clientScanId,
      uid: uid,
      deviceTime: deviceTime,
      createdAt: DateTime.now().toUtc(),
    );
    await db.insert(
      'pending_scans',
      scan.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _notifyCount();
  }

  @override
  Future<List<PendingScan>> listOrdered() async {
    final db = await _getDb();
    final rows = await db.query('pending_scans', orderBy: 'device_time ASC');
    return rows.map(PendingScan.fromMap).toList();
  }

  @override
  Future<void> remove(String clientScanId) async {
    final db = await _getDb();
    await db.delete(
      'pending_scans',
      where: 'client_scan_id = ?',
      whereArgs: [clientScanId],
    );
    await _notifyCount();
  }

  @override
  Future<void> markFailed(String clientScanId, String error) async {
    final db = await _getDb();
    await db.rawUpdate(
      '''
      UPDATE pending_scans
      SET attempts = attempts + 1, last_error = ?
      WHERE client_scan_id = ?
    ''',
      [error, clientScanId],
    );
    await _notifyCount();
  }
}

class InMemoryPendingScanStore implements PendingScanStore {
  final List<PendingScan> _items = [];
  final _countController = StreamController<int>.broadcast();

  @override
  Stream<int> get pendingCountStream => _countController.stream;

  @override
  Future<int> count() async => _items.length;

  @override
  Future<void> enqueue({
    required String clientScanId,
    required String uid,
    required DateTime deviceTime,
  }) async {
    _items.removeWhere((i) => i.clientScanId == clientScanId);
    _items.add(
      PendingScan(
        clientScanId: clientScanId,
        uid: uid,
        deviceTime: deviceTime,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    _countController.add(_items.length);
  }

  @override
  Future<List<PendingScan>> listOrdered() async {
    final copy = List<PendingScan>.from(_items);
    copy.sort((a, b) => a.deviceTime.compareTo(b.deviceTime));
    return copy;
  }

  @override
  Future<void> remove(String clientScanId) async {
    _items.removeWhere((i) => i.clientScanId == clientScanId);
    _countController.add(_items.length);
  }

  @override
  Future<void> markFailed(String clientScanId, String error) async {
    final index = _items.indexWhere((i) => i.clientScanId == clientScanId);
    if (index != -1) {
      final old = _items[index];
      _items[index] = PendingScan(
        clientScanId: old.clientScanId,
        uid: old.uid,
        deviceTime: old.deviceTime,
        createdAt: old.createdAt,
        attempts: old.attempts + 1,
        lastError: error,
      );
    }
    _countController.add(_items.length);
  }
}

final pendingScanStoreProvider = Provider<PendingScanStore>((ref) {
  if (kIsWeb) {
    return InMemoryPendingScanStore();
  }
  return SqflitePendingScanStore();
});

final pendingCountProvider = StreamProvider<int>((ref) {
  final store = ref.watch(pendingScanStoreProvider);
  return store.pendingCountStream;
});
