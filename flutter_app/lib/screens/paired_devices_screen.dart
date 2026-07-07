import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../theme/em_design_system.dart';
import '../utils/export_http_base.dart';
import '../widgets/em_brand_app_bar.dart';
import '../widgets/em_loading_states.dart';

class PairedDevice {
  const PairedDevice({
    required this.id,
    required this.deviceName,
    required this.createdAt,
    this.lastUsedAt,
    required this.revoked,
  });

  factory PairedDevice.fromJson(Map<String, dynamic> json) => PairedDevice(
        id: json['id']?.toString() ?? '',
        deviceName: json['deviceName']?.toString() ?? 'Unknown device',
        createdAt: json['createdAt']?.toString() ?? '',
        lastUsedAt: json['lastUsedAt']?.toString(),
        revoked: json['revoked'] == true,
      );

  final String id;
  final String deviceName;
  final String createdAt;
  final String? lastUsedAt;
  final bool revoked;
}

class PairedDevicesScreen extends StatefulWidget {
  const PairedDevicesScreen({super.key});

  @override
  State<PairedDevicesScreen> createState() => _PairedDevicesScreenState();
}

class _PairedDevicesScreenState extends State<PairedDevicesScreen> {
  static const _secure = FlutterSecureStorage();

  bool _loading = true;
  String? _error;
  List<PairedDevice> _devices = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<Dio> _dio() async {
    final host = await _secure.read(key: 'em_host') ?? '';
    final token = await _secure.read(key: 'em_token') ?? '';
    if (host.isEmpty || token.isEmpty) {
      throw StateError('Save endpoint and device token in Settings first.');
    }
    return Dio(BaseOptions(
      baseUrl: httpBaseFromMonitorHost(host),
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Authorization': 'Bearer $token'},
    ));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = await _dio();
      final res = await dio.get<List<dynamic>>('/api/auth/devices');
      final list = res.data ?? const [];
      if (!mounted) return;
      setState(() {
        _devices = list
            .whereType<Map<String, dynamic>>()
            .map(PairedDevice.fromJson)
            .toList()
          ..sort((a, b) {
            final at = DateTime.tryParse(a.lastUsedAt ?? a.createdAt);
            final bt = DateTime.tryParse(b.lastUsedAt ?? b.createdAt);
            if (at == null && bt == null) return 0;
            if (at == null) return 1;
            if (bt == null) return -1;
            return bt.compareTo(at);
          });
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load paired devices. Connect to the endpoint and try again.';
      });
    }
  }

  Future<void> _revoke(PairedDevice device) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke device?'),
        content: Text(
          '“${device.deviceName}” will lose access immediately. '
          'You can pair it again with a new code from the Windows PC.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final dio = await _dio();
      await dio.post('/api/auth/devices/revoke', data: {'id': device.id});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Revoked ${device.deviceName}')),
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revoke failed. Try again.')),
      );
    }
  }

  String _formatWhen(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat.yMMMd().add_jm().format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: EmBrandAppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_rounded, color: scheme.primary),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            const EmPageIntro(
              title: 'Paired devices',
              subtitle:
                  'Phones and tablets authorized to control this endpoint. Revoke lost devices here.',
              padding: EdgeInsets.only(bottom: 16),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: EmStatusPanel(loading: true, message: 'Loading devices…'),
              )
            else if (_error != null)
              EmEmptyState(
                icon: Icons.phonelink_erase_rounded,
                title: 'Unavailable',
                message: _error!,
              )
            else if (_devices.isEmpty)
              const EmEmptyState(
                icon: Icons.devices_other_rounded,
                title: 'No paired devices',
                message: 'Pair a phone from the Connect screen to see it here.',
              )
            else
              ..._devices.map((d) => _DeviceTile(
                    device: d,
                    created: _formatWhen(d.createdAt),
                    lastUsed: _formatWhen(d.lastUsedAt),
                    onRevoke: d.revoked ? null : () => _revoke(d),
                  )),
          ],
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.created,
    required this.lastUsed,
    required this.onRevoke,
  });

  final PairedDevice device;
  final String created;
  final String lastUsed;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: EmDesign.cardShell(scheme, color: scheme.surfaceContainerLow),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(
          device.revoked ? Icons.phonelink_erase_rounded : Icons.smartphone_rounded,
          color: device.revoked ? scheme.onSurfaceVariant : scheme.primary,
        ),
        title: Text(
          device.deviceName,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Paired $created', style: themeCaption(scheme)),
              Text('Last used $lastUsed', style: themeCaption(scheme)),
              if (device.revoked)
                Text(
                  'Revoked',
                  style: themeCaption(scheme)?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        trailing: onRevoke == null
            ? null
            : TextButton(
                onPressed: onRevoke,
                child: Text('Revoke', style: TextStyle(color: scheme.error)),
              ),
      ),
    );
  }

  TextStyle? themeCaption(ColorScheme scheme) =>
      GoogleFonts.inter(fontSize: 12, color: scheme.onSurfaceVariant, height: 1.35);
}
