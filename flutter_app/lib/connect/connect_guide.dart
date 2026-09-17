import 'connect_path.dart';

/// Tailscale download links opened from the guided page.
const kTailscaleWindowsDownloadUri = 'https://tailscale.com/download/windows';
const kTailscaleMobileDownloadUri = 'https://tailscale.com/download';

/// Windows service / PC agent download (GitHub releases).
const kWindowsServiceReleasesUri =
    'https://github.com/cycalo/endpoint-monitor/releases';

const kWindowsServiceDownloadTitle = 'Download Windows service';
const kWindowsServiceDownloadSubtitle =
    'Install Endpoint Monitor on the PC before you connect from this phone.';

const kDefaultPairingPort = 5000;

/// Title shown on the chooser screen.
const kConnectChooserTitle = 'Connect to your PC';
const kConnectChooserSubtitle = 'How should this phone reach the PC?';

/// One numbered instruction in the guided connect flow.
class ConnectGuideStep {
  const ConnectGuideStep(this.text, {this.linkLabel, this.linkUri});

  final String text;
  final String? linkLabel;
  final String? linkUri;
}

/// Guided page title for each path.
String connectGuidedTitle(ConnectPath path) => switch (path) {
      ConnectPath.wifi => 'Connect over Wi-Fi',
      ConnectPath.tailscale => 'Connect with Tailscale',
    };

/// Short description under each chooser card.
String connectPathCardSubtitle(ConnectPath path) => switch (path) {
      ConnectPath.wifi => 'Phone and PC on the same network. Fastest first-time setup.',
      ConnectPath.tailscale => 'Reach the PC over Tailscale from any network.',
    };

/// Label for each chooser card.
String connectPathCardTitle(ConnectPath path) => switch (path) {
      ConnectPath.wifi => 'This Wi-Fi',
      ConnectPath.tailscale => 'Away from home',
    };

/// Numbered setup steps shown above the form.
List<ConnectGuideStep> connectGuideSteps(ConnectPath path, {required bool alreadyPaired}) {
  switch (path) {
    case ConnectPath.wifi:
      return [
        const ConnectGuideStep(
          'On the PC, Endpoint Monitor is running.',
        ),
        const ConnectGuideStep(
          'This phone is on the same Wi-Fi as the PC.',
        ),
        const ConnectGuideStep(
          'On the PC, open the Endpoint Monitor desktop app → Pair. Copy the Wi-Fi address shown there.',
        ),
        ConnectGuideStep(
          alreadyPaired
              ? 'Enter that address, then tap Connect.'
              : 'Enter that address and the 6-digit code, then tap Connect.',
        ),
      ];
    case ConnectPath.tailscale:
      final steps = <ConnectGuideStep>[
        const ConnectGuideStep(
          'On the PC, install Tailscale, sign in, and leave it connected.',
          linkLabel: 'install Tailscale',
          linkUri: kTailscaleWindowsDownloadUri,
        ),
        const ConnectGuideStep(
          'On this phone, install Tailscale, sign in with the same account, and wait until it shows connected.',
          linkLabel: 'install Tailscale',
          linkUri: kTailscaleMobileDownloadUri,
        ),
        const ConnectGuideStep(
          'In Tailscale on the PC, copy the Tailscale IP (starts with 100.) or MagicDNS name (something.ts.net).',
        ),
      ];
      if (!alreadyPaired) {
        steps.add(
          const ConnectGuideStep(
            'On the PC, open the Endpoint Monitor desktop app → Pair. Copy the Tailscale address (starts with 100.) from Away from home.',
          ),
        );
      }
      steps.add(
        ConnectGuideStep(
          alreadyPaired
              ? 'Paste the Tailscale address, then tap Connect.'
              : 'Paste the Tailscale address and the code, then tap Connect.',
        ),
      );
      return steps;
  }
}

/// Hint text for the PC address field.
String connectAddressHint(ConnectPath path) => switch (path) {
      ConnectPath.wifi => '192.168.1.50',
      ConnectPath.tailscale => '100.x.x.x or my-pc.ts.net',
    };

/// Helper under the address field.
String connectAddressHelper(ConnectPath path) => switch (path) {
      ConnectPath.wifi =>
        'Copy the This Wi-Fi address from Pair on the PC. Optional: include :port (default $kDefaultPairingPort).',
      ConnectPath.tailscale =>
        'Copy the Away from home (Tailscale) address from Pair on the PC. Optional: include :port (default $kDefaultPairingPort).',
    };

/// Shown when health check fails.
String connectUnreachableMessage(ConnectPath path) => switch (path) {
      ConnectPath.wifi =>
        'Could not reach the PC. Check same Wi-Fi, the address from the desktop app Pair screen, Windows Firewall, and that Endpoint Monitor is running.',
      ConnectPath.tailscale =>
        'Could not reach the PC. Check both devices show Connected in Tailscale with the same account, use a 100. or .ts.net address (not a home 192.168 address when away), Windows Firewall, and that Endpoint Monitor is running.',
    };

/// Callout above the pairing code field.
const kPairingCodeCallout =
    'Only needed the first time. Generate the code in the Endpoint Monitor desktop app (Pair screen). Codes expire in about 5 minutes.';

/// Label for the continue chip on the chooser when a saved session exists.
String continueToSavedLabel(String address) => 'Continue to $address';

/// Primary chooser card for QR pairing.
const kConnectScanQrTitle = 'Scan QR code';
const kConnectScanQrSubtitle =
    'Fastest setup. On the PC, open Pair and scan the QR code with this phone.';

/// Shown when a scanned QR is not a valid Endpoint Monitor pairing payload.
const kPairingQrInvalidMessage =
    'This QR code is not a valid Endpoint Monitor pairing code. Scan the code from the PC Pair screen.';

/// Shown when `expiresAt` in the QR payload is in the past (client-side check).
const kPairingQrExpiredMessage =
    'This pairing code has expired. On the PC, open Pair and tap New code, then scan again.';

/// Scanner screen copy.
const kConnectQrScanTitle = 'Scan pairing QR';
const kConnectQrScanSubtitle =
    'Point your camera at the QR code on the PC Pair screen.';

const kConnectQrCameraDeniedMessage =
    'Camera access is required to scan the pairing QR code.';

const kConnectQrOpenSettingsLabel = 'Open Settings';

const kConnectQrUnsupportedPlatformMessage =
    'QR scanning is only available on Android and iOS. Use This Wi-Fi or Away from home to connect manually.';
