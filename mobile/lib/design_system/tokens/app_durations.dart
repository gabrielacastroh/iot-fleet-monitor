import 'package:flutter/material.dart';

/// Motion tokens, literal port of `frontend/src/index.css`'s duration scale
/// and `prefers-reduced-motion` block. See design §2.4.
class AppDurations {
  const AppDurations._();

  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 300);

  static const enterCurve = Curves.easeOut;
  static const exitCurve = Curves.easeIn;

  /// The single reduced-motion gate: returns [Duration.zero] when
  /// `MediaQuery.disableAnimations` is set, [duration] otherwise.
  static Duration of(BuildContext context, Duration duration) {
    return MediaQuery.of(context).disableAnimations ? Duration.zero : duration;
  }
}
