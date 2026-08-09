import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/failure.dart';
import '../../state/cached.dart';
import 'app_empty_state.dart';
import 'app_error_state.dart';
import 'app_skeleton.dart';
import 'staleness_bar.dart';

/// THE four-state contract every data-bearing screen implements (design
/// §9 / spec UI-1). Resolution order:
///
/// 1. Loading with no previous value -> [AppSkeleton].
/// 2. A [NetworkFailure] with a cached value -> data + [StalenessBar]
///    (offline is a fork of the error state, not a fifth state).
/// 3. Any other error -> [AppErrorState] with retry.
/// 4. Data satisfying [isEmpty] -> [empty] (required, no generic default).
/// 5. Otherwise -> data, plus [StalenessBar] when the value has a
///    `cachedAt`.
class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({
    required this.state,
    required this.isEmpty,
    required this.data,
    required this.empty,
    required this.onRetry,
    super.key,
  });

  final AsyncValue<Cached<T>> state;
  final bool Function(T value) isEmpty;
  final Widget Function(T value, DateTime? cachedAt) data;
  final AppEmptyState empty;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.hasError) {
      final rawError = state.error;
      final failure = rawError is Failure
          ? rawError
          : UnknownFailure(cause: rawError ?? state);
      final previous = state.valueOrNull;
      if (failure is NetworkFailure && previous != null) {
        return _resolveData(previous);
      }
      return AppErrorState(failure: failure, onRetry: onRetry);
    }

    final cached = state.valueOrNull;
    if (cached == null) {
      // Loading (or any other pending state) with nothing to paint yet.
      return const AppSkeleton();
    }
    return _resolveData(cached);
  }

  Widget _resolveData(Cached<T> cached) {
    if (isEmpty(cached.value)) return empty;

    final content = data(cached.value, cached.cachedAt);
    final cachedAt = cached.cachedAt;
    if (cachedAt == null) return content;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StalenessBar(cachedAt: cachedAt),
        Expanded(child: content),
      ],
    );
  }
}
