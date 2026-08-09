import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/error/failure.dart';
import '../state/cached.dart';
import 'components/app_button.dart';
import 'components/app_card.dart';
import 'components/app_empty_state.dart';
import 'components/async_state_view.dart';
import 'components/offline_banner.dart';
import 'components/section_header.dart';
import 'tokens/app_colors.dart';
import 'tokens/app_spacing.dart';
import 'tokens/app_typography.dart';

/// Temporary component-gallery route satisfying the slice-0 checkpoint:
/// the app runs and shows tokens + the four-state contract + buttons/cards.
/// Removed/replaced once the router lands in slice 1.
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Component gallery')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const OfflineBanner(),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'TIPOGRAFÍA'),
          const SizedBox(height: AppSpacing.sm),
          Text('Headline', style: AppTypography.headlineSmall),
          Text('Title', style: AppTypography.titleLarge),
          Text('Body', style: AppTypography.bodyLarge),
          Text(
            '1234.56',
            style: AppTypography.dataLarge.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'BOTONES Y TARJETAS'),
          const SizedBox(height: AppSpacing.sm),
          AppButton(label: 'Acción primaria', onPressed: () {}),
          const SizedBox(height: AppSpacing.md),
          const AppCard(child: Text('Contenido de tarjeta')),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'ESTADOS (AsyncStateView)'),
          const SizedBox(height: AppSpacing.sm),
          const SizedBox(
            height: 140,
            child: AsyncStateView<int>(
              state: AsyncLoading(),
              isEmpty: _isZero,
              data: _dataText,
              empty: AppEmptyState(
                icon: Icons.inbox,
                title: 'Vacío',
                body: 'Sin elementos.',
              ),
              onRetry: _noop,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 140,
            child: AsyncStateView<int>(
              state: const AsyncValue<Cached<int>>.error(
                ServerFailure(),
                StackTrace.empty,
              ),
              isEmpty: _isZero,
              data: _dataText,
              empty: const AppEmptyState(
                icon: Icons.inbox,
                title: 'Vacío',
                body: 'Sin elementos.',
              ),
              onRetry: () {},
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const SizedBox(
            height: 140,
            child: AsyncStateView<int>(
              state: AsyncValue<Cached<int>>.data(Cached(0)),
              isEmpty: _isZero,
              data: _dataText,
              empty: AppEmptyState(
                icon: Icons.inbox,
                title: 'Vacío',
                body: 'Sin elementos.',
              ),
              onRetry: _noop,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const SizedBox(
            height: 140,
            child: AsyncStateView<int>(
              state: AsyncValue<Cached<int>>.data(Cached(42)),
              isEmpty: _isZero,
              data: _dataText,
              empty: AppEmptyState(
                icon: Icons.inbox,
                title: 'Vacío',
                body: 'Sin elementos.',
              ),
              onRetry: _noop,
            ),
          ),
        ],
      ),
    );
  }
}

bool _isZero(int value) => value == 0;

Widget _dataText(int value, DateTime? cachedAt) => Text('Valor: $value');

void _noop() {}
