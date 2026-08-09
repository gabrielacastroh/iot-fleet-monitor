import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/design_system/tokens/app_durations.dart';

void main() {
  group('AppDurations.of', () {
    testWidgets('returns the base duration when animations are enabled', (
      tester,
    ) async {
      late Duration resolved;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: Builder(
            builder: (context) {
              resolved = AppDurations.of(context, AppDurations.base);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolved, AppDurations.base);
    });

    testWidgets('returns Duration.zero when the OS requests reduced motion', (
      tester,
    ) async {
      late Duration resolved;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              resolved = AppDurations.of(context, AppDurations.base);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolved, Duration.zero);
    });
  });
}
