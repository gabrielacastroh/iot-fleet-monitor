import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/design_system/app_theme.dart';
import 'package:mobile/design_system/components/offline_banner.dart';

void main() {
  testWidgets(
    'OfflineBanner shows the persistent "Sin conexión" copy with a live region',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: OfflineBanner()),
        ),
      );

      expect(find.text('Sin conexión'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);

      final semantics = tester.getSemantics(find.byType(OfflineBanner));
      expect(semantics.flagsCollection.isLiveRegion, isTrue);
    },
  );
}
