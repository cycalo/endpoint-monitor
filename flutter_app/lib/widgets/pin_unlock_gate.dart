import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../settings/app_settings_keys.dart';

/// Increment from Settings after changing PIN / lock so [PinUnlockGate] reloads.
final ValueNotifier<int> pinGateReload = ValueNotifier(0);

/// Blocks the app tree until PIN is entered when PIN lock is enabled.
class PinUnlockGate extends StatefulWidget {
  const PinUnlockGate({super.key, required this.child});

  final Widget child;

  @override
  State<PinUnlockGate> createState() => _PinUnlockGateState();
}

class _PinUnlockGateState extends State<PinUnlockGate> with WidgetsBindingObserver {
  static const _kPinSecure = 'em_security_pin';

  bool _loading = true;
  bool _pinLockEnabled = false;
  String? _storedPin;
  bool _unlocked = true;
  DateTime? _pausedAt;
  final _pinInput = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    pinGateReload.addListener(_onPinConfigChanged);
    _reload();
  }

  void _onPinConfigChanged() => _reload();

  @override
  void dispose() {
    pinGateReload.removeListener(_onPinConfigChanged);
    WidgetsBinding.instance.removeObserver(this);
    _pinInput.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final p = await SharedPreferences.getInstance();
    await AppSettingsKeys.ensureDefaults(p);
    const s = FlutterSecureStorage();
    final enabled = p.getBool(AppSettingsKeys.pinLockEnabled) ?? false;
    final pin = await s.read(key: _kPinSecure) ?? '';
    if (!mounted) return;
    setState(() {
      _pinLockEnabled = enabled && pin.length == 4;
      _storedPin = pin.length == 4 ? pin : null;
      _loading = false;
      _unlocked = !_pinLockEnabled;
      _error = null;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_loading || !_pinLockEnabled || _storedPin == null) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _pausedAt = DateTime.now();
        SharedPreferences.getInstance().then((prefs) {
          final mode = prefs.getString(AppSettingsKeys.autoLockTimeout) ?? 'never';
          if (mode == 'immediate' && mounted) {
            setState(() => _unlocked = false);
          }
        });
        break;
      case AppLifecycleState.resumed:
        final paused = _pausedAt;
        if (paused == null) return;
        SharedPreferences.getInstance().then((prefs) {
          final mode = prefs.getString(AppSettingsKeys.autoLockTimeout) ?? 'never';
          final elapsed = DateTime.now().difference(paused);
          if (!mounted) return;
          if (mode == '60' && elapsed.inSeconds >= 60) {
            setState(() => _unlocked = false);
          } else if (mode == '300' && elapsed.inSeconds >= 300) {
            setState(() => _unlocked = false);
          }
        });
        _pausedAt = null;
        break;
      default:
        break;
    }
  }

  void _tryUnlock() {
    final entered = _pinInput.text.trim();
    if (entered == _storedPin) {
      setState(() {
        _unlocked = true;
        _error = null;
        _pinInput.clear();
      });
    } else {
      setState(() => _error = 'Incorrect PIN');
      _pinInput.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Material(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_pinLockEnabled || _unlocked) {
      return widget.child;
    }
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 56, color: scheme.primary),
              const SizedBox(height: 16),
              Text(
                'Enter PIN',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _pinInput,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _tryUnlock(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: scheme.error)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _tryUnlock,
                child: const Text('Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
