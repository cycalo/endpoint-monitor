import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/ws_models.dart';

/// Persists last-known endpoint snapshots for offline / disconnected viewing.
abstract final class EmSnapshotCache {
  static const _kSystemInfo = 'em_cache_system_info_json';
  static const _kSystemInfoAt = 'em_cache_system_info_at';
  static const _kProcesses = 'em_cache_processes_json';
  static const _kProcessesAt = 'em_cache_processes_at';
  static const _kNetwork = 'em_cache_network_json';
  static const _kNetworkAt = 'em_cache_network_at';

  static Future<void> saveSystemInfoRaw(Map<String, dynamic> raw) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kSystemInfo, jsonEncode(raw));
    await p.setString(_kSystemInfoAt, DateTime.now().toUtc().toIso8601String());
  }

  static Future<SystemInfo?> loadSystemInfo() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kSystemInfo);
    if (raw == null || raw.isEmpty) return null;
    try {
      return SystemInfo.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<DateTime?> systemInfoCachedAt() async {
    final p = await SharedPreferences.getInstance();
    return DateTime.tryParse(p.getString(_kSystemInfoAt) ?? '')?.toUtc();
  }

  static Future<void> saveProcessesRaw(List<dynamic> rawList) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kProcesses, jsonEncode(rawList));
    await p.setString(_kProcessesAt, DateTime.now().toUtc().toIso8601String());
  }

  static Future<List<ProcessInfo>> loadProcesses() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kProcesses);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => ProcessInfo.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<DateTime?> processesCachedAt() async {
    final p = await SharedPreferences.getInstance();
    return DateTime.tryParse(p.getString(_kProcessesAt) ?? '')?.toUtc();
  }

  static Future<void> saveNetworkRaw(List<dynamic> rawList) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kNetwork, jsonEncode(rawList));
    await p.setString(_kNetworkAt, DateTime.now().toUtc().toIso8601String());
  }

  static Future<List<NetworkConnection>> loadNetwork() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kNetwork);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) =>
              NetworkConnection.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<DateTime?> networkCachedAt() async {
    final p = await SharedPreferences.getInstance();
    return DateTime.tryParse(p.getString(_kNetworkAt) ?? '')?.toUtc();
  }
}
