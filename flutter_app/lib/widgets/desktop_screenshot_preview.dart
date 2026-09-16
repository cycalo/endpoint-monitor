import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DesktopScreenshotPreview extends StatelessWidget {
  const DesktopScreenshotPreview({
    required this.bytes,
    required this.retakePending,
    required this.onRetake,
    required this.onClose,
    required this.onDownload,
    required this.onShare,
    super.key,
  });

  final Uint8List bytes;
  final bool retakePending;
  final VoidCallback? onRetake;
  final VoidCallback onClose;
  final VoidCallback onDownload;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxW = MediaQuery.sizeOf(context).width * 0.92;
    final maxH = MediaQuery.sizeOf(context).height * 0.62;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 4, 0),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Close',
                  onPressed: onClose,
                  icon: Icon(Icons.close_rounded, color: scheme.onSurface),
                ),
                Expanded(
                  child: Text(
                    'Desktop screenshot',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: scheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Retake',
                  onPressed: retakePending ? null : onRetake,
                  icon: retakePending
                      ? SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.primary,
                          ),
                        )
                      : Icon(Icons.refresh_rounded, color: scheme.primary),
                ),
                IconButton(
                  tooltip: 'Download',
                  onPressed: onDownload,
                  icon: Icon(Icons.download_rounded, color: scheme.primary),
                ),
                IconButton(
                  tooltip: 'Share',
                  onPressed: onShare,
                  icon: Icon(Icons.share_rounded, color: scheme.primary),
                ),
              ],
            ),
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: maxW,
            height: maxH,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: InteractiveViewer(
                  minScale: 0.2,
                  maxScale: 5,
                  child: Center(
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
