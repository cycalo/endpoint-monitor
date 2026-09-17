import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../connect/connect_guide.dart';
import '../connect/connect_path.dart';
import '../theme/em_design_system.dart';
import '../widgets/em_gradient_button.dart';
import '../widgets/em_loading_states.dart';

/// One guided connect page: checklist, address, optional code, Connect.
class ConnectGuidedPage extends StatelessWidget {
  const ConnectGuidedPage({
    super.key,
    required this.path,
    required this.alreadyPaired,
    required this.addressController,
    required this.codeController,
    required this.rememberAddress,
    required this.busy,
    required this.connecting,
    required this.errorMessage,
    required this.onRememberChanged,
    required this.onBack,
    required this.onConnect,
    required this.onScanQr,
    this.onPairAgain,
  });

  final ConnectPath path;
  final bool alreadyPaired;
  final TextEditingController addressController;
  final TextEditingController codeController;
  final bool rememberAddress;
  final bool busy;
  final bool connecting;
  final String? errorMessage;
  final ValueChanged<bool> onRememberChanged;
  final VoidCallback onBack;
  final VoidCallback onConnect;
  final VoidCallback onScanQr;
  final VoidCallback? onPairAgain;

  Future<void> _openUri(BuildContext context, String uri) async {
    final launched = await launchUrl(
      Uri.parse(uri),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mono = GoogleFonts.jetBrainsMono(fontSize: 13, color: scheme.onSurface);
    final steps = connectGuideSteps(path, alreadyPaired: alreadyPaired);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: busy ? null : onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Back',
            ),
            Expanded(
              child: Text(
                connectGuidedTitle(path),
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary.withValues(alpha: 0.14),
                    border: Border.all(color: scheme.primary.withValues(alpha: 0.45)),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _GuideStepText(
                    step: step,
                    onOpenLink: step.linkUri == null
                        ? null
                        : () => _openUri(context, step.linkUri!),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        Material(
          color: scheme.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(EmDesign.radiusLg),
          child: InkWell(
            onTap: busy ? null : onScanQr,
            borderRadius: BorderRadius.circular(EmDesign.radiusLg),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: EmDesign.cardShell(
                scheme,
                color: scheme.primaryContainer.withValues(alpha: 0.35),
              ),
              child: Row(
                children: [
                  Icon(Icons.qr_code_scanner_rounded, color: scheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kConnectScanQrTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          connectScanQrSubtitle(path),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: scheme.outline),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Or enter the address',
          style: theme.textTheme.labelLarge?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        _LabeledField(
          label: 'PC address',
          child: TextField(
            controller: addressController,
            enabled: !busy,
            style: mono,
            decoration: InputDecoration(
              hintText: connectAddressHint(path),
              prefixIcon: Icon(Icons.lan_rounded, color: scheme.outline, size: 20),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          connectAddressHelper(path),
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
            fontSize: 11,
            height: 1.35,
          ),
        ),
        if (!alreadyPaired) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: EmDesign.cardShell(
              scheme,
              color: scheme.surfaceContainerHigh,
            ),
            child: Text(
              kPairingCodeCallout,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _LabeledField(
            label: '6-digit code',
            child: TextField(
              controller: codeController,
              enabled: !busy,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 22,
                letterSpacing: 8,
                color: scheme.onSurface,
              ),
              decoration: const InputDecoration(
                hintText: '000000',
                counterText: '',
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_user_outlined, size: 16, color: scheme.tertiary),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This phone is already paired. Enter the address and connect.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (onPairAgain != null)
                      TextButton(
                        onPressed: busy ? null : onPairAgain,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.only(top: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Use a new pairing code'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: rememberAddress,
          onChanged: busy ? null : (v) => onRememberChanged(v ?? false),
          title: Text(
            'Remember this address',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 8),
          EmStatusPanel(icon: Icons.error_outline_rounded, message: errorMessage!),
        ],
        const SizedBox(height: 14),
        EmGradientButton(
          label: connecting ? 'Connecting…' : (busy ? 'Working…' : 'Connect'),
          icon: Icons.bolt_rounded,
          inProgress: busy || connecting,
          onPressed: (busy || connecting) ? null : onConnect,
        ),
      ],
    );
  }
}

class _GuideStepText extends StatelessWidget {
  const _GuideStepText({
    required this.step,
    this.onOpenLink,
  });

  final ConnectGuideStep step;
  final VoidCallback? onOpenLink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
      height: 1.4,
    );

    final linkLabel = step.linkLabel;
    if (linkLabel == null || onOpenLink == null || !step.text.contains(linkLabel)) {
      return Text(step.text, style: style);
    }

    final parts = step.text.split(linkLabel);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: parts.first),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: InkWell(
              onTap: onOpenLink,
              child: Text(
                linkLabel,
                style: style?.copyWith(
                  color: scheme.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: scheme.primary,
                ),
              ),
            ),
          ),
          if (parts.length > 1) TextSpan(text: parts.sublist(1).join(linkLabel)),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: EmDesign.labelCaps(context, scheme)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
