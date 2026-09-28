import 'package:flutter/material.dart';

import '../../core/strings.dart';
import 'nfc_service.dart';

class FakeScanDialog extends StatefulWidget {
  final FakeNfcService fakeNfcService;

  const FakeScanDialog({super.key, required this.fakeNfcService});

  static Future<void> show(
    BuildContext context,
    FakeNfcService fakeNfcService,
  ) {
    return showDialog(
      context: context,
      builder: (ctx) => FakeScanDialog(fakeNfcService: fakeNfcService),
    );
  }

  @override
  State<FakeScanDialog> createState() => _FakeScanDialogState();
}

class _FakeScanDialogState extends State<FakeScanDialog> {
  static const _sampleUids = [
    ('04A1B2C3D4E501', 'NV01 - Nguyen Van A'),
    ('04A1B2C3D4E502', 'NV02 - Tran Thi B'),
    ('04A1B2C3D4E503', 'NV03 - Inactive Employee'),
    ('04A1B2C3D4E504', 'NV01 - Locked Card'),
    ('UNKNOWN999999', 'Unknown UID'),
  ];

  final _customUidController = TextEditingController();
  String _selectedUid = _sampleUids.first.$1;

  @override
  void dispose() {
    _customUidController.dispose();
    super.dispose();
  }

  void _triggerScan(String uid) {
    Navigator.of(context).pop();
    widget.fakeNfcService.emit(uid);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(S.fakeNfcButton),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              S.selectSampleUid,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              isExpanded: true,
              value: _selectedUid,
              items: _sampleUids.map((sample) {
                return DropdownMenuItem<String>(
                  value: sample.$1,
                  child: Text(
                    '${sample.$1} (${sample.$2})',
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedUid = val);
              },
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _triggerScan(_selectedUid),
              child: const Text('Quẹt UID đã chọn'),
            ),
            const Divider(height: 32),
            TextField(
              controller: _customUidController,
              decoration: const InputDecoration(
                labelText: 'Hoặc nhập UID tùy ý',
                hintText: 'VD: 04:A1:B2:C3:D4:E5:F6',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                final custom = _customUidController.text.trim();
                if (custom.isNotEmpty) _triggerScan(custom);
              },
              child: const Text('Quẹt UID tùy ý'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(S.cancel),
        ),
      ],
    );
  }
}
