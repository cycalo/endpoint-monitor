import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bloc/connection_bloc.dart';
import '../theme/em_design_system.dart';
import '../widgets/em_brand_app_bar.dart';
import '../widgets/em_gradient_button.dart';
import '../widgets/em_technical_grid.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  static const _kRememberConnect = 'em_remember_connect';
  static const _kSavedHost = 'em_connect_saved_host';
  static const _kSavedToken = 'em_connect_saved_token';

  final _host = TextEditingController();
  final _token = TextEditingController();
  List<String> _recent = const [];
  bool _hideToken = true;
  bool _rememberDetails = false;

  @override
  void initState() {
    super.initState();
    _loadPersisted();
  }

  Future<void> _loadPersisted() async {
    final p = await SharedPreferences.getInstance();
    final remember = p.getBool(_kRememberConnect) ?? false;
    final recent = p.getStringList('em_endpoints') ?? const [];
    if (!remember) {
      if (mounted) {
        setState(() {
          _recent = recent;
          _rememberDetails = false;
        });
      }
      return;
    }
    final host = p.getString(_kSavedHost) ?? '';
    const secure = FlutterSecureStorage();
    final token = await secure.read(key: _kSavedToken) ?? '';
    if (!mounted) return;
    setState(() {
      _recent = recent;
      _rememberDetails = true;
      _host.text = host;
      _token.text = token;
    });
  }

  Future<void> _persistRememberPreference() async {
    final p = await SharedPreferences.getInstance();
    const secure = FlutterSecureStorage();
    if (_rememberDetails) {
      await p.setBool(_kRememberConnect, true);
      await p.setString(_kSavedHost, _host.text.trim());
      await secure.write(key: _kSavedToken, value: _token.text.trim());
    } else {
      await p.setBool(_kRememberConnect, false);
      await p.remove(_kSavedHost);
      await secure.delete(key: _kSavedToken);
    }
  }

  @override
  void dispose() {
    _host.dispose();
    _token.dispose();
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
                                          'Establish connection',
                                          style: theme.textTheme.headlineSmall?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Initialize telemetry for a remote Windows host.',
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
                                          label: 'Remote host address',
                                          child: TextField(
                                            controller: _host,
                                            style: mono,
                                            decoration: InputDecoration(
                                              hintText: '192.168.1.100',
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
                                        const SizedBox(height: 18),
                                        _LabeledField(
                                          label: 'Authentication token',
                                          child: TextField(
                                            controller: _token,
                                            obscureText: _hideToken,
                                            style: mono,
                                            decoration: InputDecoration(
                                              hintText: '••••••••',
                                              hintStyle: mono.copyWith(
                                                color: scheme.outline.withValues(alpha: 0.45),
                                              ),
                                              prefixIcon: Icon(
                                                Icons.key_rounded,
                                                color: scheme.outline,
                                                size: 20,
                                              ),
                                              suffixIcon: IconButton(
                                                onPressed: () =>
                                                    setState(() => _hideToken = !_hideToken),
                                                icon: Icon(
                                                  _hideToken
                                                      ? Icons.visibility_outlined
                                                      : Icons.visibility_off_outlined,
                                                  color: scheme.outline,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        CheckboxListTile(
                                          contentPadding: EdgeInsets.zero,
                                          controlAffinity: ListTileControlAffinity.leading,
                                          value: _rememberDetails,
                                          onChanged: (v) async {
                                            final next = v ?? false;
                                            setState(() => _rememberDetails = next);
                                            if (!next) {
                                              await _persistRememberPreference();
                                            }
                                          },
                                          title: Text(
                                            'Remember host and token on this device',
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
                                          label: switch (state.status) {
                                            ConnectionStatus.connecting => 'Connecting…',
                                            _ => 'Connect to endpoint',
                                          },
                                          icon: Icons.bolt_rounded,
                                          onPressed: state.status == ConnectionStatus.connecting
                                              ? null
                                              : () async {
                                                  await _persistRememberPreference();
                                                  if (!context.mounted) return;
                                                  context.read<ConnectionBloc>().add(
                                                        ConnectionConnectRequested(
                                                          host: _host.text.trim(),
                                                          token: _token.text.trim(),
                                                        ),
                                                      );
                                                },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _MetaPill(scheme: scheme, label: 'WSS / TLS 1.3'),
                                      const SizedBox(width: 20),
                                      _MetaPill(scheme: scheme, label: 'Encrypted channel'),
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
