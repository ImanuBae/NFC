import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/result.dart';
import '../../core/strings.dart';
import '../auth/auth_repository.dart';
import 'device_config.dart';
import 'fake_scan_dialog.dart';
import 'kiosk_pin_dialog.dart';
import 'kiosk_result_view.dart';
import 'my_history_page.dart';
import 'nfc_service.dart';
import 'pending_scan_store.dart';
import 'scan_coordinator.dart';
import 'sync_service.dart';

class KioskIdlePage extends ConsumerStatefulWidget {
  const KioskIdlePage({super.key});

  @override
  ConsumerState<KioskIdlePage> createState() => _KioskIdlePageState();
}

class _KioskIdlePageState extends ConsumerState<KioskIdlePage> {
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();
  bool _nfcAvailable = true;
  ScanResult? _currentResult;
  Timer? _resultDismissTimer;
  StreamSubscription<String>? _nfcSub;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _initKiosk();
  }

  Future<void> _initKiosk() async {
    try {
      if (!kIsWeb) {
        await WakelockPlus.enable();
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      }
    } catch (_) {}

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });

    try {
      final nfc = ref.read(nfcServiceProvider);
      _nfcAvailable = await nfc.isAvailable();
      if (_nfcAvailable) {
        await nfc.start();
        _nfcSub = nfc.uids.listen(_onUidScanned);
      }
    } catch (_) {
      _nfcAvailable = false;
    }
    if (mounted) setState(() {});
  }

  void _onUidScanned(String uid) async {
    if (_currentResult != null) return;

    final coordinator = ref.read(scanCoordinatorProvider);
    final result = await coordinator.handleUid(uid);
    if (result != null && mounted) {
      _showResult(result);
    }
  }

  void _showResult(ScanResult result) {
    _resultDismissTimer?.cancel();
    setState(() => _currentResult = result);

    _resultDismissTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _currentResult = null);
      }
    });
  }

  void _onLogoLongPressed() {
    KioskPinDialog.show(context, onAuthorized: () => _showExitOptions());
  }

  void _showExitOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.restart_alt),
              title: const Text('Đổi thiết bị (Xóa cấu hình thiết bị)'),
              onTap: () async {
                Navigator.of(ctx).pop();
                await ref.read(deviceConfigProvider).clearDeviceId();
                if (mounted) {
                  context.go('/kiosk/setup');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(S.logout, style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.of(ctx).pop();
                await ref.read(authRepositoryProvider).signOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(authRepositoryProvider).signOut();
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _resultDismissTimer?.cancel();
    _nfcSub?.cancel();
    try {
      ref.read(nfcServiceProvider).stop();
      if (!kIsWeb) WakelockPlus.disable();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentResult != null) {
      return KioskResultView(result: _currentResult!);
    }

    final nfc = ref.watch(nfcServiceProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_tabIndex == 0 ? 'Máy chấm công Kiosk' : 'Lịch sử của tôi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: S.logout,
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: _tabIndex == 0
          ? _buildClockBody(theme, nfc)
          : const MyHistoryPage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (idx) => setState(() => _tabIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.nfc_outlined),
            selectedIcon: Icon(Icons.nfc),
            label: 'Chấm công',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Lịch sử của tôi',
          ),
        ],
      ),
    );
  }

  Widget _buildClockBody(ThemeData theme, NfcService nfc) {
    final timeStr = DateFormat('HH:mm:ss').format(_currentTime);
    String dateStr;
    try {
      dateStr = DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(_currentTime);
    } catch (_) {
      dateStr = DateFormat('dd/MM/yyyy').format(_currentTime);
    }

    return SafeArea(
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onLongPress: _onLogoLongPressed,
                  child: Icon(
                    Icons.nfc_rounded,
                    size: 96,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  timeStr,
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 56,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  dateStr,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    S.tapCardPrompt,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Khung giờ làm việc: 09:00 - 18:00',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Vào ca: trước 09:00 • Tan ca: từ 18:00',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: Builder(
              builder: (context) {
                final isOnline =
                    ref.watch(isOnlineStreamProvider).value ?? true;
                final pendingCount =
                    ref.watch(pendingCountProvider).value ?? 0;
                final statusText = isOnline
                    ? (pendingCount > 0
                          ? '${S.onlineStatus} ($pendingCount chờ đồng bộ)'
                          : S.onlineStatus)
                    : (pendingCount > 0
                          ? '${S.offlineStatus} ($pendingCount chờ đồng bộ)'
                          : S.offlineStatus);

                return Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.green : Colors.amber[700],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      statusText,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (!_nfcAvailable)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.red[800],
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      S.nfcDisabledWarning,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (nfc is FakeNfcService)
            Positioned(
              bottom: 24,
              right: 24,
              child: FloatingActionButton.extended(
                onPressed: () => FakeScanDialog.show(context, nfc),
                icon: const Icon(Icons.touch_app),
                label: const Text(S.fakeNfcButton),
              ),
            ),
        ],
      ),
    );
  }
}
