import 'package:flutter/material.dart';

import '../tokens/app_radii.dart';
import '../tokens/app_shadows.dart';
import '../tokens/app_spacing.dart';

/// The app's card surface. `elevation: 0` always — depth comes from
/// [AppShadows], not Material elevation (design §2.4).
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.lifted = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Raised cards (design §2.4 `lift`) vs. the default `soft` shadow.
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: lifted ? AppShadows.lift : AppShadows.soft,
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
