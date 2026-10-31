import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/result.dart';
import '../../core/router.dart';
import '../../core/strings.dart';
import '../auth/auth_repository.dart';
import '../business/face_camera_service.dart';
import 'device_config.dart';
import 'fake_scan_dialog.dart';
import 'kiosk_pin_dialog.dart';
import 'kiosk_result_view.dart';
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
  bool _faceMode = false;
  bool _faceBusy = false;

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
    _faceMode = !_nfcAvailable;
    if (mounted) setState(() {});
  }

  void _onUidScanned(String uid) async {
    if (_currentResult != null || _faceMode || _faceBusy) return;

    final coordinator = ref.read(scanCoordinatorProvider);
    final result = await coordinator.handleUid(uid);
    if (result != null && mounted) {
      _showResult(result);
    }
  }

  void _showResult(ScanResult result) {
    _resultDismissTimer?.cancel();
    setState(() => _currentResult = result);
    if (result is ScanFailure && result.requiresDeviceSetup) return;

    _resultDismissTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _currentResult = null);
      }
    });
  }

  Future<void> _scanFace(String purpose) async {
    if (_faceBusy || _currentResult != null) return;
    setState(() => _faceBusy = true);
    try {
      final deviceId = await ref.read(deviceConfigProvider).getDeviceId();
      if (deviceId == null) {
        if (mounted) {
          _showResult(
            const ScanFailure(
              'Máy chưa được đăng ký.',
              requiresDeviceSetup: true,
            ),
          );
        }
        return;
      }
      final result = await ref
          .read(faceCameraServiceProvider)
          .submit(purpose, deviceId: deviceId);
      if (!mounted) return;
      _showResult(
        ScanOk(
          isCheckIn: result['type'] == 'check_in',
          name: result['employee_name'] as String,
          code: result['employee_code'] as String,
          at: DateTime.parse(result['occurred_at'] as String).toLocal(),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _faceBusy = false);
    }
  }

  void _onLogoLongPressed() {
    KioskPinDialog.show(context, onAuthorized: () => _showExitOptions());
  }

  void _recoverDevice() {
    KioskPinDialog.show(
      context,
      onAuthorized: () async {
        try {
          await ref.read(deviceConfigProvider).clearDeviceId();
          if (!mounted) return;
          await ref.read(routerNotifierProvider).refreshState();
          if (mounted) context.go('/kiosk/setup');
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Không thể thiết lập lại máy: $error')),
            );
          }
        }
      },
    );
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
                if (!mounted) return;
                await ref.read(routerNotifierProvider).refreshState();
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
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này?',
        ),
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
    ref.watch(syncServiceProvider);

    if (_currentResult != null) {
      return KioskResultView(
        result: _currentResult!,
        onDeviceSetup: _recoverDevice,
      );
    }

    final nfc = ref.watch(nfcServiceProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Điểm chấm công'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: S.logout,
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: _buildClockBody(theme, nfc),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _faceMode ? 1 : 0,
        onDestinationSelected: _faceBusy
            ? null
            : (idx) => setState(() => _faceMode = idx == 1),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.nfc_outlined),
            selectedIcon: Icon(Icons.nfc),
            label: 'Thẻ NFC',
          ),
          NavigationDestination(
            icon: Icon(Icons.face_outlined),
            selectedIcon: Icon(Icons.face),
            label: 'Khuôn mặt',
          ),
        ],
      ),
    );
  }

  Widget _buildClockBody(ThemeData theme, NfcService nfc) {
    final scheme = theme.colorScheme;
    final isOnline = ref.watch(isOnlineStreamProvider).value ?? true;
    final pending = ref.watch(pendingCountProvider).value ?? 0;
    final time = DateFormat('HH:mm:ss').format(_currentTime);
    String date;
    try {
      date = DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(_currentTime);
    } catch (_) {
      date = DateFormat('dd/MM/yyyy').format(_currentTime);
    }
    final ready = _faceMode || _nfcAvailable;
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, box) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: Icon(
                        isOnline ? Icons.wifi : Icons.wifi_off,
                        size: 18,
                      ),
                      label: Text(
                        isOnline ? 'Có kết nối mạng' : 'Đang ngoại tuyến',
                      ),
                    ),
                    if (pending > 0)
                      Chip(
                        avatar: const Icon(Icons.sync, size: 18),
                        label: Text('$pending chờ đồng bộ'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'THỜI GIAN HIỆN TẠI',
                        style: TextStyle(
                          color: scheme.onPrimaryContainer,
                          fontSize: 11,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          time,
                          style: TextStyle(
                            color: scheme.onPrimaryContainer,
                            fontSize: 44,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        date,
                        style: TextStyle(color: scheme.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        GestureDetector(
                          onLongPress: _onLogoLongPressed,
                          child: Container(
                            width: 112,
                            height: 112,
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _faceMode
                                  ? Icons.face_retouching_natural
                                  : Icons.nfc_rounded,
                              size: 60,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          _faceMode
                              ? 'Chấm công bằng khuôn mặt'
                              : 'Chạm thẻ NFC',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _faceMode
                              ? 'Chọn vào làm hoặc ra về. Nhìn thẳng vào camera và giữ yên.'
                              : 'Đưa thẻ lại gần vùng NFC của điện thoại và giữ trong giây lát.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (!_faceMode)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: ready
                                  ? scheme.primaryContainer
                                  : scheme.errorContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  ready
                                      ? Icons.contactless_outlined
                                      : Icons.warning_amber_rounded,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    ready
                                        ? 'Sẵn sàng nhận thẻ'
                                        : S.nfcDisabledWarning,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_faceMode) ...[
                          if (_faceBusy)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: LinearProgressIndicator(),
                            ),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(56),
                              ),
                              onPressed: _faceBusy
                                  ? null
                                  : () => _scanFace('check_in'),
                              icon: const Icon(Icons.login),
                              label: const Text('Vào làm bằng khuôn mặt'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(56),
                              ),
                              onPressed: _faceBusy
                                  ? null
                                  : () => _scanFace('check_out'),
                              icon: const Icon(Icons.logout),
                              label: const Text('Ra về bằng khuôn mặt'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        const Divider(),
                        const SizedBox(height: 12),
                        const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.verified_user_outlined, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Kiểm tra họ tên và kết quả sau mỗi lượt chấm công. Máy dùng chung, không cần đăng nhập tài khoản nhân viên.',
                                style: TextStyle(fontSize: 12, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: const ListTile(
                    leading: Icon(Icons.schedule_outlined),
                    title: Text('Ca chuẩn 09:00 – 18:00'),
                    subtitle: Text(
                      'Xem giờ đã làm và công còn thiếu trong cổng nhân viên.',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Chọn Thẻ NFC hoặc Khuôn mặt ở thanh bên dưới.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                if (nfc is FakeNfcService && !_faceMode)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: OutlinedButton.icon(
                      onPressed: () => FakeScanDialog.show(context, nfc),
                      icon: const Icon(Icons.touch_app),
                      label: const Text(S.fakeNfcButton),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
