import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/security/jwt_claims.dart';
import 'package:mobile/design_system/app_theme.dart';
import 'package:mobile/design_system/strings/app_strings.dart';
import 'package:mobile/domain/models/app_user.dart';
import 'package:mobile/domain/models/session.dart';
import 'package:mobile/features/profile/profile_screen.dart';
import 'package:mobile/state/config_providers.dart';
import 'package:mobile/state/connectivity_provider.dart';
import 'package:mobile/state/session_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

final _fakePackageInfo = PackageInfo(
  appName: 'IoT Fleet Monitor',
  packageName: 'com.iotfleetmonitor.mobile',
  version: '1.0.0',
  buildNumber: '1',
);

class _MockConnectivity extends Mock implements Connectivity {}

class _FakeSessionNotifier extends SessionNotifier {
  _FakeSessionNotifier(this._session);
  final Session? _session;

  bool loggedOut = false;

  @override
  Future<Session?> build() async => _session;

  @override
  Future<void> forceLogout() async {
    loggedOut = true;
  }
}

Session _session({UserRole role = UserRole.admin}) => Session(
  token: 'token-1',
  user: AppUser(
    id: 'u1',
    name: 'Ada Lovelace',
    email: 'ada@example.com',
    role: role,
    isActive: true,
    createdAt: DateTime.utc(2026),
  ),
  claims: JwtClaims(
    subject: 'u1',
    role: role.name,
    expiresAt: DateTime.utc(2099),
  ),
);

Future<_FakeSessionNotifier> _pump(
  WidgetTester tester, {
  bool online = true,
}) async {
  final notifier = _FakeSessionNotifier(_session());
  final connectivity = _MockConnectivity();
  when(
    () => connectivity.onConnectivityChanged,
  ).thenAnswer((_) => const Stream.empty());
  when(() => connectivity.checkConnectivity()).thenAnswer(
    (_) async => [online ? ConnectivityResult.wifi : ConnectivityResult.none],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith(() => notifier),
        connectivityClientProvider.overrideWithValue(connectivity),
        packageInfoProvider.overrideWith((ref) async => _fakePackageInfo),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: ProfileScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return notifier;
}

void main() {
  testWidgets('PROF-1: shows name, email and role from the cached session', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('ada@example.com'), findsOneWidget);
    expect(find.text(AppStrings.profileRoleAdmin), findsOneWidget);
  });

  testWidgets('PROF-1: no edit affordance is offered anywhere', (tester) async {
    await _pump(tester);

    expect(find.text(AppStrings.profileReadOnlyMessage), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });

  testWidgets(
    'PROF-1: diagnostics show connection status, API base URL and app version',
    (tester) async {
      await _pump(tester, online: false);

      expect(find.text(AppStrings.profileConnectionOffline), findsOneWidget);
      expect(find.textContaining(_fakePackageInfo.version), findsOneWidget);
    },
  );

  testWidgets('PROF-2: the logout button calls forceLogout', (tester) async {
    final notifier = await _pump(tester);

    // The screen scrolls: logout sits below the diagnostics block.
    final logout = find.text(AppStrings.profileLogoutLabel);
    await tester.scrollUntilVisible(logout, 200);
    await tester.tap(logout);
    await tester.pumpAndSettle();

    expect(notifier.loggedOut, isTrue);
  });

  testWidgets('the diagnostics block collapses and expands', (tester) async {
    await _pump(tester);

    expect(find.text(AppStrings.profileVersionLabel), findsOneWidget);

    await tester.tap(find.text(AppStrings.profileDiagnosticsTitle));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.profileVersionLabel), findsNothing);
    // The header stays, so the block is collapsed rather than gone.
    expect(find.text(AppStrings.profileDiagnosticsTitle), findsOneWidget);
  });

  testWidgets('the server row copies the base URL to the clipboard', (
    tester,
  ) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await _pump(tester);

    await tester.tap(find.byTooltip(AppStrings.profileCopyServerLabel));
    await tester.pumpAndSettle();

    expect(copied, hasLength(1));
    expect(copied.single, isNotEmpty);
    expect(find.text(AppStrings.profileServerCopiedMessage), findsOneWidget);
  });
}
