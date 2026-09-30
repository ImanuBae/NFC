import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/result.dart';
import '../../core/strings.dart';

class KioskResultView extends StatelessWidget {
  final ScanResult result;

  const KioskResultView({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    IconData icon;
    String title;
    String? subtitle;

    switch (result) {
      case ScanOk ok:
        final localAt = ok.at.toLocal();
        final timeFormatted = DateFormat('HH:mm:ss').format(localAt);
        if (ok.isCheckIn) {
          final isLate = localAt.hour > 9 || (localAt.hour == 9 && localAt.minute > 0);
          backgroundColor = isLate ? const Color(0xFFE65100) : const Color(0xFF2E7D32); // Orange if late, green if on time
          icon = Icons.login_rounded;
          title = '${S.welcomePrefix}${ok.name}';
          subtitle = isLate
              ? 'Vào ca: $timeFormatted (Đi trễ > 09:00)'
              : 'Vào ca: $timeFormatted (Đúng giờ)';
        } else {
          final isEarlyLeave = localAt.hour < 18;
          backgroundColor = isEarlyLeave ? const Color(0xFFE65100) : const Color(0xFF1565C0); // Orange if early, blue if normal
          icon = Icons.logout_rounded;
          title = '${S.goodbyePrefix}${ok.name}';
          subtitle = isEarlyLeave
              ? 'Ra ca: $timeFormatted (Về sớm < 18:00)'
              : 'Ra ca: $timeFormatted (Đúng giờ)';
        }
        break;
      case ScanRejected _:
        backgroundColor = const Color(0xFFC62828); // Red
        icon = Icons.cancel_outlined;
        title = S.invalidCard;
        subtitle = null;
        break;
      case ScanIgnored ignored:
        backgroundColor = const Color(0xFF616161); // Grey
        icon = Icons.info_outline;
        title = S.alreadyScanned;
        subtitle = ignored.name;
        break;
      case ScanQueuedOffline _:
        backgroundColor = const Color(0xFFF57F17); // Amber/Yellow
        icon = Icons.cloud_off_rounded;
        title = S.scanQueuedOffline;
        subtitle = null;
        break;
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 108, color: Colors.white),
                const SizedBox(height: 32),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
