import 'dart:async';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../bloc/connection_bloc.dart';
import '../connect/connect_guide.dart';
import '../connect/connect_path.dart';
import '../connect/connect_session.dart';
import '../connect/pairing_qr.dart';
import '../theme/em_design_system.dart';
import '../widgets/em_brand_app_bar.dart';
import '../widgets/em_loading_states.dart';
import '../widgets/em_technical_grid.dart';

class ConnectQrScanScreen extends StatefulWidget {
  const ConnectQrScanScreen({super.key, required this.path});

  /// Only hosts matching this path are probed after a scan.
  final ConnectPath path;

  @override
  State<ConnectQrScanScreen> createState() => _ConnectQrScanScreenState();
}

class _ConnectQrScanScreenState extends State<ConnectQrScanScreen>
    with WidgetsBindingObserver {
  MobileScannerController? _controller;
  bool _handling = false;
  bool _busy = false;
  String? _errorMessage;
  bool _cameraDenied = false;

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    if (_isMobile) {
      WidgetsBinding.instance.addObserver(this);
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const [BarcodeFormat.qrCode],
      );
      _controller!.start().then((_) => _syncPermissionState());
    }
  }

  @override
  void dispose() {
    if (_isMobile) {
      WidgetsBinding.instance.removeObserver(this);
      _controller?.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isMobile || _controller == null) return;
    if (!_controller!.value.hasCameraPermission) return;
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_controller!.start());
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        unawaited(_controller!.stop());
    }
  }

  void _syncPermissionState() {
    if (!mounted || _controller == null) return;
    setState(() {
      _cameraDenied = !_controller!.value.hasCameraPermission;
    });
  }

  Future<void> _openSettings() async {
    await AppSettings.openAppSettings(type: AppSettingsType.camera);
  }

  Future<void> _toggleTorch() async {
    await _controller?.toggleTorch();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling || _busy) return;
    final raw = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    _handling = true;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    try {
      final parsed = parsePairingQr(raw);
      switch (parsed) {
        case PairingQrParseInvalid(:final message):
          setState(() => _errorMessage = message);
          return;
        case PairingQrParseExpired():
          setState(() => _errorMessage = kPairingQrExpiredMessage);
          return;
        case PairingQrParseOk(:final data):
          final matching = hostsMatchingConnectPath(data.hosts, widget.path);
          if (matching.isEmpty) {
            setState(() => _errorMessage = pairingQrNoHostsForPathMessage(widget.path));
            return;
          }
          final host = await probeFirstReachableHost(matching);
          if (!mounted) return;
          if (host == null) {
            setState(() => _errorMessage = connectUnreachableMessage(widget.path));
            return;
          }

          final bloc = context.read<ConnectionBloc>();
          final result = await completeConnectSession(
            connectionBloc: bloc,
            host: host,
            path: widget.path,
            pairingCode: data.code,
            persistHost: true,
          );

          if (!result.success) {
            setState(() => _errorMessage = result.errorMessage);
            return;
          }

          if (!mounted) return;
          Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _handling = false;
        });
      } else {
        _handling = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: EmBrandAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        EmPageIntro(
                          title: kConnectQrScanTitle,
                          subtitle: connectQrScanSubtitle(widget.path),
                        ),
                        if (!_isMobile)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: EmDesign.cardShell(
                              scheme,
                              color: scheme.surfaceContainerLow,
                            ),
                            child: Text(
                              kConnectQrUnsupportedPlatformMessage,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          )
                        else if (_cameraDenied)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: EmDesign.cardShell(
                              scheme,
                              color: scheme.surfaceContainerLow,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  kConnectQrCameraDeniedMessage,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                FilledButton(
                                  onPressed: _openSettings,
                                  child: const Text(kConnectQrOpenSettingsLabel),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: EmDesign.cardShell(
                              scheme,
                              color: scheme.surfaceContainerLow,
                            ),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  MobileScanner(
                                    controller: _controller,
                                    onDetect: _onDetect,
                                  ),
                                  if (_busy)
                                    const ColoredBox(
                                      color: Color(0x88000000),
                                      child: Center(
                                        child: EmStatusPanel(
                                          loading: true,
                                          message: 'Connecting…',
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        if (_isMobile && !_cameraDenied) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton.filledTonal(
                              tooltip: 'Toggle torch',
                              onPressed: _toggleTorch,
                              icon: const Icon(Icons.flashlight_on_rounded),
                            ),
                          ),
                        ],
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: EmDesign.cardShell(
                              scheme,
                              color: scheme.errorContainer.withValues(alpha: 0.35),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.error,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
