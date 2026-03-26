import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:google_fonts/google_fonts.dart';

import '../bloc/software_bloc.dart';
import '../models/ws_models.dart';
import '../theme/em_design_system.dart';
import '../utils/software_display.dart';
import '../widgets/em_brand_app_bar.dart';

class SoftwareDetailScreen extends StatefulWidget {
  const SoftwareDetailScreen({super.key, required this.item});

  final InstalledSoftwareItem item;

  @override
  State<SoftwareDetailScreen> createState() => _SoftwareDetailScreenState();
}

class _SoftwareDetailScreenState extends State<SoftwareDetailScreen> {
  bool _uninstallBusy = false;

  @override
  void initState() {
    super.initState();
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    super.dispose();
  }

  void _onTaskData(Object data) {
    if (data is! Map) return;
    final m = Map<String, dynamic>.from(data);
    if (m['type']?.toString() != 'command_result') return;
    if (m['command']?.toString() != 'uninstall_software') return;
    if (!mounted) return;
    setState(() => _uninstallBusy = false);
    final ok = m['success'] == true;
    final msg = m['message']?.toString() ?? '';
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          ok
              ? 'Uninstall started. Complete any prompts on the monitored PC.'
              : _friendlyUninstallError(msg),
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
    if (ok) {
      context.read<SoftwareBloc>().request();
    }
  }

  String _friendlyUninstallError(String code) {
    switch (code) {
      case 'no_remove':
        return 'This product is marked as non-removable.';
      case 'not_found':
        return 'Uninstall entry was not found. Refresh the list and try again.';
      case 'no_uninstall_string':
        return 'No uninstall command is registered for this product.';
      case 'invalid_registry_subkey':
        return 'Invalid uninstall request.';
      case 'start_failed':
        return 'Could not start the uninstaller.';
      default:
        return code.isEmpty ? 'Uninstall failed.' : code;
    }
  }

  Future<void> _confirmUninstall() async {
    final name = widget.item.name.trim().isEmpty ? 'this program' : widget.item.name.trim();
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Uninstall?', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
        content: Text(
          'Start uninstall for “$name” on the monitored Windows PC? '
          'You may need to interact with uninstaller windows there.',
          style: Theme.of(c).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Uninstall')),
        ],
      ),
    );
    if (go != true || !mounted) return;
    if (widget.item.uninstallRegistrySubKey.trim().isEmpty) return;
    setState(() => _uninstallBusy = true);
    FlutterForegroundTask.sendDataToTask(
      jsonEncode({
        'type': 'uninstall_software',
        'registrySubKey': widget.item.uninstallRegistrySubKey.trim(),
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final item = widget.item;

    Widget row(String label, String value, {bool mono = false}) {
      final v = value.trim().isEmpty ? '—' : value.trim();
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            SelectableText(
              v,
              style: mono
                  ? GoogleFonts.jetBrainsMono(fontSize: 12, height: 1.45)
                  : theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ],
        ),
      );
    }

    final canTrigger = item.canUninstall && item.uninstallRegistrySubKey.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: EmBrandAppBar(
        title: Text(
          'Software',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: scheme.primary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            item.name.trim().isEmpty ? '—' : item.name.trim(),
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: EmDesign.cardShell(scheme),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                row('Vendor', item.vendor),
                row('Version', truncateVersion(item.version, maxLen: 1000)),
                row('Install date', normalizeInstallDateDisplay(item.installDate)),
                row('Install size', formatInstallSizeKb(item.installSizeKb)),
                row(
                  'Install location',
                  item.installLocation,
                  mono: true,
                ),
              ],
            ),
          ),
          if (canTrigger) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _uninstallBusy ? null : _confirmUninstall,
                icon: _uninstallBusy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.onPrimary,
                        ),
                      )
                    : Icon(Icons.delete_outline_rounded, color: scheme.onPrimary),
                label: Text(
                  _uninstallBusy ? 'Starting…' : 'Uninstall',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Text(
              'Uninstall is not available for this entry (missing uninstall information or marked non-removable).',
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.45,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
