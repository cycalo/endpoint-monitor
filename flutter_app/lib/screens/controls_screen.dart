import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../bloc/connection_bloc.dart';
import '../bloc/controls_bloc.dart';
import '../bloc/system_info_bloc.dart';
import '../theme/em_design_system.dart';
import '../widgets/em_brand_app_bar.dart';

const _borderSession = Color(0xFF00838F);
const _borderPowerAmber = Color(0xFFFF8F00);
const _borderPowerRed = Color(0xFFC62828);
const _borderDisplay = Color(0xFF1565C0);
const _borderCancel = Color(0xFF757575);
const _borderAudio = Color(0xFF7B1FA2);

class ControlsScreen extends StatelessWidget {
  const ControlsScreen({super.key});

  static String _hostLabel(SystemInfoState si) {
    final n = si.info?.systemName.trim() ?? '';
    return n.isEmpty ? 'this machine' : n;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BlocListener<ControlsBloc, ControlsState>(
      listenWhen: (p, c) =>
          c.feedback != null &&
          (p.feedback == null ||
              p.feedback!.message != c.feedback!.message ||
              p.feedback!.success != c.feedback!.success),
      listener: (context, s) {
        final f = s.feedback!;
        context.read<ControlsBloc>().clearFeedback();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(f.message),
            backgroundColor:
                f.success ? null : Theme.of(context).colorScheme.error,
          ),
        );
      },
      child: Scaffold(
        backgroundColor: scheme.surface,
        appBar: EmBrandAppBar(
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () => context.pop(),
            icon: Icon(Icons.arrow_back_rounded, color: scheme.primary),
          ),
          title: Text(
            'Controls',
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
        ),
        body: BlocBuilder<ConnectionBloc, EmConnectionState>(
          builder: (context, conn) {
            final connected = conn.isConnected;
            return BlocBuilder<SystemInfoBloc, SystemInfoState>(
              builder: (context, si) {
                final host = _hostLabel(si);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  children: [
                    _sectionTitle(context, scheme, 'SESSION'),
                    _ControlCard(
                      borderColor: _borderSession,
                      muted: false,
                      enabled: connected,
                      commandType: 'lock_screen',
                      icon: Icons.lock_outline_rounded,
                      title: 'Lock Screen',
                      description: 'Lock the Windows session immediately',
                      buttonLabel: 'Lock Screen',
                      onPrimaryTap: (ctx) => ctx.read<ControlsBloc>().send(
                        const {'type': 'lock_screen'},
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ControlCard(
                      borderColor: _borderSession,
                      muted: false,
                      enabled: connected,
                      commandType: 'logoff_user',
                      icon: Icons.logout_rounded,
                      title: 'Log Off',
                      description: 'Log off the current Windows user',
                      buttonLabel: 'Log Off',
                      onPrimaryTap: (ctx) => _logoffFlow(ctx, host),
                    ),
                    const SizedBox(height: 20),
                    _sectionTitle(context, scheme, 'AUDIO'),
                    _SystemVolumeCard(enabled: connected),
                    const SizedBox(height: 20),
                    _sectionTitle(context, scheme, 'POWER'),
                    _ControlCard(
                      borderColor: _borderPowerAmber,
                      muted: false,
                      enabled: connected,
                      commandType: 'restart_machine',
                      icon: Icons.restart_alt_rounded,
                      title: 'Restart',
                      description: 'Restart the monitored machine',
                      buttonLabel: 'Restart',
                      onPrimaryTap: (ctx) => _restartFlow(ctx, host),
                    ),
                    const SizedBox(height: 12),
                    _ControlCard(
                      borderColor: _borderPowerRed,
                      muted: false,
                      enabled: connected,
                      commandType: 'shutdown_machine',
                      icon: Icons.power_settings_new_rounded,
                      title: 'Shutdown',
                      description: 'Shut down the monitored machine',
                      buttonLabel: 'Shut Down',
                      onPrimaryTap: (ctx) => _shutdownFlow(ctx, host),
                    ),
                    const SizedBox(height: 12),
                    _ControlCard(
                      borderColor: _borderPowerAmber,
                      muted: false,
                      enabled: connected,
                      commandType: 'sleep_machine',
                      icon: Icons.bedtime_outlined,
                      title: 'Sleep',
                      description: 'Put the machine to sleep',
                      buttonLabel: 'Sleep',
                      onPrimaryTap: (ctx) => _sleepFlow(ctx, host),
                    ),
                    const SizedBox(height: 20),
                    _sectionTitle(context, scheme, 'DISPLAY'),
                    _ControlCard(
                      borderColor: _borderDisplay,
                      muted: false,
                      enabled: connected,
                      commandType: 'turn_off_display',
                      icon: Icons.desktop_access_disabled_outlined,
                      title: 'Turn Off Display',
                      description: 'Turn off the monitor without sleeping',
                      buttonLabel: 'Turn Off Display',
                      onPrimaryTap: (ctx) => ctx.read<ControlsBloc>().send(
                        const {'type': 'turn_off_display'},
                      ),
                    ),
                    const SizedBox(height: 20),
                    _sectionTitle(context, scheme, 'CANCEL'),
                    _ControlCard(
                      borderColor: _borderCancel,
                      muted: true,
                      enabled: connected,
                      commandType: 'cancel_shutdown',
                      icon: Icons.cancel_outlined,
                      title: 'Cancel Pending Shutdown',
                      description: 'Cancel a pending restart or shutdown',
                      buttonLabel: 'Cancel Shutdown',
                      onPrimaryTap: (ctx) => ctx.read<ControlsBloc>().send(
                        const {'type': 'cancel_shutdown'},
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  static Widget _sectionTitle(
      BuildContext context, ColorScheme scheme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: EmDesign.labelCaps(context, scheme),
      ),
    );
  }

  static Future<void> _logoffFlow(BuildContext context, String host) async {
    final go = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Log off',
                style: Theme.of(c).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                'The current user session will end. Unsaved work may be lost.',
                style: Theme.of(c).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
    if (go != true || !context.mounted) return;
    final amber = const Color(0xFFE65100);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Log off user?'),
        content: Text(
          'Log off the current user on $host? Unsaved work will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: amber,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Log Off'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<ControlsBloc>().send(const {'type': 'logoff_user'});
    }
  }

  static Future<void> _restartFlow(BuildContext context, String host) async {
    var delaySec = 0;
    final go = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setSt) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 8,
              bottom: 24 + MediaQuery.viewInsetsOf(c).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Restart',
                  style: Theme.of(c).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  'The machine will reboot. Monitoring will reconnect automatically after restart.',
                  style: Theme.of(c).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                Text(
                  'Delay',
                  style: Theme.of(c).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('None')),
                    ButtonSegment(value: 60, label: Text('1 min')),
                    ButtonSegment(value: 300, label: Text('5 min')),
                  ],
                  selected: {delaySec},
                  onSelectionChanged: (s) => setSt(() => delaySec = s.first),
                  showSelectedIcon: false,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (go != true || !context.mounted) return;
    final amber = const Color(0xFFE65100);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Restart machine?'),
        content: Text(
          'Restart $host? The machine will be unavailable while rebooting. '
          'Monitoring will reconnect automatically after restart.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: amber,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<ControlsBloc>().send({
        'type': 'restart_machine',
        'delaySeconds': delaySec,
      });
    }
  }

  static Future<void> _shutdownFlow(BuildContext context, String host) async {
    var delaySec = 0;
    final go = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setSt) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 8,
              bottom: 24 + MediaQuery.viewInsetsOf(c).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Shut down',
                  style: Theme.of(c).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  'The machine will power off. The monitoring connection will be lost.',
                  style: Theme.of(c).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                Text(
                  'Delay',
                  style: Theme.of(c).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('None')),
                    ButtonSegment(value: 60, label: Text('1 min')),
                    ButtonSegment(value: 300, label: Text('5 min')),
                  ],
                  selected: {delaySec},
                  onSelectionChanged: (s) => setSt(() => delaySec = s.first),
                  showSelectedIcon: false,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (go != true || !context.mounted) return;
    final scheme = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Shut down machine?'),
        content: Text(
          'Shut down $host? The monitoring connection will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Shut Down'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<ControlsBloc>().send({
        'type': 'shutdown_machine',
        'delaySeconds': delaySec,
      });
    }
  }

  static Future<void> _sleepFlow(BuildContext context, String host) async {
    final go = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sleep',
                style: Theme.of(c).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                'The machine will suspend. The monitoring connection will be lost until wake.',
                style: Theme.of(c).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
    if (go != true || !context.mounted) return;
    final amber = const Color(0xFFE65100);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Put machine to sleep?'),
        content: Text(
          'Put $host to sleep? The monitoring connection will be lost until wake.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: amber,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sleep'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<ControlsBloc>().send(const {'type': 'sleep_machine'});
    }
  }
}

/// Volume applies on [Slider.onChangeEnd] only. Mute sends `toggle_mute` per tap.
class _SystemVolumeCard extends StatefulWidget {
  const _SystemVolumeCard({required this.enabled});

  final bool enabled;

  @override
  State<_SystemVolumeCard> createState() => _SystemVolumeCardState();
}

class _SystemVolumeCardState extends State<_SystemVolumeCard> {
  double _sliderValue = 50;

  /// Optimistic UI: we don’t read live mute state from the PC (assume unmuted until user toggles).
  bool _muted = false;

  void _onMuteTap(BuildContext context) {
    setState(() => _muted = !_muted);
    context.read<ControlsBloc>().toggleMute();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final volumePending = context.select<ControlsBloc, bool>(
      (b) => b.state.pending.contains('set_volume'),
    );
    final mutePending = context.select<ControlsBloc, bool>(
      (b) => b.state.pending.contains('toggle_mute'),
    );
    final opacity = widget.enabled ? 1.0 : 0.45;
    final sliderLive = widget.enabled && !volumePending;

    return Opacity(
      opacity: opacity,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(EmDesign.radiusLg),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: _borderAudio.withValues(alpha: 0.95),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(EmDesign.radiusLg),
                    bottomLeft: Radius.circular(EmDesign.radiusLg),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.graphic_eq_rounded,
                            color: scheme.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'System volume',
                              style: GoogleFonts.manrope(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          Text(
                            '${_sliderValue.round()}%',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Drag to choose a level, then release to apply on the PC. '
                        'Mute toggles Windows master audio.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Tooltip(
                            message: _muted ? 'Unmute' : 'Mute',
                            child: IconButton.filled(
                              onPressed: widget.enabled && !mutePending
                                  ? () => _onMuteTap(context)
                                  : null,
                              icon: mutePending
                                  ? SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _muted
                                            ? scheme.onErrorContainer
                                            : scheme.onPrimaryContainer,
                                      ),
                                    )
                                  : Icon(
                                      _muted
                                          ? Icons.volume_off_rounded
                                          : Icons.volume_up_rounded,
                                    ),
                              style: IconButton.styleFrom(
                                backgroundColor: _muted
                                    ? scheme.errorContainer
                                    : scheme.primaryContainer,
                                foregroundColor: _muted
                                    ? scheme.onErrorContainer
                                    : scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Slider(
                              value: _sliderValue.clamp(0.0, 100.0),
                              min: 0,
                              max: 100,
                              divisions: 20,
                              onChanged: sliderLive
                                  ? (v) => setState(() => _sliderValue = v)
                                  : null,
                              onChangeEnd: sliderLive
                                  ? (v) {
                                      final muteInFlight = context
                                          .read<ControlsBloc>()
                                          .state
                                          .pending
                                          .contains('toggle_mute');
                                      setState(() {
                                        _sliderValue = v;
                                        if (!muteInFlight) _muted = false;
                                      });
                                      context
                                          .read<ControlsBloc>()
                                          .setVolume(v.round());
                                    }
                                  : null,
                            ),
                          ),
                          if (volumePending) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: scheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _ControlsTap = void Function(BuildContext context);

class _ControlCard extends StatelessWidget {
  const _ControlCard({
    required this.borderColor,
    required this.muted,
    required this.enabled,
    required this.commandType,
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPrimaryTap,
  });

  final Color borderColor;
  final bool muted;
  final bool enabled;
  final String commandType;
  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final _ControlsTap onPrimaryTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final loading = context.select<ControlsBloc, bool>(
        (b) => b.state.pending.contains(commandType));
    final effective = enabled && !loading;
    final opacity = enabled ? 1.0 : 0.45;

    return Opacity(
      opacity: opacity,
      child: Container(
        decoration: BoxDecoration(
          color: muted
              ? scheme.surfaceContainerLow.withValues(alpha: 0.85)
              : scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(EmDesign.radiusLg),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: muted ? 0.12 : 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: borderColor.withValues(alpha: muted ? 0.35 : 0.95),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(EmDesign.radiusLg),
                    bottomLeft: Radius.circular(EmDesign.radiusLg),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon,
                              color: muted ? scheme.outline : scheme.primary,
                              size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              title,
                              style: GoogleFonts.manrope(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.tonal(
                        onPressed:
                            effective ? () => onPrimaryTap(context) : null,
                        child: loading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: scheme.primary,
                                ),
                              )
                            : Text(buttonLabel),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
