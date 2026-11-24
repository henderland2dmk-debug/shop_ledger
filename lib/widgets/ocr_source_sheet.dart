import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/ocr/ocr_service.dart';

/// Asks whether the list should be photographed or chosen from the gallery.
Future<OcrSource?> showOcrSourceSheet(BuildContext context) {
  return showModalBottomSheet<OcrSource>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Scan an item list',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Use a clear photo of a bill or paper list.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              _SourceTile(
                actionKey: const Key('ocr-source-camera'),
                icon: Icons.photo_camera_outlined,
                label: 'Open camera',
                onTap: () => Navigator.of(context).pop(OcrSource.camera),
              ),
              const SizedBox(height: 10),
              _SourceTile(
                actionKey: const Key('ocr-source-gallery'),
                icon: Icons.photo_library_outlined,
                label: 'Upload image',
                onTap: () => Navigator.of(context).pop(OcrSource.gallery),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.actionKey,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Key actionKey;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFAFBF8),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        key: actionKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 14),
              Text(label, style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
