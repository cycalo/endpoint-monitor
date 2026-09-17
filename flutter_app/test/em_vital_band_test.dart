import 'package:endpoint_monitor/utils/em_vital_band.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('emVitalBandForPercent', () {
    test('calm below 60', () {
      expect(emVitalBandForPercent(0), EmVitalBand.calm);
      expect(emVitalBandForPercent(59.9), EmVitalBand.calm);
    });

    test('warn between 60 and 80', () {
      expect(emVitalBandForPercent(60), EmVitalBand.warn);
      expect(emVitalBandForPercent(79.9), EmVitalBand.warn);
    });

    test('critical at 80 and above', () {
      expect(emVitalBandForPercent(80), EmVitalBand.critical);
      expect(emVitalBandForPercent(100), EmVitalBand.critical);
    });
  });

  group('emEndpointHealthScore', () {
    test('returns 100 when all vitals are zero', () {
      expect(
        emEndpointHealthScore(cpuPercent: 0, ramPercent: 0, diskPercent: 0),
        100,
      );
    });

    test('applies weighted formula and clamps', () {
      expect(
        emEndpointHealthScore(cpuPercent: 100, ramPercent: 100, diskPercent: 100),
        0,
      );
      final score = emEndpointHealthScore(
        cpuPercent: 50,
        ramPercent: 50,
        diskPercent: 50,
      );
      expect(score, 50);
    });
  });

  group('emWorstVitalBand', () {
    test('returns critical when any vital is critical', () {
      expect(
        emWorstVitalBand(cpuPercent: 10, ramPercent: 10, diskPercent: 85),
        EmVitalBand.critical,
      );
    });
  });

  group('emParseAgentUptime', () {
    test('parses agent format', () {
      final d = emParseAgentUptime('3d 4h 12m');
      expect(d, const Duration(days: 3, hours: 4, minutes: 12));
    });

    test('returns null for invalid', () {
      expect(emParseAgentUptime(''), isNull);
      expect(emParseAgentUptime('bad'), isNull);
    });
  });

  group('emVitalBandColor', () {
    test('maps bands to scheme tokens', () {
      final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);
      expect(
        emVitalBandColor(scheme, EmVitalBand.calm),
        scheme.tertiary,
      );
      expect(
        emVitalBandColor(scheme, EmVitalBand.critical),
        scheme.error,
      );
    });
  });
}
