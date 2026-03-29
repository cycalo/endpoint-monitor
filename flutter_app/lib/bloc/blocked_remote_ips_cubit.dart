import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ws_models.dart';
import '../utils/ip_normalize.dart';

/// Client-side blocked remote IPs plus last-known connection metadata. The OS
/// snapshot may drop blocked sockets; we persist enough to label rows (process, PID).
class BlockedRemoteIpsCubit extends Cubit<Map<String, BlockedRemoteMeta>> {
  BlockedRemoteIpsCubit() : super({}) {
    _load();
  }

  static const _prefsKeyV2 = 'em_blocked_remotes_v2';
  static const _prefsKeyLegacy = 'em_blocked_remote_ips';

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final v2 = p.getString(_prefsKeyV2);
    if (v2 != null && v2.isNotEmpty) {
      try {
        final decoded = jsonDecode(v2) as Map<String, dynamic>;
        final m = <String, BlockedRemoteMeta>{};
        for (final e in decoded.entries) {
          final k = normalizeIpForBlockList(e.key);
          if (k.isEmpty) continue;
          m[k] = BlockedRemoteMeta.fromJson(
            Map<String, dynamic>.from(e.value as Map),
          );
        }
        emit(m);
      } catch (_) {
        emit({});
      }
      return;
    }

    final legacy = p.getStringList(_prefsKeyLegacy);
    if (legacy != null && legacy.isNotEmpty) {
      final m = <String, BlockedRemoteMeta>{};
      for (final e in legacy) {
        final k = normalizeIpForBlockList(e);
        if (k.isEmpty) continue;
        m[k] = const BlockedRemoteMeta();
      }
      emit(m);
      await _save(m);
      await p.remove(_prefsKeyLegacy);
    }
  }

  Future<void> _save(Map<String, BlockedRemoteMeta> next) async {
    final p = await SharedPreferences.getInstance();
    final sortedKeys = next.keys.toList()..sort();
    final json = jsonEncode({
      for (final k in sortedKeys) k: next[k]!.toJson(),
    });
    await p.setString(_prefsKeyV2, json);
  }

  bool isBlocked(String remoteAddress) {
    final k = normalizeIpForBlockList(remoteAddress);
    return k.isNotEmpty && state.containsKey(k);
  }

  BlockedRemoteMeta? metaFor(String remoteAddress) {
    final k = normalizeIpForBlockList(remoteAddress);
    if (k.isEmpty) return null;
    return state[k];
  }

  /// [snapshot] should be the connection row at block time (process name, PID, ports).
  Future<void> add(
    String remoteAddress, {
    NetworkConnection? snapshot,
  }) async {
    final k = normalizeIpForBlockList(remoteAddress);
    if (k.isEmpty) return;
    final BlockedRemoteMeta meta;
    if (snapshot != null) {
      meta = BlockedRemoteMeta.fromConnection(snapshot);
    } else if (state.containsKey(k)) {
      return;
    } else {
      meta = const BlockedRemoteMeta();
    }
    final next = {...state, k: meta};
    emit(next);
    await _save(next);
  }

  Future<void> remove(String remoteAddress) async {
    final k = normalizeIpForBlockList(remoteAddress);
    if (k.isEmpty) return;
    if (!state.containsKey(k)) return;
    final next = {...state}..remove(k);
    emit(next);
    await _save(next);
  }
}
