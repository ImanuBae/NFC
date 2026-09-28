/// Result of a kiosk card scan operation
sealed class ScanResult {
  const ScanResult();
}

class ScanOk extends ScanResult {
  final bool isCheckIn;
  final String name;
  final String code;
  final DateTime at;

  const ScanOk({
    required this.isCheckIn,
    required this.name,
    required this.code,
    required this.at,
  });
}

class ScanRejected extends ScanResult {
  final String reason;

  const ScanRejected({required this.reason});
}

class ScanIgnored extends ScanResult {
  final String? name;

  const ScanIgnored({this.name});
}

class ScanQueuedOffline extends ScanResult {
  const ScanQueuedOffline();
}
