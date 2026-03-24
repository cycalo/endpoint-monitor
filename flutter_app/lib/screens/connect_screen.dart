import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bloc/connection_bloc.dart';
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
      body: EmTechnicalGrid(
        child: SafeArea(
          child: BlocConsumer<ConnectionBloc, EmConnectionState>(
            listener: (context, state) {
              if (state.status == ConnectionStatus.connected) {
                context.goNamed('dashboard');
              }
            },
            builder: (context, state) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 8),
                              Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: scheme.surfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: scheme.shadow,
                                          blurRadius: 24,
                                          offset: const Offset(0, 12),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.terminal_rounded,
                                      size: 48,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    'Connect to Endpoint',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Enter the host address and your bearer token to securely monitor this device.',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 28),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: scheme.shadow,
                                      blurRadius: 32,
                                      offset: const Offset(0, 16),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      if (_recent.isNotEmpty) ...[
                                        Text(
                                          'RECENT ENDPOINTS',
                                          style: theme.textTheme.labelSmall,
                                        ),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: _recent.map((h) {
                                            return Material(
                                              color: scheme.surfaceContainerHigh,
                                              borderRadius: BorderRadius.circular(6),
                                              child: InkWell(
                                                onTap: () {
                                                  _host.text = h
                                                      .replaceFirst(RegExp(r'^https?://'), '')
                                                      .replaceFirst(RegExp(r'^ws://'), '');
                                                },
                                                borderRadius: BorderRadius.circular(6),
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                                  child: Text(
                                                    h,
                                                    style: mono.copyWith(fontSize: 11),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                        const SizedBox(height: 22),
                                      ],
                                      _LabeledField(
                                        label: 'Host Address',
                                        child: TextField(
                                          controller: _host,
                                          style: mono,
                                          decoration: InputDecoration(
                                            hintText: '192.168.1.100 or endpoint-monitor.local',
                                            hintStyle: mono.copyWith(
                                              color: scheme.outline.withValues(alpha: 0.45),
                                            ),
                                            prefixIcon: Icon(
                                              Icons.link_rounded,
                                              color: scheme.outline,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      _LabeledField(
                                        label: 'Bearer Token',
                                        child: TextField(
                                          controller: _token,
                                          obscureText: _hideToken,
                                          style: mono,
                                          decoration: InputDecoration(
                                            hintText: 'Enter authentication token',
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
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: scheme.error.withValues(alpha: 0.1),
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
                                          _ => 'Connect',
                                        },
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
                              ),
                              const SizedBox(height: 22),
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: scheme.outlineVariant.withValues(alpha: 0.1),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _MetaCell(
                                      label: 'Protocol',
                                      value: 'WSS/TLS 1.3',
                                      mono: mono,
                                    ),
                                  ),
                                  Expanded(
                                    child: _MetaCell(
                                      label: 'Encryption',
                                      value: 'AES-256-GCM',
                                      mono: mono,
                                    ),
                                  ),
                                  Expanded(
                                    child: _MetaCell(
                                      label: 'Region',
                                      value: 'Global',
                                      mono: mono,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.4,
                ),
          ),
        ),
        child,
      ],
    );
  }
}

class _MetaCell extends StatelessWidget {
  const _MetaCell({
    required this.label,
    required this.value,
    required this.mono,
  });

  final String label;
  final String value;
  final TextStyle mono;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 9,
                letterSpacing: 0.5,
                color: scheme.outline,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: mono.copyWith(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
