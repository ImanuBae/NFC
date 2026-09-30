import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../core/supabase_client.dart';
import 'device_config.dart';

class KioskSetupPage extends ConsumerStatefulWidget {
  const KioskSetupPage({super.key});

  @override
  ConsumerState<KioskSetupPage> createState() => _KioskSetupPageState();
}

class _KioskSetupPageState extends ConsumerState<KioskSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _registerDevice() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      final response = await client.rpc(
        'register_device',
        params: {'p_name': _nameController.text.trim()},
      );

      final deviceId = response as String;
      await ref.read(deviceConfigProvider).saveDeviceId(deviceId);

      // Reload/redirect will take user to /kiosk
      if (mounted) {
        context.go('/kiosk');
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
      appBar: AppBar(title: const Text(S.kioskSetupTitle)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.devices_outlined,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    S.kioskSetupTitle,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: S.deviceName,
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return S.deviceNameEmpty;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _registerDevice,
                    icon: const Icon(Icons.check),
                    label: Text(_isLoading ? S.loading : S.registerDevice),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
