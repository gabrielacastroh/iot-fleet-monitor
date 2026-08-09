import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/components/app_card.dart';
import '../../../design_system/strings/app_strings.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_durations.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../data/realtime/telemetry_socket.dart' show WsConnectionState;
import '../../../state/config_providers.dart';
import '../../../state/connectivity_provider.dart';
import '../../../state/realtime_provider.dart';

/// PROF-1's diagnostics block: connection status (OFF-1/OFF-2), the
/// effective API base URL, and the app version — the only "technical"
/// information a read-only profile screen has to show.
///
/// Collapsible, because this is support material: it is what you read out
/// when something is wrong, not what you open the profile for. The server
/// row can be copied, which is the one action anyone actually performs
/// here (pasting the base URL into a bug report).
class DiagnosticsCard extends ConsumerStatefulWidget {
  const DiagnosticsCard({super.key});

  @override
  ConsumerState<DiagnosticsCard> createState() => _DiagnosticsCardState();
}

class _DiagnosticsCardState extends ConsumerState<DiagnosticsCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isOnline = ref.watch(connectivityProvider);
    final wsState = ref.watch(wsConnectionStateProvider);
    final config = ref.watch(appConfigProvider);
    final packageInfoAsync = ref.watch(packageInfoProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          isExpanded: _isExpanded,
          onToggle: () => setState(() => _isExpanded = !_isExpanded),
        ),
        AnimatedSize(
          duration: AppDurations.of(context, AppDurations.base),
          curve: AppDurations.enterCurve,
          alignment: Alignment.topCenter,
          child: _isExpanded
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Column(
                      children: [
                        _DiagnosticsRow(
                          // A11Y-5: connectivity is never color-only — the
                          // icon and the label both say it, same as
                          // OfflineBanner.
                          icon: isOnline
                              ? Icons.cloud_done_outlined
                              : Icons.cloud_off,
                          tint: isOnline
                              ? colors.onSuccessSoft
                              : AppColors.mutedForeground,
                          tintSurface: isOnline
                              ? colors.successSoft
                              : AppColors.secondary,
                          label: AppStrings.profileConnectionLabel,
                          value: isOnline
                              ? AppStrings.profileConnectionOnline
                              : AppStrings.profileConnectionOffline,
                          valueColor: isOnline ? colors.onSuccessSoft : null,
                        ),
                        const _RowDivider(),
                        _DiagnosticsRow(
                          // A11Y-5: same rule as the row above — icon +
                          // label, never color-only. A second, distinct
                          // signal from device connectivity: the real
                          // WebSocket lifecycle (WS-1..WS-9), not just
                          // whether the phone has a network path.
                          icon: _wsStateIcon(wsState),
                          tint: _wsStateTint(wsState, colors),
                          tintSurface: _wsStateTintSurface(wsState, colors),
                          label: AppStrings.profileWsConnectionLabel,
                          value: _wsStateLabel(wsState),
                          valueColor: wsState == WsConnectionState.open
                              ? colors.onSuccessSoft
                              : null,
                        ),
                        const _RowDivider(),
                        _DiagnosticsRow(
                          icon: Icons.dns_outlined,
                          tint: AppColors.primary,
                          tintSurface: AppColors.primarySoft,
                          label: AppStrings.profileServerLabel,
                          value: config.apiBaseUrl,
                          onCopy: () => _copyServerUrl(config.apiBaseUrl),
                        ),
                        const _RowDivider(),
                        _DiagnosticsRow(
                          icon: Icons.info_outline,
                          tint: AppColors.primary,
                          tintSurface: AppColors.primarySoft,
                          label: AppStrings.profileVersionLabel,
                          value: packageInfoAsync.when(
                            data: (info) => AppStrings.profileAppVersion(
                              info.version,
                              info.buildNumber,
                            ),
                            loading: () => AppStrings.kpiNoDataValue,
                            error: (_, _) => AppStrings.kpiNoDataValue,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Future<void> _copyServerUrl(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.profileServerCopiedMessage)),
    );
  }
}

/// Three visual buckets for four [WsConnectionState] values: `connecting`
/// and `reconnecting` share the neutral/in-progress treatment (the label
/// text below is what tells them apart) — only `open` (success) and
/// `closed` (muted/error) get their own icon+tint.
IconData _wsStateIcon(WsConnectionState state) => switch (state) {
  WsConnectionState.open => Icons.cloud_done_outlined,
  WsConnectionState.connecting || WsConnectionState.reconnecting => Icons.sync,
  WsConnectionState.closed => Icons.cloud_off,
};

Color _wsStateTint(WsConnectionState state, AppColors colors) =>
    switch (state) {
      WsConnectionState.open => colors.onSuccessSoft,
      WsConnectionState.connecting ||
      WsConnectionState.reconnecting => colors.onWarningSoft,
      WsConnectionState.closed => AppColors.mutedForeground,
    };

Color _wsStateTintSurface(WsConnectionState state, AppColors colors) =>
    switch (state) {
      WsConnectionState.open => colors.successSoft,
      WsConnectionState.connecting ||
      WsConnectionState.reconnecting => colors.warningSoft,
      WsConnectionState.closed => AppColors.secondary,
    };

String _wsStateLabel(WsConnectionState state) => switch (state) {
  WsConnectionState.open => AppStrings.profileWsConnectionOpen,
  WsConnectionState.connecting => AppStrings.profileWsConnectionConnecting,
  WsConnectionState.reconnecting =>
    AppStrings.profileWsConnectionReconnecting,
  WsConnectionState.closed => AppStrings.profileWsConnectionClosed,
};

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.isExpanded, required this.onToggle});

  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      expanded: isExpanded,
      label: isExpanded
          ? AppStrings.profileDiagnosticsCollapseLabel
          : AppStrings.profileDiagnosticsExpandLabel,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Padding(
            // A11Y-1: the row is the target, not just the chevron.
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                const Icon(
                  Icons.monitor_heart_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    AppStrings.profileDiagnosticsTitle,
                    style: AppTypography.titleMedium,
                  ),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: AppDurations.of(context, AppDurations.fast),
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: AppSpacing.lg,
      endIndent: AppSpacing.lg,
      color: AppColors.border,
    );
  }
}

class _DiagnosticsRow extends StatelessWidget {
  const _DiagnosticsRow({
    required this.icon,
    required this.tint,
    required this.tintSurface,
    required this.label,
    required this.value,
    this.valueColor,
    this.onCopy,
  });

  final IconData icon;
  final Color tint;
  final Color tintSurface;
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tintSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: tint),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppTypography.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    value,
                    style: AppTypography.bodySmall.copyWith(
                      color: valueColor ?? AppColors.mutedForeground,
                      fontWeight: valueColor == null
                          ? FontWeight.w400
                          : FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onCopy != null)
              IconButton(
                onPressed: onCopy,
                tooltip: AppStrings.profileCopyServerLabel,
                icon: const Icon(
                  Icons.copy_rounded,
                  size: 18,
                  color: AppColors.mutedForeground,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
