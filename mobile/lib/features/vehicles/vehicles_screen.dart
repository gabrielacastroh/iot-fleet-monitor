import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design_system/components/app_empty_state.dart';
import '../../design_system/components/two_pane_row.dart';
import '../../design_system/strings/app_strings.dart';
import '../../router/routes.dart';
import 'widgets/vehicles_list_pane.dart';

/// VEH-1..VEH-8: the vehicles list. Below RESP-1's 600dp breakpoint this is
/// a plain [VehiclesListPane] that pushes `/vehicles/:id` on tap. At
/// ≥600dp it becomes the left pane of a list-detail two-pane layout, paired
/// with a "pick a vehicle" placeholder until a selection is pushed (which,
/// on a tablet, shows this same screen underneath — still in two-pane mode
/// — with [VehicleDetailScreen] as the companion detail pane).
class VehiclesScreen extends StatelessWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pane = VehiclesListPane(
          onSelectDevice: (device) =>
              context.push(Routes.vehicleDetail(device.id)),
        );

        if (constraints.maxWidth < tabletBreakpoint) return pane;

        return twoPaneRow(
          list: pane,
          detail: const AppEmptyState(
            icon: Icons.local_shipping_outlined,
            title: AppStrings.vehiclesSelectPromptTitle,
            body: AppStrings.vehiclesSelectPromptBody,
          ),
        );
      },
    );
  }
}
