import 'package:flutter/material.dart';

import '../../design_system/strings/app_strings.dart';

/// One entry per `StatefulShellRoute` branch, in branch order (design §7).
/// [selectedIcon] is the filled counterpart of [icon] — the selected
/// destination reads as filled-on-tint, unselected as outline-on-muted, so
/// the active branch never depends on colour alone.
class ShellNavItem {
  const ShellNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badges = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// Whether this destination shows the open-alerts count. A flag on the item
  /// rather than an index check in the shell, so reordering the branches
  /// cannot silently move the badge onto the wrong tab.
  final bool badges;
}

const shellNavItems = [
  ShellNavItem(
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard_rounded,
    label: AppStrings.dashboardTitle,
  ),
  ShellNavItem(
    icon: Icons.local_shipping_outlined,
    selectedIcon: Icons.local_shipping_rounded,
    label: AppStrings.vehiclesTitle,
  ),
  ShellNavItem(
    icon: Icons.map_outlined,
    selectedIcon: Icons.map_rounded,
    label: AppStrings.mapTitle,
  ),
  ShellNavItem(
    icon: Icons.notifications_outlined,
    selectedIcon: Icons.notifications_rounded,
    label: AppStrings.alertsTitle,
    badges: true,
  ),
  ShellNavItem(
    icon: Icons.person_outline,
    selectedIcon: Icons.person_rounded,
    label: AppStrings.profileTitle,
  ),
];
