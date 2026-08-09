import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/strings/app_strings.dart';
import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_radii.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../../design_system/tokens/app_typography.dart';
import '../../state/session_provider.dart';
import 'widgets/diagnostics_card.dart';
import 'widgets/profile_header_card.dart';

/// PROF-1/PROF-2: read-only profile (name/email/role from the cached
/// `GET /auth/me`) + diagnostics + logout. There is deliberately no edit
/// affordance anywhere — no `PATCH /auth/me` exists for this screen to call
/// (design §13), so the permissions row states it plainly rather than
/// showing a disabled control that implies otherwise.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  /// The content stays a column of cards on a tablet instead of stretching
  /// a 900dp-wide avatar row across the pane.
  static const _maxContentWidth = 640.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).valueOrNull?.user;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxxl,
          ),
          children: [
            Text(AppStrings.profileTitle, style: AppTypography.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              AppStrings.profileSubtitle,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (user != null) ...[
              ProfileHeaderCard(user: user),
              const SizedBox(height: AppSpacing.xxl),
            ],
            const DiagnosticsCard(),
            const SizedBox(height: AppSpacing.xxl),
            _LogoutButton(
              onPressed: () => ref.read(sessionProvider.notifier).forceLogout(),
            ),
          ],
        ),
      ),
    );
  }
}

/// PROF-2's logout, in the destructive tone the mockup gives it: a tinted
/// surface rather than the primary fill, because ending the session is the
/// one irreversible thing this screen can do — it should not look like the
/// screen's main call to action.
class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.destructiveSoft,
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: Container(
          // A11Y-1: a full-width 56dp target.
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(
              color: AppColors.destructive.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.logout,
                size: 20,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  AppStrings.profileLogoutLabel,
                  style: AppTypography.labelLarge.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
