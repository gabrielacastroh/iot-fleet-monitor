import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

/// RESP-1's ≥600dp list-detail layout skeleton: a fixed-width list pane, a
/// hairline divider, and an expanded detail pane. Used identically by the
/// vehicles and alerts branches — the route tree itself never changes
/// (design §14 risk #3's `LayoutBuilder`-at-the-branch-screen fallback).
const twoPaneListWidth = 360.0;

/// RESP-1's shared breakpoint: at or above this width, navigation switches
/// to a `NavigationRail` and the vehicles/alerts branches switch to
/// two-pane. Applied consistently against the local `LayoutBuilder`
/// constraints of whichever content area is measuring it.
const tabletBreakpoint = 600.0;

Widget twoPaneRow({required Widget list, required Widget detail}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(width: twoPaneListWidth, child: list),
      const VerticalDivider(width: 1, color: AppColors.border),
      Expanded(child: detail),
    ],
  );
}
