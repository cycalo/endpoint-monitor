import 'package:endpoint_monitor/connect/connect_guide.dart';
import 'package:endpoint_monitor/connect/connect_path.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('connectGuideSteps', () {
    test('wifi guide does not mention Tailscale install', () {
      final steps = connectGuideSteps(ConnectPath.wifi, alreadyPaired: false);
      final joined = steps.map((s) => s.text).join(' ').toLowerCase();
      expect(joined, contains('wi-fi'));
      expect(joined, isNot(contains('tailscale.com/download')));
      expect(joined, isNot(contains('install tailscale')));
    });

    test('tailscale guide includes install links and same account', () {
      final steps = connectGuideSteps(ConnectPath.tailscale, alreadyPaired: false);
      final joined = steps.map((s) => s.text).join(' ').toLowerCase();
      expect(joined, contains('same account'));
      expect(joined, contains('100.'));
      expect(joined, contains('.ts.net'));
      expect(
        steps.any((s) => s.linkUri == kTailscaleWindowsDownloadUri),
        isTrue,
      );
      expect(
        steps.any((s) => s.linkUri == kTailscaleMobileDownloadUri),
        isTrue,
      );
    });

    test('paired tailscale guide omits pairing code step', () {
      final steps = connectGuideSteps(ConnectPath.tailscale, alreadyPaired: true);
      expect(steps.any((s) => s.text.contains('pairing code')), isFalse);
      expect(steps.length, 4);
    });
  });

  group('inferConnectPathFromHost', () {
    test('detects tailscale ip and magicdns', () {
      expect(inferConnectPathFromHost('100.64.0.1'), ConnectPath.tailscale);
      expect(inferConnectPathFromHost('my-pc.ts.net'), ConnectPath.tailscale);
      expect(inferConnectPathFromHost('http://100.64.0.1:5000'), ConnectPath.tailscale);
    });

    test('defaults to wifi for lan addresses', () {
      expect(inferConnectPathFromHost('192.168.1.50'), ConnectPath.wifi);
    });
  });
}
