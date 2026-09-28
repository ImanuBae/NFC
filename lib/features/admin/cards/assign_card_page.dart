import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../../core/uid.dart';
import '../../kiosk/nfc_service.dart';
import '../employees/employee_detail_page.dart';
import 'card_repository.dart';

class AssignCardPage extends ConsumerStatefulWidget {
  final String employeeId;

  const AssignCardPage({super.key, required this.employeeId});

  @override
  ConsumerState<AssignCardPage> createState() => _AssignCardPageState();
}

class _AssignCardPageState extends ConsumerState<AssignCardPage> {
  final _uidController = TextEditingController();
  bool _isReadingNfc = false;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<String>? _nfcSub;

  @override
  void dispose() {
    _uidController.dispose();
    _nfcSub?.cancel();
    super.dispose();
  }

  Future<void> _startNfcRead() async {
    final nfc = ref.read(nfcServiceProvider);
    final available = await nfc.isAvailable();
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text(S.nfcDisabledWarning)));
      }
      return;
    }

    setState(() {
      _isReadingNfc = true;
      _error = null;
    });

    await nfc.start();
    _nfcSub?.cancel();
    _nfcSub = nfc.uids.listen((uid) async {
      if (mounted) {
        setState(() {
          _uidController.text = normalizeUid(uid);
          _isReadingNfc = false;
        });
        await nfc.stop();
        _nfcSub?.cancel();
      }
    });
  }

  Future<void> _stopNfcRead() async {
    final nfc = ref.read(nfcServiceProvider);
    await nfc.stop();
    _nfcSub?.cancel();
    if (mounted) setState(() => _isReadingNfc = false);
  }

  Future<void> _assignCard() async {
    final rawUid = _uidController.text.trim();
    final uid = normalizeUid(rawUid);

    if (uid.isEmpty) {
      setState(() => _error = S.uidEmpty);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final repo = ref.read(cardRepositoryProvider);

    try {
      final exists = await repo.isCardExists(uid);
      if (exists) {
        if (mounted) {
          setState(() {
            _error = S.cardAlreadyExists;
            _isLoading = false;
          });
        }
        return;
      }

      await repo.assignCard(uid: uid, employeeId: widget.employeeId);
      ref.invalidate(employeeCardsProvider(widget.employeeId));

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text(S.assignCard)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(
                      _isReadingNfc ? Icons.sensors_rounded : Icons.nfc_rounded,
                      size: 64,
                      color: _isReadingNfc
                          ? Colors.orange
                          : theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isReadingNfc ? S.readingCard : S.tapCardToRead,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isReadingNfc)
                      OutlinedButton.icon(
                        onPressed: _stopNfcRead,
                        icon: const Icon(Icons.stop),
                        label: const Text(S.cancel),
                      )
                    else
                      FilledButton.tonalIcon(
                        onPressed: _startNfcRead,
                        icon: const Icon(Icons.sensors),
                        label: const Text(S.tapCardToRead),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _uidController,
              decoration: const InputDecoration(
                labelText: S.manualUid,
                hintText: 'VD: 04A1B2C3D4E501',
                prefixIcon: Icon(Icons.credit_card),
              ),
              textCapitalization: TextCapitalization.characters,
              onChanged: (val) {
                final normalized = normalizeUid(val);
                if (normalized != val) {
                  _uidController.value = TextEditingValue(
                    text: normalized,
                    selection: TextSelection.collapsed(
                      offset: normalized.length,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _isLoading ? null : _assignCard,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(_isLoading ? S.loading : S.save),
            ),
          ],
        ),
      ),
    );
  }
}
