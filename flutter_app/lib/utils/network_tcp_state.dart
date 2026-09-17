import 'package:flutter/material.dart';

/// Normalizes MSFT_NetTCPConnection [State] (numeric CIM or string) for filters/UI.
String normalizeCimTcpState(String rawState) {
  final s = rawState.trim();
  if (s.isEmpty) return '';
  if (s.toUpperCase() == 'BLOCKED') return 'BLOCKED';
  final n = int.tryParse(s);
  if (n == null) return s.toUpperCase();
  switch (n) {
    case 1:
      return 'CLOSED';
    case 2:
      return 'LISTEN';
    case 3:
      return 'SYN_SENT';
    case 4:
      return 'SYN_RECV';
    case 5:
      return 'ESTABLISHED';
    case 6:
      return 'FIN_WAIT1';
    case 7:
      return 'FIN_WAIT2';
    case 8:
      return 'CLOSE_WAIT';
    case 9:
      return 'CLOSING';
    case 10:
      return 'LAST_ACK';
    case 11:
      return 'TIME_WAIT';
    case 12:
      return 'DELETE_TCB';
    case 100:
      return 'BOUND';
    default:
      return 'STATE_$n';
  }
}

bool isEstablishedTcpState(String rawState) =>
    normalizeCimTcpState(rawState) == 'ESTABLISHED';

bool isListenTcpState(String rawState) =>
    normalizeCimTcpState(rawState) == 'LISTEN';

bool isBoundTcpState(String rawState) =>
    normalizeCimTcpState(rawState) == 'BOUND';

Color networkStateColor(ColorScheme scheme, String normalizedState) {
  switch (normalizedState) {
    case 'ESTABLISHED':
      return const Color(0xFF2FD9F4);
    case 'LISTEN':
      return const Color(0xFFFFC857);
    case 'BOUND':
      return scheme.outline;
    case 'TIME_WAIT':
      return const Color(0xFF6CD3FF);
    case 'CLOSE_WAIT':
      return scheme.error;
    case 'SYN_SENT':
    case 'SYN_RECV':
      return const Color(0xFF4D7CFE);
    case 'FIN_WAIT1':
    case 'FIN_WAIT2':
    case 'CLOSING':
    case 'LAST_ACK':
      return const Color(0xFF9B8CFF);
    case 'CLOSED':
    case 'DELETE_TCB':
      return scheme.outline;
    case 'BLOCKED':
      return scheme.error;
    default:
      return scheme.onSurfaceVariant;
  }
}
