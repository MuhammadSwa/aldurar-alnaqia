import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// First-run onboarding shown when entering a slidable zikr collection.
/// Hand-slide animation + a short message telling the user they can swipe
/// right and left to move between azkar.
class SwipeHintDialog extends StatelessWidget {
  const SwipeHintDialog({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  static const String animationAsset = 'assets/lottie/handslide.lottie';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The handslide artwork is single-color black line art, so a srcIn
    // tint recolors every stroke to the theme primary while keeping the
    // original alpha/animation. Rebuilt from Theme.of, so light/dark and
    // any custom scheme update automatically.
    final themedAnimation = ColorFiltered(
      colorFilter: ColorFilter.mode(scheme.primary, BlendMode.srcIn),
      child: Lottie.asset(
        animationAsset,
        width: 160,
        height: 120,
        repeat: true,
        // Tests / missing bundle / unsupported format must not crash
        // the zikr page — fall back to a static swipe icon.
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.swipe,
          size: 80,
          color: scheme.primary,
        ),
      ),
    );
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            themedAnimation,
            const SizedBox(height: 12),
            const Text(
              'اسحب يمينًا ويسارًا للتنقل بين الأذكار',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onDismiss,
                child: const Text('فهمت'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
