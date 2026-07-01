import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bloc/connection_bloc.dart';
import '../theme/em_design_system.dart';
import '../utils/export_http_base.dart';
import '../widgets/em_brand_app_bar.dart';
import '../widgets/em_gradient_button.dart';
import '../widgets/em_loading_states.dart';
import '../widgets/em_technical_grid.dart';

/// Same keys as [ConnectionBloc] for host and paired device token.
const _kEmHost = 'em_host';
const _kEmToken = 'em_token';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  static const _kRememberConnect = 'em_remember_connect';
  static const _kSavedHost = 'em_connect_saved_host';

  final _host = TextEditingController();
  List<String> _recent = const [];
  bool _rememberDetails = false;
  bool _pairing = false;
  int _onboardingStep = 0;
  /// True if [em_token] is present in secure storage (pairing already done on this device).
  bool? _hasDeviceToken;

  @override
  void initState() {
    super.initState();
    _loadPersisted();
  }

  Future<void> _loadPersisted() async {
    const secure = FlutterSecureStorage();
    final p = await SharedPreferences.getInstance();
    final remember = p.getBool(_kRememberConnect) ?? false;
    final recent = p.getStringList('em_endpoints') ?? const [];
    final t = await secure.read(key: _kEmToken);
    if (!mounted) return;
    setState(() {
      _rememberDetails = remember;
      _recent = recent;
      _hasDeviceToken = t != null && t.isNotEmpty;
    });
    if (remember) {
      final host = p.getString(_kSavedHost) ?? await secure.read(key: _kEmHost) ?? '';
      if (!mounted) return;
      setState(() {
        if (host.isNotEmpty) _host.text = host;
      });
    }
  }

  /// Saves remembered IP only. Does not remove credentials (use [_clearCredentials] for that).
  Future<void> _saveRememberedHost() async {
    final p = await SharedPreferences.getInstance();
    if (_rememberDetails) {
      await p.setBool(_kRememberConnect, true);
      await p.setString(_kSavedHost, _host.text.trim());
      const secure = FlutterSecureStorage();
      await secure.write(key: _kEmHost, value: _host.text.trim());
    } else {
      await p.setBool(_kRememberConnect, false);
      await p.remove(_kSavedHost);
    }
  }

  /// Forgets saved IP only. Paired [em_token] is kept so the user can enter the address again and connect.
  Future<void> _clearRememberedIpOnly() async {
    const secure = FlutterSecureStorage();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kRememberConnect, false);
    await p.remove(_kSavedHost);
    await secure.delete(key: _kEmHost);
  }

  Future<void> _pairDeviceWithCode() async {
    final host = _host.text.trim();
    if (host.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the PC IP address first.')),
      );
      return;
    }

    final codeController = TextEditingController();
    try {
      final code = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final theme = Theme.of(ctx);
          final scheme = theme.colorScheme;
          return AlertDialog(
            title: Text(
              'Pairing code',
              style: theme.textTheme.titleLarge,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Enter the six-digit code shown in the Windows tray app.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: EmDesign.spaceMd),
                TextField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 22,
                    letterSpacing: 8,
                    color: scheme.onSurface,
                  ),
                  decoration: const InputDecoration(
                    hintText: '000000',
                    counterText: '',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(codeController.text.trim()),
                child: const Text('Pair device'),
              ),
            ],
          );
        },
      );
      if (code == null || code.isEmpty) return;

      if (mounted) setState(() => _pairing = true);
      final base = httpBaseFromMonitorHost(host);
      final dio = Dio(BaseOptions(
        baseUrl: base,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
      final response = await dio.post<Map<String, dynamic>>(
        '/api/auth/pairing/complete',
        data: {
          'code': code,
          'deviceName': 'Flutter ${Platform.operatingSystem}',
        },
      );
      final token = response.data?['token']?.toString();
      if (token == null || token.isEmpty) {
        throw StateError('No device credential returned.');
      }
      const secure = FlutterSecureStorage();
      await secure.write(key: _kEmToken, value: token);
      await secure.write(key: _kEmHost, value: host);
      await _saveRememberedHost();
      if (!mounted) return;
      setState(() => _hasDeviceToken = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paired. You can connect now.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pairing failed. Check the code and endpoint, then try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _pairing = false);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        codeController.dispose();
      });
    }
  }

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mono = GoogleFonts.jetBrainsMono(fontSize: 13, color: scheme.onSurface);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: const EmBrandAppBar(),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.35),
                  radius: 1.15,
                  colors: [
                    scheme.surfaceContainer.withValues(alpha: 0.65),
                    scheme.surface,
                  ],
                ),
              ),
            ),
          ),
          EmTechnicalGrid(
            child: SafeArea(
              child: BlocConsumer<ConnectionBloc, EmConnectionState>(
                listener: (context, state) {
                  if (state.status == ConnectionStatus.connected) {
                    context.goNamed('dashboard');
                  }
                },
                builder: (context, state) {
                  final hasToken = _hasDeviceToken == true;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainer,
                                    borderRadius: BorderRadius.circular(EmDesign.radiusMd),
                                    border: EmDesign.ghostBorder(scheme),
                                    boxShadow: [
                                      BoxShadow(
                                        color: scheme.primary.withValues(alpha: 0.08),
                                        blurRadius: 24,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.monitor_heart_rounded,
                                    size: 30,
                                    color: scheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'ENDPOINT MONITOR',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 3,
                                    color: scheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: EmDesign.cardShell(
                                scheme,
                                color: scheme.surfaceContainerLow,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Connect to your PC',
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Enter the PC’s IP, pair once with a code from the Windows tray, then connect.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 22),
                                  if (_hasDeviceToken == null)
                                    const EmStatusPanel(
                                      loading: true,
                                      message: 'Checking device pairing…',
                                    )
                                  else ...[
                                  _ConnectStepIndicator(
                                    step: _onboardingStep,
                                    includePairing: !hasToken,
                                  ),
                                  const SizedBox(height: 20),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 280),
                                    switchInCurve: Curves.easeOutCubic,
                                    child: _onboardingStep == 0
                                        ? _ConnectAddressStep(
                                            key: const ValueKey('addr'),
                                            scheme: scheme,
                                            theme: theme,
                                            mono: mono,
                                            recent: _recent,
                                            host: _host,
                                            rememberDetails: _rememberDetails,
                                            onRecentTap: (h) {
                                              _host.text = h
                                                  .replaceFirst(RegExp(r'^https?://'), '')
                                                  .replaceFirst(RegExp(r'^wss?://'), '');
                                              setState(() {});
                                            },
                                            onRememberChanged: (next) async {
                                              if (!next) {
                                                await _clearRememberedIpOnly();
                                                if (mounted) {
                                                  setState(() => _rememberDetails = false);
                                                }
                                                return;
                                              }
                                              if (mounted) {
                                                setState(() => _rememberDetails = true);
                                              }
                                              await _saveRememberedHost();
                                            },
                                            onNext: () {
                                              if (_host.text.trim().isEmpty) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Enter the PC IP address first.'),
                                                  ),
                                                );
                                                return;
                                              }
                                              setState(() {
                                                _onboardingStep = hasToken ? 1 : 1;
                                              });
                                            },
                                          )
                                        : (_onboardingStep == 1 && !hasToken)
                                            ? _ConnectPairStep(
                                                key: const ValueKey('pair'),
                                                scheme: scheme,
                                                theme: theme,
                                                pairing: _pairing,
                                                connecting: state.status == ConnectionStatus.connecting,
                                                onBack: () => setState(() => _onboardingStep = 0),
                                                onPair: _pairDeviceWithCode,
                                                onNext: () => setState(() => _onboardingStep = 2),
                                                hasToken: hasToken,
                                              )
                                            : _ConnectFinalStep(
                                                key: const ValueKey('connect'),
                                                scheme: scheme,
                                                theme: theme,
                                                state: state,
                                                hasToken: hasToken,
                                                pairing: _pairing,
                                                onBack: () => setState(
                                                  () => _onboardingStep = hasToken ? 0 : 1,
                                                ),
                                                onConnect: () async {
                                                  final host = _host.text.trim();
                                                  if (host.isEmpty) {
                                                    if (!context.mounted) return;
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        content: Text('Enter the PC IP address.'),
                                                      ),
                                                    );
                                                    return;
                                                  }
                                                  const secure = FlutterSecureStorage();
                                                  var token = await secure.read(key: _kEmToken) ?? '';
                                                  if (token.isEmpty) {
                                                    if (!context.mounted) return;
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Pair with a code from the Windows tray first.',
                                                        ),
                                                      ),
                                                    );
                                                    return;
                                                  }
                                                  await _saveRememberedHost();
                                                  if (!context.mounted) return;
                                                  context.read<ConnectionBloc>().add(
                                                        ConnectionConnectRequested(
                                                          host: host,
                                                          token: token,
                                                        ),
                                                      );
                                                },
                                                onPair: _pairDeviceWithCode,
                                              ),
                                  ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _MetaPill(scheme: scheme, label: 'Pairing + TLS'),
                                const SizedBox(width: 20),
                                _MetaPill(scheme: scheme, label: 'Tailscale / LAN'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.scheme, required this.label});

  final ColorScheme scheme;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.tertiary,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: EmDesign.labelCaps(context, scheme)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _ConnectStepIndicator extends StatelessWidget {
  const _ConnectStepIndicator({
    required this.step,
    required this.includePairing,
  });

  final int step;
  final bool includePairing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labels = includePairing
        ? const ['Address', 'Pair', 'Connect']
        : const ['Address', 'Connect'];

    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: i <= step
                    ? scheme.primary.withValues(alpha: 0.55)
                    : scheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= step
                      ? scheme.primary.withValues(alpha: i == step ? 0.22 : 0.12)
                      : scheme.surfaceContainerHigh,
                  border: Border.all(
                    color: i <= step
                        ? scheme.primary
                        : scheme.outlineVariant.withValues(alpha: 0.25),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${i + 1}',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: i <= step ? scheme.primary : scheme.outline,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                labels[i].toUpperCase(),
                style: EmDesign.labelCaps(context, scheme).copyWith(
                  fontSize: 8,
                  color: i == step ? scheme.primary : scheme.outline,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ConnectAddressStep extends StatelessWidget {
  const _ConnectAddressStep({
    super.key,
    required this.scheme,
    required this.theme,
    required this.mono,
    required this.recent,
    required this.host,
    required this.rememberDetails,
    required this.onRecentTap,
    required this.onRememberChanged,
    required this.onNext,
  });

  final ColorScheme scheme;
  final ThemeData theme;
  final TextStyle mono;
  final List<String> recent;
  final TextEditingController host;
  final bool rememberDetails;
  final ValueChanged<String> onRecentTap;
  final ValueChanged<bool> onRememberChanged;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (recent.isNotEmpty) ...[
          Text('RECENT ENDPOINTS', style: EmDesign.labelCaps(context, scheme)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: recent.map((h) {
              return Material(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  onTap: () => onRecentTap(h),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: EmDesign.ghostBorder(scheme),
                    ),
                    child: Text(h, style: GoogleFonts.inter(fontSize: 12)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
        ],
        _LabeledField(
          label: 'IP address',
          child: TextField(
            controller: host,
            style: mono,
            decoration: InputDecoration(
              hintText: 'IP address',
              prefixIcon: Icon(Icons.lan_rounded, color: scheme.outline, size: 20),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Optional: include :port (default 5000).',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 14),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: rememberDetails,
          onChanged: (v) => onRememberChanged(v ?? false),
          title: Text(
            'Remember this IP on this device',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 12),
        EmGradientButton(label: 'Continue', icon: Icons.arrow_forward_rounded, onPressed: onNext),
      ],
    );
  }
}

class _ConnectPairStep extends StatelessWidget {
  const _ConnectPairStep({
    super.key,
    required this.scheme,
    required this.theme,
    required this.pairing,
    required this.connecting,
    required this.onBack,
    required this.onPair,
    required this.onNext,
    required this.hasToken,
  });

  final ColorScheme scheme;
  final ThemeData theme;
  final bool pairing;
  final bool connecting;
  final VoidCallback onBack;
  final VoidCallback onPair;
  final VoidCallback onNext;
  final bool hasToken;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Pair this phone with your PC using the six-digit code from the Windows tray.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        EmGradientButton(
          label: pairing ? 'Pairing…' : 'Pair with code',
          icon: Icons.phonelink_lock_rounded,
          inProgress: pairing,
          onPressed: (connecting || pairing) ? null : onPair,
        ),
        if (hasToken) ...[
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onNext, child: const Text('Already paired — continue')),
        ],
        const SizedBox(height: 10),
        OutlinedButton(onPressed: onBack, child: const Text('Back')),
      ],
    );
  }
}

class _ConnectFinalStep extends StatelessWidget {
  const _ConnectFinalStep({
    super.key,
    required this.scheme,
    required this.theme,
    required this.state,
    required this.hasToken,
    required this.pairing,
    required this.onBack,
    required this.onConnect,
    required this.onPair,
  });

  final ColorScheme scheme;
  final ThemeData theme;
  final EmConnectionState state;
  final bool hasToken;
  final bool pairing;
  final VoidCallback onBack;
  final VoidCallback onConnect;
  final VoidCallback onPair;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasToken)
          Row(
            children: [
              Icon(Icons.verified_user_outlined, size: 16, color: scheme.tertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Device paired. Connect when the PC is reachable on your network.',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          )
        else
          Text(
            'Pair first, then connect to start live monitoring.',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        if (state.message != null) ...[
          const SizedBox(height: 12),
          EmStatusPanel(icon: Icons.error_outline_rounded, message: state.message!),
        ],
        const SizedBox(height: 16),
        EmGradientButton(
          label: state.status == ConnectionStatus.connecting ? 'Connecting…' : 'Connect',
          icon: Icons.bolt_rounded,
          inProgress: state.status == ConnectionStatus.connecting,
          onPressed: (state.status == ConnectionStatus.connecting || pairing) ? null : onConnect,
        ),
        if (!hasToken) ...[
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onPair, child: const Text('Pair with code instead')),
        ],
        const SizedBox(height: 10),
        OutlinedButton(onPressed: onBack, child: const Text('Back')),
      ],
    );
  }
}
