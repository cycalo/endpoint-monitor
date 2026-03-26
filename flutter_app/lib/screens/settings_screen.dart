import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_version.dart';
import '../theme/theme_cubit.dart';
import '../widgets/em_brand_app_bar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _httpBase = TextEditingController();
  final _static = TextEditingController();
  final _pin = TextEditingController();
  bool _hideToken = true;
  String? _message;

  @override
  void dispose() {
    _httpBase.dispose();
    _static.dispose();
    _pin.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _httpBase.text = p.getString('em_http_base') ?? 'http://192.168.1.10:5000';
    final s = const FlutterSecureStorage();
    _static.text = await s.read(key: 'em_static_token') ?? '';
    _pin.text = await s.read(key: 'em_app_pin') ?? '';
    setState(() {});
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('em_http_base', _httpBase.text.trim());
    final s = const FlutterSecureStorage();
    await s.write(key: 'em_static_token', value: _static.text.trim());
    await s.write(key: 'em_app_pin', value: _pin.text.trim());
    setState(() => _message = 'Saved');
  }

  Future<void> _exchangeJwt() async {
    setState(() => _message = null);
    try {
      final dio = Dio(BaseOptions(baseUrl: _httpBase.text.trim(), connectTimeout: const Duration(seconds: 10)));
      final res = await dio.post<Map<String, dynamic>>(
        '/api/auth/token',
        data: {'token': _static.text.trim()},
      );
      final jwt = res.data?['token'] as String?;
      if (jwt == null) throw StateError('No token in response');
      const storage = FlutterSecureStorage();
      await storage.write(key: 'em_token', value: jwt);
      setState(() => _message = 'JWT saved to secure storage as em_token');
    } catch (e) {
      setState(() => _message = e.toString());
    }
  }

  Future<void> _rememberEndpoint() async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList('em_endpoints') ?? [];
    final host = _httpBase.text.trim();
    if (host.isEmpty) return;
    final next = [host, ...list.where((e) => e != host)].take(3).toList();
    await p.setStringList('em_endpoints', next);
    setState(() => _message = 'Endpoint added to history (last 3)');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: const EmBrandAppBar(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'SETTINGS',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Appearance',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          BlocBuilder<ThemeCubit, ThemeMode>(
            builder: (context, mode) {
              return SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_outlined)),
                  ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
                ],
                selected: {mode},
                onSelectionChanged: (s) => context.read<ThemeCubit>().setTheme(s.first),
              );
            },
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _httpBase,
            style: GoogleFonts.jetBrainsMono(fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'HTTP base (for JWT exchange)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _static,
            obscureText: _hideToken,
            style: GoogleFonts.jetBrainsMono(fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Static shared token',
              suffixIcon: IconButton(
                onPressed: () => setState(() => _hideToken = !_hideToken),
                icon: Icon(_hideToken ? Icons.visibility : Icons.visibility_off),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _exchangeJwt, child: const Text('Exchange JWT')),
          const SizedBox(height: 8),
          FilledButton.tonal(onPressed: _rememberEndpoint, child: const Text('Remember endpoint (last 3)')),
          const SizedBox(height: 16),
          TextField(
            controller: _pin,
            obscureText: true,
            style: GoogleFonts.jetBrainsMono(fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Optional app PIN (stored locally)',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _savePrefs, child: const Text('Save settings')),
          if (_message != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_message!)),
          const SizedBox(height: 32),
          Text(
            'About',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'App version $kAppVersion',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
