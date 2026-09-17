import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bloc/connection_bloc.dart';
import '../connect/connect_guide.dart';
import '../connect/connect_path.dart';
import '../connect/connect_persistence.dart';
import '../connect/connect_session.dart';
import '../connect/connect_validation.dart';
import '../theme/em_design_system.dart';
import '../utils/agent_health.dart';
import '../utils/device_token_status.dart';
import '../widgets/em_brand_app_bar.dart';
import '../widgets/em_loading_states.dart';
import '../widgets/em_technical_grid.dart';
import 'connect_chooser.dart';
import 'connect_guided_page.dart';
import 'connect_qr_scan_screen.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _address = TextEditingController();
  final _code = TextEditingController();

  ConnectPath? _selectedPath;
  bool _busy = false;
  String? _inlineError;
  bool? _hasDeviceToken;
  ConnectPath? _savedPath;
  ConnectPersistedPaths _persisted = const ConnectPersistedPaths(
    savedHosts: {},
    rememberAddress: {},
  );

  @override
  void initState() {
    super.initState();
    _loadPersisted();
  }

  Future<void> _loadPersisted() async {
    const secure = FlutterSecureStorage();
    final p = await SharedPreferences.getInstance();
    await migrateLegacyConnectPrefs(
      p,
      secureHost: await secure.read(key: kEmHost),
    );
    final persisted = loadConnectPersistedPaths(p);
    final token = await secure.read(key: kEmToken);
    final pathPref = connectPathFromPref(p.getString(kConnectPathPrefKey));

    if (!mounted) return;

    var hasToken = token != null && token.isNotEmpty;
    ConnectPath? lastPath = pathPref;
    if (lastPath == null) {
      for (final path in ConnectPath.values) {
        if (persisted.savedHosts[path] != null) {
          lastPath = path;
          break;
        }
      }
    }
    final rememberedHost = lastPath == null ? null : persisted.savedHosts[lastPath];
    if (hasToken && rememberedHost != null) {
      final status = await probeDeviceToken(rememberedHost, token);
      if (status == DeviceTokenStatus.revoked) {
        await secure.delete(key: kEmToken);
        hasToken = false;
      }
    }

    if (!mounted) return;
    setState(() {
      _hasDeviceToken = hasToken;
      _persisted = persisted;
      _savedPath = lastPath;
    });
  }

  Future<void> _persistPath(ConnectPath path) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(kConnectPathPrefKey, connectPathToPref(path));
  }

  void _selectPath(ConnectPath path) {
    setState(() {
      _selectedPath = path;
      _inlineError = null;
      _address.text = connectAddressForPath(path, _persisted) ?? '';
    });
    _persistPath(path);
  }

  void _openSavedSession() {
    final path = _savedPath;
    if (path == null) return;
    final host = _persisted.savedHosts[path];
    if (host == null || host.isEmpty) return;
    setState(() {
      _selectedPath = path;
      _address.text = host;
      _inlineError = null;
    });
    _persistPath(path);
  }

  void _backToChooser() {
    setState(() {
      _selectedPath = null;
      _inlineError = null;
    });
  }

  Future<void> _openQrScanner() async {
    setState(() => _inlineError = null);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => const ConnectQrScanScreen(),
      ),
    );
    if (!mounted) return;
    const secure = FlutterSecureStorage();
    final token = await secure.read(key: kEmToken);
    if (token != null && token.isNotEmpty) {
      setState(() => _hasDeviceToken = true);
    }
  }

  Future<void> _saveRememberedHost(String host, ConnectPath path) async {
    const secure = FlutterSecureStorage();
    final p = await SharedPreferences.getInstance();
    final remember = _persisted.rememberAddress[path] ?? true;
    if (remember) {
      await p.setBool(rememberConnectPrefKey(path), true);
      await p.setString(savedHostPrefKey(path), host);
      await secure.write(key: kEmHost, value: host);
      if (!mounted) return;
      setState(() {
        _persisted = ConnectPersistedPaths(
          savedHosts: {..._persisted.savedHosts, path: host},
          rememberAddress: {..._persisted.rememberAddress, path: true},
        );
        _savedPath = path;
      });
    } else {
      await p.setBool(rememberConnectPrefKey(path), false);
      await p.remove(savedHostPrefKey(path));
      if (!mounted) return;
      setState(() {
        _persisted = ConnectPersistedPaths(
          savedHosts: {..._persisted.savedHosts, path: null},
          rememberAddress: {..._persisted.rememberAddress, path: false},
        );
      });
    }
  }

  Future<void> _clearRememberedHostOnly(ConnectPath path) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(rememberConnectPrefKey(path), false);
    await p.remove(savedHostPrefKey(path));
    if (!mounted) return;
    setState(() {
      _persisted = ConnectPersistedPaths(
        savedHosts: {..._persisted.savedHosts, path: null},
        rememberAddress: {..._persisted.rememberAddress, path: false},
      );
    });
  }

  Future<void> _forgetLocalPairing() async {
    const secure = FlutterSecureStorage();
    await secure.delete(key: kEmToken);
    if (!mounted) return;
    setState(() {
      _hasDeviceToken = false;
      _inlineError = null;
    });
  }

  Future<void> _connect() async {
    final path = _selectedPath;
    if (path == null) return;

    final host = _address.text.trim();
    final addressResult = validateConnectAddress(host);
    if (addressResult is ConnectValidationError) {
      setState(() => _inlineError = addressResult.message);
      return;
    }

    final hasToken = _hasDeviceToken == true;
    if (!hasToken) {
      final codeResult = validatePairingCode(_code.text);
      if (codeResult is ConnectValidationError) {
        setState(() => _inlineError = codeResult.message);
        return;
      }
    }

    setState(() {
      _busy = true;
      _inlineError = null;
    });

    try {
      final reachable = await probeAgentHealth(host);
      if (!reachable) {
        if (mounted) {
          setState(() => _inlineError = connectUnreachableMessage(path));
        }
        return;
      }
      if (!mounted) return;

      final bloc = context.read<ConnectionBloc>();
      final result = await completeConnectSession(
        connectionBloc: bloc,
        host: host,
        path: path,
        pairingCode: hasToken ? null : _code.text.trim(),
        persistHost: false,
      );
      if (!result.success) {
        if (mounted) {
          setState(() {
            _inlineError = result.errorMessage;
            if (result.clearedStoredToken) {
              _hasDeviceToken = false;
            }
          });
        }
        return;
      }
      if (result.obtainedNewToken && mounted) {
        setState(() => _hasDeviceToken = true);
      }
      await _saveRememberedHost(host, path);
      await _persistPath(path);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _address.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

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
                  if (state.message == kDeviceUnpairedMessage &&
                      _hasDeviceToken == true) {
                    setState(() => _hasDeviceToken = false);
                  }
                },
                builder: (context, state) {
                  final continueHost = _savedPath == null
                      ? null
                      : _persisted.savedHosts[_savedPath!];
                  final showContinueChip =
                      _hasDeviceToken == true &&
                      continueHost != null &&
                      continueHost.isNotEmpty;

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
                              child: Material(
                                type: MaterialType.transparency,
                                child: _hasDeviceToken == null
                                    ? const EmStatusPanel(
                                        loading: true,
                                        message: 'Checking device pairing…',
                                      )
                                    : AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 280),
                                        switchInCurve: Curves.easeOutCubic,
                                        child: _selectedPath == null
                                            ? ConnectChooser(
                                                key: const ValueKey('chooser'),
                                                savedHost: showContinueChip ? continueHost : null,
                                                savedPath: _savedPath,
                                                onContinueSaved: showContinueChip ? _openSavedSession : null,
                                                onPathSelected: _selectPath,
                                                onScanQr: _openQrScanner,
                                              )
                                            : ConnectGuidedPage(
                                                key: ValueKey('guided-${_selectedPath!.name}'),
                                                path: _selectedPath!,
                                                alreadyPaired: _hasDeviceToken == true,
                                                addressController: _address,
                                                codeController: _code,
                                                rememberAddress:
                                                    _persisted.rememberAddress[_selectedPath!] ??
                                                    true,
                                                busy: _busy,
                                                connecting: state.status == ConnectionStatus.connecting,
                                                errorMessage: _inlineError ?? state.message,
                                                onRememberChanged: (next) async {
                                                  final path = _selectedPath!;
                                                  if (!next) {
                                                    await _clearRememberedHostOnly(path);
                                                    return;
                                                  }
                                                  if (mounted) {
                                                    setState(() {
                                                      _persisted = ConnectPersistedPaths(
                                                        savedHosts: _persisted.savedHosts,
                                                        rememberAddress: {
                                                          ..._persisted.rememberAddress,
                                                          path: true,
                                                        },
                                                      );
                                                    });
                                                  }
                                                  if (_address.text.trim().isNotEmpty) {
                                                    await _saveRememberedHost(
                                                      _address.text.trim(),
                                                      path,
                                                    );
                                                  }
                                                },
                                                onBack: _backToChooser,
                                                onConnect: _connect,
                                                onPairAgain: _forgetLocalPairing,
                                              ),
                                      ),
                              ),
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
