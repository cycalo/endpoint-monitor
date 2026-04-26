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
          return AlertDialog(
            title: const Text('Pairing code'),
            content: TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                hintText: 'Code from Windows tray',
                counterText: '',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(codeController.text.trim()),
                child: Text(
                  'Pair',
                  style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onPrimary),
                ),
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
          SnackBar(content: Text('Pairing failed: $e')),
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
                                  if (_recent.isNotEmpty) ...[
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'RECENT ENDPOINTS',
                                          style: EmDesign.labelCaps(context, scheme),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: _recent.map((h) {
                                        return Material(
                                          color: scheme.surfaceContainerHigh,
                                          borderRadius: BorderRadius.circular(999),
                                          child: InkWell(
                                            onTap: () {
                                              _host.text = h
                                                  .replaceFirst(RegExp(r'^https?://'), '')
                                                  .replaceFirst(RegExp(r'^wss?://'), '');
                                              setState(() {});
                                            },
                                            borderRadius: BorderRadius.circular(999),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(999),
                                                border: EmDesign.ghostBorder(scheme),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 6,
                                                    height: 6,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: scheme.tertiary,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: scheme.tertiary.withValues(alpha: 0.4),
                                                          blurRadius: 6,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    h,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12,
                                                      color: scheme.onSurface,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 22),
                                  ],
                                  _LabeledField(
                                    label: 'IP address',
                                    child: TextField(
                                      controller: _host,
                                      style: mono,
                                      keyboardType: TextInputType.text,
                                      decoration: InputDecoration(
                                        hintText: 'IP address',
                                        hintStyle: mono.copyWith(
                                          color: scheme.outline.withValues(alpha: 0.45),
                                        ),
                                        prefixIcon: Icon(
                                          Icons.lan_rounded,
                                          color: scheme.outline,
                                          size: 20,
                                        ),
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
                                  if (hasToken) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(Icons.verified_user_outlined, size: 16, color: scheme.tertiary),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'This device is paired. Use Connect when the PC is reachable.',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 18),
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    controlAffinity: ListTileControlAffinity.leading,
                                    value: _rememberDetails,
                                    onChanged: (v) async {
                                      final next = v ?? false;
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
                                    title: Text(
                                      'Remember this IP on this device',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                  if (state.message != null) ...[
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: scheme.errorContainer.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(EmDesign.radiusMd),
                                        border: Border.all(
                                          color: scheme.error.withValues(alpha: 0.15),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.error_outline_rounded,
                                            color: scheme.error,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              state.message!,
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: scheme.onErrorContainer,
                                                height: 1.35,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 22),
                                  EmGradientButton(
                                    label: _pairing ? 'Pairing…' : 'Pair with code',
                                    icon: Icons.phonelink_lock_rounded,
                                    inProgress: _pairing,
                                    onPressed: (state.status == ConnectionStatus.connecting || _pairing)
                                        ? null
                                        : _pairDeviceWithCode,
                                  ),
                                  const SizedBox(height: 10),
                                  OutlinedButton.icon(
                                    onPressed: (state.status == ConnectionStatus.connecting || _pairing)
                                        ? null
                                        : () async {
                                            final host = _host.text.trim();
                                            if (host.isEmpty) {
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Enter the PC IP address.')),
                                              );
                                              return;
                                            }
                                            const secure = FlutterSecureStorage();
                                            var token = await secure.read(key: _kEmToken) ?? '';
                                            if (token.isEmpty) {
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Pair with a code from the Windows tray first.'),
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
                                    icon: const Icon(Icons.bolt_rounded),
                                    label: Text(
                                      state.status == ConnectionStatus.connecting
                                          ? 'Connecting…'
                                          : 'Connect to endpoint',
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                  ),
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
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
