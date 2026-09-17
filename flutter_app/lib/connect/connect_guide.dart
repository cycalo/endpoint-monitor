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
      ConnectPath.wifi => 'Phone and PC on the same local network.',
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
          'On the PC, open Endpoint Monitor → Pair. Scan the QR, or copy the This Wi-Fi address.',
        ),
        ConnectGuideStep(
          alreadyPaired
              ? 'Scan the QR, or enter that address and tap Connect.'
              : 'Scan the QR, or enter that address and the 6-digit code, then tap Connect.',
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
      steps.add(
        ConnectGuideStep(
          alreadyPaired
              ? 'On the PC, open Pair. Scan the QR (this uses the Tailscale address) or paste a 100. / .ts.net address, then tap Connect.'
              : 'On the PC, open Pair. Scan the QR (this uses the Tailscale address) or paste a 100. / .ts.net address and the code, then tap Connect.',
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

/// Scan QR control on a guided connect page.
const kConnectScanQrTitle = 'Scan QR code';

String connectScanQrSubtitle(ConnectPath path) => switch (path) {
      ConnectPath.wifi =>
        'Uses the This Wi-Fi address from Pair — not Tailscale, even if both are in the QR.',
      ConnectPath.tailscale =>
        'Uses the Away from home (Tailscale) address from Pair — even if you are on the same Wi-Fi.',
    };

String connectQrScanSubtitle(ConnectPath path) => switch (path) {
      ConnectPath.wifi =>
        'Point your camera at the Pair QR. This phone will connect over local Wi-Fi.',
      ConnectPath.tailscale =>
        'Point your camera at the Pair QR. This phone will connect over Tailscale.',
    };

/// QR parsed, but it had no hosts for the path the user chose.
String pairingQrNoHostsForPathMessage(ConnectPath path) => switch (path) {
      ConnectPath.wifi =>
        'That QR has no local Wi-Fi address. On the PC, check This Wi-Fi on the Pair screen, or go back and choose Away from home.',
      ConnectPath.tailscale =>
        'That QR has no Tailscale address. On the PC, connect Tailscale and tap New code, or go back and choose This Wi-Fi.',
    };

/// Shown when a scanned QR is not a valid Endpoint Monitor pairing payload.
const kPairingQrInvalidMessage =
    'This QR code is not a valid Endpoint Monitor pairing code. Scan the code from the PC Pair screen.';

/// Shown when `expiresAt` in the QR payload is in the past (client-side check).
const kPairingQrExpiredMessage =
    'This pairing code has expired. On the PC, open Pair and tap New code, then scan again.';

/// Scanner screen copy.
const kConnectQrScanTitle = 'Scan pairing QR';

const kConnectQrCameraDeniedMessage =
    'Camera access is required to scan the pairing QR code.';

const kConnectQrOpenSettingsLabel = 'Open Settings';

const kConnectQrUnsupportedPlatformMessage =
    'QR scanning is only available on Android and iOS. Enter the address below instead.';
