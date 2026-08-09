import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/api/alerts_api.dart';
import 'package:mobile/design_system/strings/app_strings.dart';
import 'package:mobile/features/alerts/alerts_locked_screen.dart';
import 'package:mobile/state/api_providers.dart';
import 'package:mocktail/mocktail.dart';

class _MockAlertsApi extends Mock implements AlertsApi {}

void main() {
  testWidgets(
    'ROLE-2: shows the admin-only copy and never calls the alerts endpoint',
    (tester) async {
      final api = _MockAlertsApi();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [alertsApiProvider.overrideWithValue(api)],
          child: const MaterialApp(home: Scaffold(body: AlertsLockedScreen())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.alertsAdminOnlyMessage), findsOneWidget);
      verifyZeroInteractions(api);
    },
  );
}
