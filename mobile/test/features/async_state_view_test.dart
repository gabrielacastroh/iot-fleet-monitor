import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/design_system/app_theme.dart';
import 'package:mobile/design_system/components/app_empty_state.dart';
import 'package:mobile/design_system/components/app_error_state.dart';
import 'package:mobile/design_system/components/app_skeleton.dart';
import 'package:mobile/design_system/components/async_state_view.dart';
import 'package:mobile/design_system/components/staleness_bar.dart';
import 'package:mobile/state/cached.dart';

Widget _harness(AsyncStateView<int> child) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    ),
  );
}

AsyncStateView<int> _view({
  required AsyncValue<Cached<int>> state,
  bool Function(int)? isEmpty,
  VoidCallback? onRetry,
}) {
  return AsyncStateView<int>(
    state: state,
    isEmpty: isEmpty ?? (value) => value == 0,
    data: (value, cachedAt) => Text('value: $value'),
    empty: const AppEmptyState(
      icon: Icons.inbox,
      title: 'Nada por aquí',
      body: 'Sin elementos.',
    ),
    onRetry: onRetry ?? () {},
  );
}

void main() {
  group('AsyncStateView resolution order (design §9)', () {
    testWidgets('1. loading with no previous value renders AppSkeleton', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(_view(state: const AsyncLoading())));

      expect(find.byType(AppSkeleton), findsOneWidget);
    });

    testWidgets(
      '2. NetworkFailure with a cached value renders data + StalenessBar (offline fork)',
      (tester) async {
        final cachedAt = DateTime.now().toUtc().subtract(
          const Duration(minutes: 10),
        );
        final previous = AsyncValue<Cached<int>>.data(
          Cached(7, cachedAt: cachedAt),
        );
        final errored = const AsyncValue<Cached<int>>.error(
          NetworkFailure(),
          StackTrace.empty,
        ).copyWithPrevious(previous);

        await tester.pumpWidget(_harness(_view(state: errored)));

        expect(find.text('value: 7'), findsOneWidget);
        expect(find.byType(StalenessBar), findsOneWidget);
        expect(find.byType(AppErrorState), findsNothing);
      },
    );

    testWidgets(
      '3. any other error renders AppErrorState with a working retry',
      (tester) async {
        var retried = false;
        final errored = const AsyncValue<Cached<int>>.error(
          ServerFailure(),
          StackTrace.empty,
        );

        await tester.pumpWidget(
          _harness(_view(state: errored, onRetry: () => retried = true)),
        );

        expect(find.byType(AppErrorState), findsOneWidget);
        await tester.tap(find.text('Reintentar'));
        expect(retried, isTrue);
      },
    );

    testWidgets('4. data satisfying isEmpty renders the required empty state', (
      tester,
    ) async {
      final state = AsyncValue<Cached<int>>.data(const Cached(0));

      await tester.pumpWidget(_harness(_view(state: state)));

      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(find.text('Nada por aquí'), findsOneWidget);
    });

    testWidgets('5. non-empty fresh data renders data with no StalenessBar', (
      tester,
    ) async {
      final state = AsyncValue<Cached<int>>.data(const Cached(3));

      await tester.pumpWidget(_harness(_view(state: state)));

      expect(find.text('value: 3'), findsOneWidget);
      expect(find.byType(StalenessBar), findsNothing);
    });

    testWidgets(
      '5b. non-empty data with a cachedAt renders data + StalenessBar',
      (tester) async {
        final cachedAt = DateTime.now().toUtc().subtract(
          const Duration(minutes: 2),
        );
        final state = AsyncValue<Cached<int>>.data(
          Cached(3, cachedAt: cachedAt),
        );

        await tester.pumpWidget(_harness(_view(state: state)));

        expect(find.text('value: 3'), findsOneWidget);
        expect(find.byType(StalenessBar), findsOneWidget);
      },
    );
  });
}
