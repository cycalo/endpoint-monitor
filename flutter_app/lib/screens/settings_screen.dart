import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_version.dart';
import '../bloc/alerts_bloc.dart';
import '../bloc/connection_bloc.dart';
import '../bloc/events_bloc.dart';
import '../bloc/system_info_bloc.dart';
import '../bloc/threat_intel_bloc.dart';
import '../settings/app_settings_keys.dart';
import '../theme/em_design_system.dart';
import '../theme/theme_cubit.dart';
import '../utils/export_http_base.dart';
import '../utils/jwt_expiry.dart';
import '../utils/relative_time.dart';
import '../widgets/em_brand_app_bar.dart';
import '../widgets/em_loading_states.dart';
import '../widgets/pin_unlock_gate.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _endpoint = TextEditingController();
  final _jwt = TextEditingController();
  final _httpBase = TextEditingController();
  final _groqApiKey = TextEditingController();
  bool _hideJwt = true;
  bool _hideGroqApi = true;
  bool _rememberEndpoint = true;
  bool _pinLock = false;
  String _autoLock = 'never';
  bool _notifyHigh = true;
  bool _notifyWatch = true;
  bool _notifyIso = true;
  bool _notifySoft = true;
  String _eventsRange = '1h';
  int _eventsMax = 100;
  bool _showIpv6 = false;
  bool _compactProc = false;

  String _savedEndpoint = '';
  String _savedJwt = '';
  String _savedHttp = '';
  String _savedGroqApi = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _endpoint.dispose();
    _jwt.dispose();
    _httpBase.dispose();
    _groqApiKey.dispose();
    super.dispose();
  }

  bool get _connectionDirty =>
      _endpoint.text.trim() != _savedEndpoint ||
      _jwt.text.trim() != _savedJwt ||
      _httpBase.text.trim() != _savedHttp;

  bool get _groqDirty => _groqApiKey.text.trim() != _savedGroqApi;

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    await AppSettingsKeys.ensureDefaults(p);
    const s = FlutterSecureStorage();
    final host = await s.read(key: 'em_host') ?? '';
    final token = await s.read(key: 'em_token') ?? '';
    final groqKey = (await s.read(key: AppSettingsKeys.groqApiKey) ?? '').trim();
    _endpoint.text = host;
    _jwt.text = token;
    _groqApiKey.text = groqKey;
    _httpBase.text = p.getString(AppSettingsKeys.httpBase) ?? 'http://192.168.1.10:5000';
    _rememberEndpoint =
        p.getBool(AppSettingsKeys.rememberEndpoint) ?? p.getBool('em_remember_connect') ?? true;
    _pinLock = p.getBool(AppSettingsKeys.pinLockEnabled) ?? false;
    _autoLock = p.getString(AppSettingsKeys.autoLockTimeout) ?? 'never';
    _notifyHigh = p.getBool(AppSettingsKeys.notifyHighSeverity) ?? true;
    _notifyWatch = p.getBool(AppSettingsKeys.notifyWatchlist) ?? true;
    _notifyIso = p.getBool(AppSettingsKeys.notifyIsolation) ?? true;
    _notifySoft = p.getBool(AppSettingsKeys.notifyNewSoftware) ?? true;
    _eventsRange = p.getString(AppSettingsKeys.eventsDefaultRange) ?? '1h';
    _eventsMax = p.getInt(AppSettingsKeys.eventsMaxLoad) ?? 100;
    _showIpv6 = p.getBool(AppSettingsKeys.showIpv6Network) ?? false;
    _compactProc = p.getBool(AppSettingsKeys.compactProcessCards) ?? false;
    _savedEndpoint = host;
    _savedJwt = token;
    _savedGroqApi = groqKey.trim();
    _savedHttp = _httpBase.text.trim();
    if (mounted) setState(() {});
  }

  Future<void> _saveGroqApiKey() async {
    const s = FlutterSecureStorage();
    final key = _groqApiKey.text.trim();
    await s.write(key: AppSettingsKeys.groqApiKey, value: key);
    _savedGroqApi = key;
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Groq API Key saved')));
  }

  Future<void> _persistNonConnection() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(AppSettingsKeys.rememberEndpoint, _rememberEndpoint);
    await p.setBool('em_remember_connect', _rememberEndpoint);
    await p.setBool(AppSettingsKeys.pinLockEnabled, _pinLock);
    await p.setString(AppSettingsKeys.autoLockTimeout, _autoLock);
    await p.setBool(AppSettingsKeys.notifyHighSeverity, _notifyHigh);
    await p.setBool(AppSettingsKeys.notifyWatchlist, _notifyWatch);
    await p.setBool(AppSettingsKeys.notifyIsolation, _notifyIso);
    await p.setBool(AppSettingsKeys.notifyNewSoftware, _notifySoft);
    await p.setString(AppSettingsKeys.eventsDefaultRange, _eventsRange);
    await p.setInt(AppSettingsKeys.eventsMaxLoad, _eventsMax);
    await p.setBool(AppSettingsKeys.showIpv6Network, _showIpv6);
    await p.setBool(AppSettingsKeys.compactProcessCards, _compactProc);
    await p.setString(AppSettingsKeys.httpBase, _httpBase.text.trim());
  }

  Future<void> _saveConnection() async {
    const s = FlutterSecureStorage();
    final ep = _endpoint.text.trim();
    final tok = _jwt.text.trim();
    await s.write(key: 'em_host', value: ep);
    await s.write(key: 'em_token', value: tok);
    await _persistNonConnection();
    _savedEndpoint = ep;
    _savedJwt = tok;
    _savedHttp = _httpBase.text.trim();
    if (!mounted) return;
    if (ep.isNotEmpty && tok.isNotEmpty) {
      context.read<ConnectionBloc>().add(ConnectionConnectRequested(host: ep, token: tok));
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
  }

  Future<void> _testPing() async {
    final c = context.read<ConnectionBloc>();
    if (!c.state.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect to the endpoint first')),
      );
      return;
    }
    c.add(const ConnectionPingMeasureRequested());
  }

  Future<void> _exportEvents() async {
    try {
      const s = FlutterSecureStorage();
      final token = await s.read(key: 'em_token');
      final host = await s.read(key: 'em_host');
      if (token == null || host == null || token.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Save endpoint and device token first')),
          );
        }
        return;
      }
      final base = httpBaseFromMonitorHost(host);
      final dio = Dio(BaseOptions(
        baseUrl: base,
        connectTimeout: const Duration(seconds: 60),
        headers: {'Authorization': 'Bearer $token'},
      ));
      final res = await dio.get<List<dynamic>>('/export/events');
      final data = res.data;
      if (data == null) throw StateError('Empty export');
      final dir = await getTemporaryDirectory();
      final file = await File('${dir.path}/endpoint_monitor_events.json').writeAsString(
        jsonEncode(data),
      );
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: 'Endpoint Monitor events export');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _openNoiseEditor() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(AppSettingsKeys.noiseProcesses) ?? AppSettingsKeys.defaultNoiseCsv;
    final list = raw.split(',').map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toList();
    final addCtl = TextEditingController();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        var local = List<String>.from(list);
        return StatefulBuilder(
          builder: (context, setModal) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ListTile(title: Text('Noise filter (hidden by default in Events)')),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: local.length,
                        itemBuilder: (_, i) => ListTile(
                          title: Text(local[i], style: GoogleFonts.jetBrainsMono(fontSize: 13)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => setModal(() => local.removeAt(i)),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: addCtl,
                              decoration: const InputDecoration(labelText: 'Add process.exe'),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              final v = addCtl.text.trim().toLowerCase();
                              if (v.isEmpty) return;
                              setModal(() {
                                if (!local.contains(v)) local.add(v);
                                addCtl.clear();
                              });
                            },
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: () async {
                        await p.setString(AppSettingsKeys.noiseProcesses, local.join(','));
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Done'),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _promptNewPin() async {
    final c1 = TextEditingController();
    final c2 = TextEditingController();
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set 4-digit PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: c1, keyboardType: TextInputType.number, maxLength: 4, obscureText: true),
            TextField(controller: c2, keyboardType: TextInputType.number, maxLength: 4, obscureText: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (c1.text == c2.text && c1.text.length == 4) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok == true && c1.text.length == 4) {
      const s = FlutterSecureStorage();
      await s.write(key: 'em_security_pin', value: c1.text);
      pinGateReload.value++;
      if (mounted) setState(() => _pinLock = true);
      final p = await SharedPreferences.getInstance();
      await p.setBool(AppSettingsKeys.pinLockEnabled, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return BlocListener<ConnectionBloc, EmConnectionState>(
      listenWhen: (p, c) => p.lastTestPingMs != c.lastTestPingMs || p.lastTestPingError != c.lastTestPingError,
      listener: (context, s) {
        if (s.lastTestPingMs != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Connected · ${s.lastTestPingMs} ms')),
          );
        } else if (s.lastTestPingError != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.lastTestPingError!)));
        }
      },
      child: Scaffold(
        backgroundColor: scheme.surface,
        appBar: const EmBrandAppBar(),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            const EmPageIntro(
              title: 'Settings',
              subtitle: 'Connection, security, notifications, and display preferences.',
              padding: EdgeInsets.only(bottom: 16),
            ),
            if (_connectionDirty)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(EmDesign.radiusMd),
                ),
                child: Text(
                  'Unsaved changes in Connection',
                  style: theme.textTheme.labelLarge?.copyWith(color: scheme.onPrimaryContainer),
                ),
              ),
            _sectionLabel(context, 'CONNECTION'),
            _card(
              scheme,
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _endpoint,
                    style: GoogleFonts.jetBrainsMono(fontSize: 13),
                    decoration: const InputDecoration(labelText: 'Endpoint (host:port or ws URL)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _jwt,
                    obscureText: _hideJwt,
                    style: GoogleFonts.jetBrainsMono(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Device token (from pairing)',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _hideJwt = !_hideJwt),
                        icon: Icon(_hideJwt ? Icons.visibility : Icons.visibility_off),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _httpBase,
                    style: GoogleFonts.jetBrainsMono(fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'HTTP base (exports / REST)',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Remember endpoint'),
                    value: _rememberEndpoint,
                    onChanged: (v) => setState(() => _rememberEndpoint = v),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(onPressed: _testPing, child: const Text('Test connection')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _saveConnection, child: const Text('Save connection')),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _sectionLabel(context, 'SECURITY'),
            _card(
              scheme,
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('PIN lock'),
                    subtitle: const Text('Require PIN when opening the app'),
                    value: _pinLock,
                    onChanged: (v) async {
                      if (v) {
                        await _promptNewPin();
                      } else {
                        const s = FlutterSecureStorage();
                        await s.delete(key: 'em_security_pin');
                        final p = await SharedPreferences.getInstance();
                        await p.setBool(AppSettingsKeys.pinLockEnabled, false);
                        pinGateReload.value++;
                        setState(() => _pinLock = false);
                      }
                    },
                  ),
                  if (_pinLock) ...[
                    DropdownButtonFormField<String>(
                      key: ValueKey(_autoLock),
                      initialValue: _autoLock,
                      decoration: const InputDecoration(labelText: 'Auto-lock'),
                      items: const [
                        DropdownMenuItem(value: 'immediate', child: Text('Immediately')),
                        DropdownMenuItem(value: '60', child: Text('1 minute after background')),
                        DropdownMenuItem(value: '300', child: Text('5 minutes after background')),
                        DropdownMenuItem(value: 'never', child: Text('Never')),
                      ],
                      onChanged: (v) async {
                        if (v == null) return;
                        setState(() => _autoLock = v);
                        final p = await SharedPreferences.getInstance();
                        await p.setString(AppSettingsKeys.autoLockTimeout, v);
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  FutureBuilder<String?>(
                    future: const FlutterSecureStorage().read(key: 'em_token'),
                    builder: (context, snap) {
                      final t = snap.data;
                      final line = t == null || t.isEmpty
                          ? 'No device token saved'
                          : (t.split('.').length == 3
                              ? formatJwtExpiryLine(t)
                              : 'Device token saved (pair on Connect to replace)');
                      return Text(line, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _sectionLabel(context, 'NOTIFICATIONS'),
            _card(
              scheme,
              Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('High severity alerts'),
                    value: _notifyHigh,
                    onChanged: (v) => setState(() => _notifyHigh = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Watchlist process detected'),
                    value: _notifyWatch,
                    onChanged: (v) => setState(() => _notifyWatch = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Machine isolation changed'),
                    value: _notifyIso,
                    onChanged: (v) => setState(() => _notifyIso = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('New software installed'),
                    value: _notifySoft,
                    onChanged: (v) => setState(() => _notifySoft = v),
                  ),
                  FilledButton.tonal(
                    onPressed: () async {
                      await _persistNonConnection();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification prefs saved')));
                    },
                    child: const Text('Save notification prefs'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _sectionLabel(context, 'EVENTS'),
            _card(
              scheme,
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Manage noise filter'),
                    subtitle: FutureBuilder<SharedPreferences>(
                      future: SharedPreferences.getInstance(),
                      builder: (_, snap) {
                        final p = snap.data;
                        final n = p?.getString(AppSettingsKeys.noiseProcesses)?.split(',').where((e) => e.isNotEmpty).length ?? 0;
                        return Text('$n processes');
                      },
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _openNoiseEditor,
                  ),
                  const Text('Default time range (Events screen)'),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: '15m', label: Text('15m')),
                      ButtonSegment(value: '1h', label: Text('1h')),
                      ButtonSegment(value: '6h', label: Text('6h')),
                      ButtonSegment(value: 'all', label: Text('All')),
                    ],
                    selected: {_eventsRange},
                    onSelectionChanged: (s) => setState(() => _eventsRange = s.first),
                    showSelectedIcon: false,
                  ),
                  const SizedBox(height: 12),
                  const Text('Max events to load'),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 50, label: Text('50')),
                      ButtonSegment(value: 100, label: Text('100')),
                      ButtonSegment(value: 250, label: Text('250')),
                      ButtonSegment(value: 500, label: Text('500')),
                    ],
                    selected: {_eventsMax},
                    onSelectionChanged: (s) => setState(() => _eventsMax = s.first),
                    showSelectedIcon: false,
                  ),
                  FilledButton.tonal(
                    onPressed: () async {
                      final p = await SharedPreferences.getInstance();
                      await p.setString(AppSettingsKeys.eventsDefaultRange, _eventsRange);
                      await p.setInt(AppSettingsKeys.eventsMaxLoad, _eventsMax);
                      await _persistNonConnection();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Events prefs saved')));
                    },
                    child: const Text('Save events prefs'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _sectionLabel(context, 'DISPLAY'),
            _card(
              scheme,
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BlocBuilder<ThemeCubit, ThemeMode>(
                    builder: (context, mode) {
                      return SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                          ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                          ButtonSegment(value: ThemeMode.system, label: Text('System')),
                        ],
                        selected: {mode},
                        onSelectionChanged: (s) => context.read<ThemeCubit>().setTheme(s.first),
                      );
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show IPv6 addresses'),
                    subtitle: const Text('Network screen'),
                    value: _showIpv6,
                    onChanged: (v) => setState(() => _showIpv6 = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Compact process cards'),
                    value: _compactProc,
                    onChanged: (v) => setState(() => _compactProc = v),
                  ),
                  FilledButton.tonal(
                    onPressed: () async {
                      await _persistNonConnection();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Display prefs saved')));
                    },
                    child: const Text('Save display prefs'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _sectionLabel(context, 'GROQ AI'),
            _card(
              scheme,
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _groqApiKey,
                    obscureText: _hideGroqApi,
                    decoration: InputDecoration(
                      labelText: 'Groq API Key',
                      suffixIcon: IconButton(
                        icon: Icon(_hideGroqApi ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _hideGroqApi = !_hideGroqApi),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Free API key available at console.groq.com',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: _groqDirty ? _saveGroqApiKey : null,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _sectionLabel(context, 'THREAT INTEL'),
            _card(
              scheme,
              BlocBuilder<ThreatIntelBloc, ThreatIntelState>(
                builder: (context, ti) {
                  final rel = formatRelativeSinceUtcIso(ti.lastRunUtc);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${ti.entryCount} known threat IPs monitored',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Connections to these IPs trigger high severity alerts',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      if (rel.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Last updated: $rel',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (ti.feeds.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        for (final f in ti.feeds)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${f.name} · ${f.count} IPs',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                      if (ti.lastError != null && ti.lastError!.isNotEmpty)
                        Text(
                          ti.lastError!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.error,
                          ),
                        ),
                      const SizedBox(height: 10),
                      FilledButton.tonal(
                        onPressed: ti.loading
                            ? null
                            : () => context
                                .read<ThreatIntelBloc>()
                                .requestRefreshFeeds(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (ti.loading) ...[
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: scheme.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Text(
                                ti.loading ? 'Updating…' : 'Update feeds now'),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            _sectionLabel(context, 'DATA'),
            _card(
              scheme,
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Clear cached events?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                            FilledButton(
                              style: FilledButton.styleFrom(foregroundColor: scheme.onError, backgroundColor: scheme.error),
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true && context.mounted) {
                        context.read<EventsBloc>().clearAll();
                      }
                    },
                    child: const Text('Clear cached events'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Clear acknowledged alerts?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                            FilledButton(
                              style: FilledButton.styleFrom(foregroundColor: scheme.onError, backgroundColor: scheme.error),
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true && context.mounted) {
                        context.read<AlertsBloc>().clearAcknowledged();
                      }
                    },
                    child: const Text('Clear acknowledged alerts'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(onPressed: _exportEvents, child: const Text('Export all data (events JSON)')),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _sectionLabel(context, 'ABOUT'),
            _card(
              scheme,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('App version: $kAppVersion'),
                  BlocBuilder<SystemInfoBloc, SystemInfoState>(
                    builder: (context, si) {
                      final i = si.info;
                      if (i == null) return const Text('Service version: waiting…');
                      final v = i.agentVersion.trim().isNotEmpty ? i.agentVersion : i.osVersion;
                      return Text('Service version: ${v.isNotEmpty ? v : "—"}');
                    },
                  ),
                  BlocBuilder<ConnectionBloc, EmConnectionState>(
                    builder: (context, c) {
                      if (c.connectedAt == null) return const Text('Connection uptime: —');
                      final d = DateTime.now().difference(c.connectedAt!);
                      return Text('Connection uptime: ${d.inHours}h ${d.inMinutes.remainder(60)}m');
                    },
                  ),
                  BlocBuilder<SystemInfoBloc, SystemInfoState>(
                    builder: (context, si) {
                      final s = si.info?.sysmonStatus.trim();
                      return Text('Sysmon: ${(s == null || s.isEmpty) ? "—" : s}');
                    },
                  ),
                  BlocBuilder<SystemInfoBloc, SystemInfoState>(
                    builder: (context, si) {
                      final h = si.info?.systemName ?? '—';
                      return Text('Monitoring agent: $h');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        t,
        style: EmDesign.labelCaps(context, Theme.of(context).colorScheme),
      ),
    );
  }

  Widget _card(ColorScheme scheme, Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: EmDesign.cardShell(scheme),
      child: child,
    );
  }
}
