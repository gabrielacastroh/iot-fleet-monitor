import 'package:flutter/material.dart';

import '../tokens/app_radii.dart';

/// The app's primary button. Guarantees a minimum 48x48dp hit area
/// (A11Y-1) and a built-in loading state that disables the button and
/// swaps the label for a spinner (used by AUTH-6's double-submit guard).
///
/// [onPressed] is nullable (AUTH-5) so callers can express a genuinely
/// disabled button — `FilledButton` derives its own `enabled` semantics
/// flag from `onPressed == null`, so no separate `enabled` field is
/// needed here.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.borderRadius = AppRadii.md,
    this.trailing,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  /// Callers that sit inside a card of their own can match its radius —
  /// a button rounded tighter than everything around it reads as borrowed
  /// from a different screen.
  final double borderRadius;

  /// Optional glyph after the label, for a button that also states a
  /// direction ("Ingresar →"). Hidden while [isLoading].
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : trailing == null
            ? Text(label)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text(label), const SizedBox(width: 10), trailing!],
              ),
      ),
    );
  }
}
