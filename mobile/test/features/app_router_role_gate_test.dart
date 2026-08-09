import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/data/repositories/alert_repository.dart';
import 'package:mobile/design_system/app_theme.dart';
import 'package:mobile/design_system/strings/app_strings.dart';
import 'package:mobile/features/alerts/alerts_screen.dart';
import 'package:mobile/state/repository_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_viewport.dart';

class _MockAlertRepository extends Mock implements AlertRepository {}

void main() {
  testWidgets(
    'ROLE-4: an unexpected 403 renders the inline error state, never an unhandled exception',
    (tester) async {
      pinPhoneViewport(tester);
      final repository = _MockAlertRepository();
      when(() => repository.peekCache()).thenReturn(null);
      when(
        () => repository.fetchAndCache(),
      ).thenThrow(const ForbiddenFailure());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            alertRepositoryProvider.overrideWith((ref) async => repository),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: AlertsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.forbiddenMessage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
