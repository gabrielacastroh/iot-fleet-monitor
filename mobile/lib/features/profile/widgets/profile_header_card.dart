import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/components/app_card.dart';
import '../../../design_system/strings/app_strings.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../domain/models/app_user.dart';
import '../../../state/connectivity_provider.dart';

/// PROF-1's identity block: who is signed in, with what role, and — since
/// this screen exists partly to answer "why can't I change anything?" — the
/// read-only permission line right under it, inside the same card.
///
/// The dot on the avatar is the live connection state (OFF-1/OFF-2), not a
/// decorative "online" badge: this app has no presence concept, and the
/// diagnostics block below says the same thing in words.
class ProfileHeaderCard extends ConsumerWidget {
  const ProfileHeaderCard({required this.user, super.key});

  final AppUser user;

  /// Below this the identity column and the role shield can't share a row
  /// without the name clipping.
  static const _shieldMinWidth = 320.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isOnline = ref.watch(connectivityProvider);
    final isAdmin = user.role == UserRole.admin;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadii.xl),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  _Avatar(isOnline: isOnline, colors: colors),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: _Identity(user: user, isAdmin: isAdmin)),
                  if (isAdmin && constraints.maxWidth >= _shieldMinWidth) ...[
                    const SizedBox(width: AppSpacing.md),
                    const _AdminShield(),
                  ],
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: _PermissionsRow(),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.isOnline, required this.colors});

  final bool isOnline;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isOnline
          ? AppStrings.profileConnectionOnline
          : AppStrings.profileConnectionOffline,
      child: ExcludeSemantics(
        child: SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.card,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline,
                  size: 34,
                  color: AppColors.primary,
                ),
              ),
              Positioned(
                right: 2,
                bottom: 6,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    // A11Y-5: the same state is spelled out in the
                    // diagnostics block, so the dot is never the only
                    // channel.
                    color: isOnline
                        ? colors.success
                        : AppColors.mutedForeground,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.card, width: 2.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.user, required this.isAdmin});

  final AppUser user;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          user.name,
          style: AppTypography.titleLarge,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          user.email,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.mutedForeground,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.sm),
        _RoleChip(isAdmin: isAdmin),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.xxl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAdmin ? Icons.verified_user_outlined : Icons.person_outline,
            size: 14,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              isAdmin
                  ? AppStrings.profileRoleAdmin
                  : AppStrings.profileRoleUser,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// The mockup's shield tile. Decorative reinforcement of the role chip
/// beside it — not a control, because there is nothing on this screen an
/// admin can act on (design §13: the profile is read-only).
class _AdminShield extends StatelessWidget {
  const _AdminShield();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppStrings.profileAdminBadgeLabel,
      child: ExcludeSemantics(
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: const Icon(
            Icons.shield_outlined,
            size: 22,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// PROF-1's read-only statement. Deliberately not a tappable row with a
/// chevron like the mockup's: there is no permissions screen behind it, and
/// an affordance that leads nowhere is worse than none.
class _PermissionsRow extends StatelessWidget {
  const _PermissionsRow();

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: const Icon(
              Icons.lock_outline,
              size: 20,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppStrings.profilePermissionsLabel,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                Text(
                  AppStrings.profileReadOnlyTitle,
                  style: AppTypography.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppStrings.profileReadOnlyMessage,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
