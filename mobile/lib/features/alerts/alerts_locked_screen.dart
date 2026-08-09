import 'package:flutter/material.dart';

import '../../design_system/components/app_empty_state.dart';
import '../../design_system/strings/app_strings.dart';

/// ROLE-2: rendered by the router in place of [AlertsScreen] for a
/// non-admin session — never a redirect (design §7: "a silently hidden
/// destination teaches nothing"). Purely presentational: no provider is
/// watched here, so `GET /alerts` structurally cannot fire from this
/// widget.
class AlertsLockedScreen extends StatelessWidget {
  const AlertsLockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppEmptyState(
      icon: Icons.lock_outline,
      title: AppStrings.alertsAdminOnlyMessage,
      body: AppStrings.alertsAdminOnlyBody,
    );
  }
}
