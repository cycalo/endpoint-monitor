import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../bloc/process_bloc.dart';
import '../models/ws_models.dart';

/// Always-on red for destructive Kill control (light/dark themes).
const processKillButtonRed = Color(0xFFC62828);

Future<void> confirmKillProcess(BuildContext context, ProcessInfo p) async {
  final scheme = Theme.of(context).colorScheme;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Kill process?'),
      content: Text(
        'Kill ${p.name} (PID ${p.pid})? This will immediately terminate the process '
        'and cannot be undone.',
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
          child: const Text('Kill'),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    context
        .read<ProcessBloc>()
        .sendCommand({'type': 'kill_process', 'pid': p.pid});
  }
}

class ProcessKillInkButton extends StatelessWidget {
  const ProcessKillInkButton({
    super.key,
    required this.onPressed,
    required this.label,
    required this.enabled,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bg = enabled ? processKillButtonRed : Colors.grey.shade600;
    const fg = Colors.white;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: bg,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cancel_rounded, size: 18, color: fg),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProcessOutlineInkButton extends StatelessWidget {
  const ProcessOutlineInkButton({
    super.key,
    required this.scheme,
    required this.icon,
    required this.label,
    this.onPressed,
    this.dimmed = false,
  });

  final ColorScheme scheme;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !dimmed;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: scheme.onSurface),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
