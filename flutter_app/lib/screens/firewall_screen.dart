import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../bloc/connection_bloc.dart';
import '../bloc/firewall_bloc.dart';
import '../bloc/process_bloc.dart';
import '../models/ws_models.dart';
import '../theme/em_design_system.dart';
import '../widgets/em_brand_app_bar.dart';
import '../widgets/em_loading_states.dart';

class FirewallScreen extends StatefulWidget {
  const FirewallScreen({super.key});

  @override
  State<FirewallScreen> createState() => _FirewallScreenState();
}

class _FirewallScreenState extends State<FirewallScreen>
    with SingleTickerProviderStateMixin {
  final _ipController = TextEditingController();
  final _manualPortController = TextEditingController();
  final _processNameController = TextEditingController();
  String _manualDirection = 'outbound';
  String _processDirection = 'outbound';
  String _ipExpiryChoice = 'perm';
  String _processExpiryChoice = 'perm';
  int _firewallSection = 0;
  String? _ipError;
  String? _portError;
  String? _processNameError;
  late final AnimationController _pulseController;

  static int? _expiryHours(String choice) {
    switch (choice) {
      case '1':
        return 1;
      case '24':
        return 24;
      case '168':
        return 168;
      default:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final conn = context.read<ConnectionBloc>().state;
      if (conn.isConnected) {
        context.read<FirewallBloc>().refresh();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  static String _directionLabel(String d) {
    switch (d.toLowerCase()) {
      case 'inbound':
        return 'Inbound';
      case 'both':
        return 'Both';
      default:
        return 'Outbound';
    }
  }

  static String _relativeTime(DateTime utc) {
    final now = DateTime.now().toUtc();
    var diff = now.difference(utc.toUtc());
    if (diff.isNegative) diff = Duration.zero;
    if (diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return '$m minute${m == 1 ? '' : 's'} ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return '$h hour${h == 1 ? '' : 's'} ago';
    }
    if (diff.inDays < 14) {
      final d = diff.inDays;
      return '$d day${d == 1 ? '' : 's'} ago';
    }
    final w = (diff.inDays / 7).floor();
    return '$w week${w == 1 ? '' : 's'} ago';
  }

  static bool _isValidIp(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return false;
    try {
      final a = InternetAddress(s);
      return a.type == InternetAddressType.IPv4 ||
          a.type == InternetAddressType.IPv6;
    } catch (_) {
      return false;
    }
  }

  Future<void> _onPullRefresh(BuildContext context) async {
    final bloc = context.read<FirewallBloc>();
    if (!context.read<ConnectionBloc>().state.isConnected) return;
    bloc.refresh(isPull: true);
    await bloc.stream.firstWhere((s) => !s.pullRefreshing);
  }

  Future<void> _showIsolateBottomSheet(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: scheme.surfaceContainerHigh,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Isolate this machine?',
                style: Theme.of(c).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Blocks all network traffic except the monitoring connection — use this to contain a suspected compromise.',
                style: Theme.of(c).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                ),
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Continue to confirm'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirm isolation'),
        content: const Text(
          'This will apply Windows Firewall rules that block broad traffic while keeping the Endpoint Monitor channel. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(c).colorScheme.error,
              foregroundColor: Theme.of(c).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Isolate machine'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<FirewallBloc>().requestIsolate();
    }
  }

  Future<void> _confirmUnisolate(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remove isolation?'),
        content: const Text(
          'Network restrictions added for isolation will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Unisolate'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<FirewallBloc>().requestUnisolate();
    }
  }

  String _blockSummary(FirewallBlockEntry e) {
    switch (e.blockKind) {
      case 'process':
        return e.processName ?? 'this process';
      case 'port':
        final p = e.ip != null && e.ip!.startsWith('port:')
            ? e.ip!.substring(5)
            : '${e.remotePort ?? ''}';
        return 'outbound TCP port $p';
      default:
        return e.ip ?? '';
    }
  }

  Future<void> _confirmUnblock(
      BuildContext context, FirewallBlockEntry e) async {
    final summary = _blockSummary(e);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remove block?'),
        content: Text(
          e.blockKind == 'process'
              ? 'Remove the firewall rule for $summary (${_directionLabel(e.direction).toLowerCase()})?'
              : 'Stop blocking ${_directionLabel(e.direction).toLowerCase()} traffic for $summary?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(c).colorScheme.error,
              foregroundColor: Theme.of(c).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<FirewallBloc>().requestUnblockEntry(e);
    }
  }

  Future<void> _confirmQuickBlockPort(BuildContext context, int port) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Block outbound port $port?'),
        content: Text(
          'All outbound TCP connections to port $port will be blocked on this machine.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(c).colorScheme.error,
              foregroundColor: Theme.of(c).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Block port'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<FirewallBloc>().requestBlockOutboundPort(
            port,
            expiresInHours: _expiryHours(_ipExpiryChoice),
          );
    }
  }

  void _submitManualBlock(BuildContext context) {
    final raw = _ipController.text;
    setState(() {
      _ipError = _isValidIp(raw)
          ? null
          : 'Enter a valid IPv4 or IPv6 address';
      final pt = _manualPortController.text.trim();
      if (pt.isEmpty) {
        _portError = null;
      } else {
        final p = int.tryParse(pt);
        _portError = (p != null && p >= 1 && p <= 65535)
            ? null
            : 'Port must be 1–65535';
      }
    });
    if (_ipError != null || _portError != null) return;
    final portText = _manualPortController.text.trim();
    final remotePort =
        portText.isEmpty ? null : int.tryParse(portText);
    context.read<FirewallBloc>().requestManualBlock(
          raw,
          _manualDirection,
          remotePort: remotePort,
          expiresInHours: _expiryHours(_ipExpiryChoice),
        );
    _ipController.clear();
    _manualPortController.clear();
  }

  void _submitProcessBlock(BuildContext context) {
    final raw = _processNameController.text.trim();
    setState(() {
      _processNameError =
          raw.isEmpty ? 'Enter a process name (e.g. notepad.exe)' : null;
    });
    if (_processNameError != null) return;
    context.read<FirewallBloc>().requestBlockProcess(
          raw,
          direction: _processDirection,
          expiresInHours: _expiryHours(_processExpiryChoice),
        );
    _processNameController.clear();
  }

  static bool _isPortBlocked(FirewallState fw, int port) {
    for (final e in fw.blocks) {
      if (e.blockKind != 'port') continue;
      if (e.ip == 'port:$port') return true;
      if (e.remotePort == port) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return BlocListener<ConnectionBloc, EmConnectionState>(
      listenWhen: (p, c) => c.isConnected && !p.isConnected,
      listener: (context, _) => context.read<FirewallBloc>().refresh(),
      child: BlocConsumer<FirewallBloc, FirewallState>(
        listenWhen: (p, c) =>
            c.snackbarMessage != null && c.snackbarMessage != p.snackbarMessage,
        listener: (context, state) {
          final msg = state.snackbarMessage;
          if (msg == null) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
          );
          context.read<FirewallBloc>().clearFeedback();
        },
        builder: (context, fw) {
          return BlocBuilder<ConnectionBloc, EmConnectionState>(
            builder: (context, conn) {
              final connected = conn.isConnected;
              final showLoading = fw.waitingFirstSnapshot &&
                  fw.snapshotLoading &&
                  !fw.pullRefreshing &&
                  connected;

              return Scaffold(
                backgroundColor: scheme.surface,
                appBar: EmBrandAppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.pop(),
                  ),
                ),
                body: RefreshIndicator(
                  color: scheme.primary,
                  onRefresh: connected
                      ? () => _onPullRefresh(context)
                      : () async {},
                  child: CustomScrollView(
                    primary: true,
                    physics: connected
                        ? const AlwaysScrollableScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            const EmPageIntro(
                              title: 'Firewall',
                              subtitle:
                                  'Network isolation, IP/port blocks, and process rules.',
                              padding: EdgeInsets.only(bottom: 16),
                            ),
                            if (!connected) ...[
                              _OfflineBanner(scheme: scheme, theme: theme),
                              const SizedBox(height: 16),
                            ],
                            if (fw.errorMessage != null && connected) ...[
                              _ErrorCard(
                                scheme: scheme,
                                message: fw.errorMessage!,
                                onRetry: () =>
                                    context.read<FirewallBloc>().refresh(),
                              ),
                              const SizedBox(height: 16),
                            ],
                            _IsolationCard(
                              scheme: scheme,
                              theme: theme,
                              isolated: fw.isolated,
                              enabled: connected && fw.errorMessage == null,
                              pulse: _pulseController,
                              onIsolate: () => _showIsolateBottomSheet(context),
                              onUnisolate: () => _confirmUnisolate(context),
                            ),
                            const SizedBox(height: 20),
                            SegmentedButton<int>(
                              segments: const [
                                ButtonSegment<int>(
                                  value: 0,
                                  label: Text('IP & ports'),
                                  icon: Icon(Icons.public_outlined, size: 18),
                                ),
                                ButtonSegment<int>(
                                  value: 1,
                                  label: Text('Processes'),
                                  icon: Icon(Icons.apps_outlined, size: 18),
                                ),
                              ],
                              selected: {_firewallSection},
                              onSelectionChanged:
                                  connected && fw.errorMessage == null
                                      ? (s) => setState(
                                            () => _firewallSection = s.first,
                                          )
                                      : (_) {},
                              showSelectedIcon: false,
                            ),
                            const SizedBox(height: 18),
                            if (_firewallSection == 0) ...[
                              Text(
                                'IP & port blocks (${fw.ipAndPortBlocks.length})',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (showLoading)
                                const EmLoadingSpinner(
                                  expand: false,
                                  compact: true,
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  message: 'Loading firewall rules…',
                                )
                              else
                                EmCollapsibleBlockList(
                                  items: fw.ipAndPortBlocks,
                                  empty: EmEmptyState(
                                    icon: Icons.shield_outlined,
                                    title: 'No active blocks',
                                    message:
                                        'Connections are unrestricted on this endpoint.',
                                  ),
                                  itemBuilder: (context, e) => _BlockTile(
                                    entry: e,
                                    scheme: scheme,
                                    theme: theme,
                                    relative: _relativeTime(e.createdAt),
                                    directionLabel:
                                        _directionLabel(e.direction),
                                    enabled:
                                        connected && fw.errorMessage == null,
                                    onUnblock: () =>
                                        _confirmUnblock(context, e),
                                  ),
                                ),
                              const SizedBox(height: 20),
                              _QuickBlocksCard(
                                scheme: scheme,
                                theme: theme,
                                enabled: connected && fw.errorMessage == null,
                                isPortBlocked: (p) =>
                                    _isPortBlocked(fw, p),
                                onBlockPort: (p) =>
                                    _confirmQuickBlockPort(context, p),
                              ),
                              const SizedBox(height: 16),
                              _ManualBlockCard(
                                scheme: scheme,
                                theme: theme,
                                controller: _ipController,
                                portController: _manualPortController,
                                direction: _manualDirection,
                                ipError: _ipError,
                                portError: _portError,
                                expiryChoice: _ipExpiryChoice,
                                enabled:
                                    connected && fw.errorMessage == null,
                                onDirectionChanged: (v) =>
                                    setState(() => _manualDirection = v),
                                onExpiryChanged: (v) =>
                                    setState(() => _ipExpiryChoice = v),
                                onSubmit: () => _submitManualBlock(context),
                                onIpChanged: () {
                                  if (_ipError != null) {
                                    setState(() => _ipError = null);
                                  }
                                },
                                onPortChanged: () {
                                  if (_portError != null) {
                                    setState(() => _portError = null);
                                  }
                                },
                              ),
                            ] else ...[
                              Text(
                                'Process blocks (${fw.processBlocks.length})',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (showLoading)
                                const EmLoadingSpinner(
                                  expand: false,
                                  compact: true,
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  message: 'Loading firewall rules…',
                                )
                              else
                                EmCollapsibleBlockList(
                                  items: fw.processBlocks,
                                  empty: EmEmptyState(
                                    icon: Icons.apps_outlined,
                                    title: 'No process rules',
                                    message:
                                        'No process-based firewall rules are configured.',
                                  ),
                                  itemBuilder: (context, e) => _BlockTile(
                                    entry: e,
                                    scheme: scheme,
                                    theme: theme,
                                    relative: _relativeTime(e.createdAt),
                                    directionLabel:
                                        _directionLabel(e.direction),
                                    enabled:
                                        connected && fw.errorMessage == null,
                                    onUnblock: () =>
                                        _confirmUnblock(context, e),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              _ProcessBlockCard(
                                scheme: scheme,
                                theme: theme,
                                controller: _processNameController,
                                direction: _processDirection,
                                nameError: _processNameError,
                                expiryChoice: _processExpiryChoice,
                                enabled:
                                    connected && fw.errorMessage == null,
                                onDirectionChanged: (v) => setState(
                                    () => _processDirection = v),
                                onExpiryChanged: (v) => setState(
                                    () => _processExpiryChoice = v),
                                onSubmit: () => _submitProcessBlock(context),
                                onNameChanged: () {
                                  if (_processNameError != null) {
                                    setState(() => _processNameError = null);
                                  }
                                },
                              ),
                            ],
                            const SizedBox(height: 20),
                            const _AboutBlockingCard(),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.scheme, required this.theme});

  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: EmDesign.cardShell(
        scheme,
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: scheme.outline),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Not connected to the endpoint. Connect from the home screen, then open Firewall again.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.scheme,
    required this.message,
    required this.onRetry,
  });

  final ColorScheme scheme;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: EmDesign.cardShell(
        scheme,
        color: scheme.errorContainer.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: scheme.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onErrorContainer,
                        height: 1.35,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _IsolationCard extends StatelessWidget {
  const _IsolationCard({
    required this.scheme,
    required this.theme,
    required this.isolated,
    required this.enabled,
    required this.pulse,
    required this.onIsolate,
    required this.onUnisolate,
  });

  final ColorScheme scheme;
  final ThemeData theme;
  final bool isolated;
  final bool enabled;
  final AnimationController pulse;
  final VoidCallback onIsolate;
  final VoidCallback onUnisolate;

  @override
  Widget build(BuildContext context) {
    final redTint = scheme.error.withValues(alpha: 0.12);
    final baseColor =
        isolated ? redTint : scheme.surfaceContainer;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: EmDesign.cardShell(
        scheme,
        color: baseColor,
        ghostEdge: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MACHINE ISOLATION',
            style: EmDesign.labelCaps(context, scheme),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (isolated)
                FadeTransition(
                  opacity: Tween<double>(begin: 0.45, end: 1).animate(
                    CurvedAnimation(
                      parent: pulse,
                      curve: Curves.easeInOut,
                    ),
                  ),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.error,
                      boxShadow: [
                        BoxShadow(
                          color: scheme.error.withValues(alpha: 0.55),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.tertiary,
                    boxShadow: [
                      BoxShadow(
                        color: scheme.tertiary.withValues(alpha: 0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isolated ? 'Isolated' : 'Not Isolated',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isolated)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.tertiary,
                foregroundColor: scheme.onTertiary,
              ),
              onPressed: enabled ? onUnisolate : null,
              child: const Text('Unisolate Machine'),
            )
          else
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: enabled ? onIsolate : null,
              child: const Text('Isolate Machine'),
            ),
        ],
      ),
    );
  }
}

class _QuickBlocksCard extends StatelessWidget {
  const _QuickBlocksCard({
    required this.scheme,
    required this.theme,
    required this.enabled,
    required this.isPortBlocked,
    required this.onBlockPort,
  });

  final ColorScheme scheme;
  final ThemeData theme;
  final bool enabled;
  final bool Function(int port) isPortBlocked;
  final void Function(int port) onBlockPort;

  static const _ports = [22, 80, 443, 3389, 8080, 5900];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: EmDesign.cardShell(scheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'QUICK BLOCKS (OUTBOUND TCP)',
            style: EmDesign.labelCaps(context, scheme),
          ),
          const SizedBox(height: 8),
          Text(
            'Block common remote ports for all outbound TCP traffic.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in _ports)
                FilterChip(
                  label: Text('$p'),
                  selected: isPortBlocked(p),
                  onSelected: !enabled || isPortBlocked(p)
                      ? null
                      : (_) => onBlockPort(p),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BlockTile extends StatelessWidget {
  const _BlockTile({
    required this.entry,
    required this.scheme,
    required this.theme,
    required this.relative,
    required this.directionLabel,
    required this.enabled,
    required this.onUnblock,
  });

  final FirewallBlockEntry entry;
  final ColorScheme scheme;
  final ThemeData theme;
  final String relative;
  final String directionLabel;
  final bool enabled;
  final VoidCallback onUnblock;

  String _primaryLine() {
    switch (entry.blockKind) {
      case 'process':
        return entry.processName ?? 'Process';
      case 'port':
        final raw = entry.ip;
        if (raw != null && raw.startsWith('port:')) {
          return 'Outbound TCP · port ${raw.substring(5)}';
        }
        return 'Outbound TCP · port ${entry.remotePort ?? ''}';
      default:
        return entry.ip ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final mono = GoogleFonts.jetBrainsMono(
      fontSize: 13,
      color: scheme.onSurface,
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: EmDesign.cardShell(scheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_primaryLine(), style: mono),
          if (entry.blockKind == 'process' &&
              entry.executablePath != null) ...[
            const SizedBox(height: 6),
            Text(
              entry.executablePath!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _DirectionBadge(label: directionLabel, scheme: scheme),
              if (entry.blockKind == 'ip')
                _KindBadge(label: 'IP', scheme: scheme),
              if (entry.blockKind == 'port')
                _KindBadge(label: 'Port', scheme: scheme),
              if (entry.blockKind == 'process')
                _KindBadge(label: 'Process', scheme: scheme),
              Text(
                relative,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (entry.blockKind == 'ip' &&
              entry.remotePort != null &&
              entry.remotePort! > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Remote port ${entry.remotePort}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (entry.sourceProcessName != null) ...[
            const SizedBox(height: 6),
            Text(
              'Source: ${entry.sourceProcessName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (entry.expiresAt != null) ...[
            const SizedBox(height: 8),
            _ExpiryCountdown(expiresAt: entry.expiresAt!),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: enabled ? onUnblock : null,
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              child: const Text('Remove'),
            ),
          ),
        ],
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.label, required this.scheme});

  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(6),
        border: EmDesign.ghostBorder(scheme),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: scheme.onPrimaryContainer,
            ),
      ),
    );
  }
}

class _ExpiryCountdown extends StatefulWidget {
  const _ExpiryCountdown({required this.expiresAt});

  final DateTime expiresAt;

  @override
  State<_ExpiryCountdown> createState() => _ExpiryCountdownState();
}

class _ExpiryCountdownState extends State<_ExpiryCountdown> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now().toUtc();
    final exp = widget.expiresAt.toUtc();
    if (!exp.isAfter(now)) {
      return Text(
        'Expired',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.error,
              fontWeight: FontWeight.w600,
            ),
      );
    }
    final diff = exp.difference(now);
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    final s = diff.inSeconds.remainder(60);
    final String msg;
    if (h > 48) {
      final d = (h / 24).floor();
      msg = 'Expires in ~$d day${d == 1 ? '' : 's'}';
    } else if (h > 0) {
      msg = 'Expires in ${h}h ${m}m';
    } else if (diff.inMinutes > 0) {
      msg = 'Expires in ${diff.inMinutes}m ${s}s';
    } else {
      msg = 'Expires in ${s}s';
    }
    return Text(
      msg,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.tertiary,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _DirectionBadge extends StatelessWidget {
  const _DirectionBadge({required this.label, required this.scheme});

  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: EmDesign.ghostBorder(scheme),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
      ),
    );
  }
}

class _ManualBlockCard extends StatelessWidget {
  const _ManualBlockCard({
    required this.scheme,
    required this.theme,
    required this.controller,
    required this.portController,
    required this.direction,
    required this.ipError,
    required this.portError,
    required this.expiryChoice,
    required this.enabled,
    required this.onDirectionChanged,
    required this.onExpiryChanged,
    required this.onSubmit,
    required this.onIpChanged,
    required this.onPortChanged,
  });

  final ColorScheme scheme;
  final ThemeData theme;
  final TextEditingController controller;
  final TextEditingController portController;
  final String direction;
  final String? ipError;
  final String? portError;
  final String expiryChoice;
  final bool enabled;
  final ValueChanged<String> onDirectionChanged;
  final ValueChanged<String> onExpiryChanged;
  final VoidCallback onSubmit;
  final VoidCallback onIpChanged;
  final VoidCallback onPortChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: EmDesign.cardShell(scheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'MANUAL IP BLOCK',
            style: EmDesign.labelCaps(context, scheme),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            enabled: enabled,
            onChanged: (_) => onIpChanged(),
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: 'IP address',
              errorText: ipError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(EmDesign.radiusMd),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: portController,
            enabled: enabled,
            onChanged: (_) => onPortChanged(),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Remote port (optional)',
              hintText: 'e.g. 443',
              errorText: portError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(EmDesign.radiusMd),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Direction',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'outbound', label: Text('Outbound')),
              ButtonSegment(value: 'inbound', label: Text('Inbound')),
              ButtonSegment(value: 'both', label: Text('Both')),
            ],
            selected: {direction},
            onSelectionChanged: (s) {
              if (enabled) onDirectionChanged(s.first);
            },
            showSelectedIcon: false,
          ),
          const SizedBox(height: 12),
          Text(
            'Expires',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'perm', label: Text('Never')),
              ButtonSegment(value: '1', label: Text('1h')),
              ButtonSegment(value: '24', label: Text('24h')),
              ButtonSegment(value: '168', label: Text('7d')),
            ],
            selected: {expiryChoice},
            onSelectionChanged: (s) {
              if (enabled) onExpiryChanged(s.first);
            },
            showSelectedIcon: false,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: enabled ? onSubmit : null,
            child: const Text('Add block'),
          ),
        ],
      ),
    );
  }
}

/// Option row for process autocomplete (RawAutocomplete needs non-nullable [Object] subtype).
class _ProcSuggest {
  const _ProcSuggest._(this.process, this.isNoMatch);
  const _ProcSuggest.pick(ProcessInfo p) : this._(p, false);
  const _ProcSuggest.noMatch() : this._(null, true);

  final ProcessInfo? process;
  final bool isNoMatch;
}

/// Process name field with live suggestions from [ProcessBloc] (max 5, min 2 chars).
class _ProcessBlockNameAutocomplete extends StatefulWidget {
  const _ProcessBlockNameAutocomplete({
    required this.items,
    required this.controller,
    required this.enabled,
    required this.scheme,
    required this.theme,
    required this.nameError,
    required this.onNameChanged,
  });

  final List<ProcessInfo> items;
  final TextEditingController controller;
  final bool enabled;
  final ColorScheme scheme;
  final ThemeData theme;
  final String? nameError;
  final VoidCallback onNameChanged;

  @override
  State<_ProcessBlockNameAutocomplete> createState() =>
      _ProcessBlockNameAutocompleteState();
}

class _ProcessBlockNameAutocompleteState
    extends State<_ProcessBlockNameAutocomplete> {
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final muted = widget.theme.textTheme.bodySmall?.copyWith(
      color: widget.scheme.onSurfaceVariant,
      fontWeight: FontWeight.w500,
    );
    return RawAutocomplete<_ProcSuggest>(
      textEditingController: widget.controller,
      focusNode: _focus,
      displayStringForOption: (s) => s.process?.name ?? '',
      optionsBuilder: (textEditingValue) {
        final q = textEditingValue.text.trim();
        if (q.length < 2) return const Iterable<_ProcSuggest>.empty();
        final matches = widget.items
            .where(
              (p) => p.name.toLowerCase().contains(q.toLowerCase()),
            )
            .take(5)
            .map(_ProcSuggest.pick)
            .toList();
        if (matches.isEmpty) return const [_ProcSuggest.noMatch()];
        return matches;
      },
      onSelected: (s) {
        if (!s.isNoMatch && s.process != null) {
          widget.controller.text = s.process!.name;
          widget.onNameChanged();
        }
      },
      fieldViewBuilder: (context, c, fn, onFieldSubmitted) {
        return TextField(
          controller: c,
          focusNode: fn,
          enabled: widget.enabled,
          onChanged: (_) => widget.onNameChanged(),
          decoration: InputDecoration(
            labelText: 'Process name',
            hintText: 'notepad.exe',
            errorText: widget.nameError,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(EmDesign.radiusMd),
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final kb = MediaQuery.viewInsetsOf(context).bottom;
        final opts = options.toList();
        return Padding(
          padding: EdgeInsets.only(bottom: kb),
          child: Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 8,
              color: widget.scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(EmDesign.radiusMd),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: opts.length,
                  itemBuilder: (context, i) {
                    final opt = opts[i];
                    if (opt.isNoMatch) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Text(
                          'No running processes match — process must be running for path lookup',
                          style: muted,
                        ),
                      );
                    }
                    final p = opt.process!;
                    return InkWell(
                      onTap: () => onSelected(opt),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.settings_suggest_outlined,
                              size: 20,
                              color: widget.scheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                p.name,
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: widget.scheme.onSurface,
                                ),
                              ),
                            ),
                            Text(
                              '${p.pid}',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: widget.scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProcessBlockCard extends StatelessWidget {
  const _ProcessBlockCard({
    required this.scheme,
    required this.theme,
    required this.controller,
    required this.direction,
    required this.nameError,
    required this.expiryChoice,
    required this.enabled,
    required this.onDirectionChanged,
    required this.onExpiryChanged,
    required this.onSubmit,
    required this.onNameChanged,
  });

  final ColorScheme scheme;
  final ThemeData theme;
  final TextEditingController controller;
  final String direction;
  final String? nameError;
  final String expiryChoice;
  final bool enabled;
  final ValueChanged<String> onDirectionChanged;
  final ValueChanged<String> onExpiryChanged;
  final VoidCallback onSubmit;
  final VoidCallback onNameChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: EmDesign.cardShell(scheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'BLOCK BY PROCESS',
            style: EmDesign.labelCaps(context, scheme),
          ),
          const SizedBox(height: 8),
          Text(
            'The process must be running so the service can read its path from WMI.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          BlocBuilder<ProcessBloc, ProcessState>(
            buildWhen: (a, b) => a.items != b.items,
            builder: (context, proc) {
              return _ProcessBlockNameAutocomplete(
                items: proc.items,
                controller: controller,
                enabled: enabled,
                scheme: scheme,
                theme: theme,
                nameError: nameError,
                onNameChanged: onNameChanged,
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Direction',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'outbound', label: Text('Outbound')),
              ButtonSegment(value: 'inbound', label: Text('Inbound')),
              ButtonSegment(value: 'both', label: Text('Both')),
            ],
            selected: {direction},
            onSelectionChanged: (s) {
              if (enabled) onDirectionChanged(s.first);
            },
            showSelectedIcon: false,
          ),
          const SizedBox(height: 12),
          Text(
            'Expires',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'perm', label: Text('Never')),
              ButtonSegment(value: '1', label: Text('1h')),
              ButtonSegment(value: '24', label: Text('24h')),
              ButtonSegment(value: '168', label: Text('7d')),
            ],
            selected: {expiryChoice},
            onSelectionChanged: (s) {
              if (enabled) onExpiryChanged(s.first);
            },
            showSelectedIcon: false,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: enabled ? onSubmit : null,
            child: const Text('Block process'),
          ),
        ],
      ),
    );
  }
}

class _AboutBlockingCard extends StatefulWidget {
  const _AboutBlockingCard();

  @override
  State<_AboutBlockingCard> createState() => _AboutBlockingCardState();
}

class _AboutBlockingCardState extends State<_AboutBlockingCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Container(
      decoration: EmDesign.cardShell(scheme),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.info_outline, color: scheme.primary),
            title: Text(
              'About IP Blocking',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            trailing: Icon(
              _open ? Icons.expand_less : Icons.expand_more,
              color: scheme.onSurfaceVariant,
            ),
            onTap: () => setState(() => _open = !_open),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'IP blocking prevents new connections to the specified address. '
                'Existing open sockets are not immediately closed and CDN-hosted services may reconnect via a different IP. '
                'To stop an application entirely use Kill Process in the Processes screen.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
