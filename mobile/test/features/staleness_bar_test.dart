import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/design_system/app_theme.dart';
import 'package:mobile/design_system/components/staleness_bar.dart';

void main() {
  testWidgets('StalenessBar shows OFF-4 copy with the computed timeAgo', (
    tester,
  ) async {
    final cachedAt = DateTime.now().toUtc().subtract(
      const Duration(minutes: 5),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: StalenessBar(cachedAt: cachedAt)),
      ),
    );

    expect(find.textContaining('Sin conexión · datos de hace'), findsOneWidget);
    expect(find.textContaining('5 min'), findsOneWidget);
  });
}
