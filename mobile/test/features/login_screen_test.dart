import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mobile/data/api/auth_interceptor.dart';
import 'package:mobile/data/api/error_interceptor.dart';
import 'package:mobile/design_system/app_theme.dart';
import 'package:mobile/design_system/strings/app_strings.dart';
import 'package:mobile/features/auth/login_screen.dart';
import 'package:mobile/state/api_providers.dart';
import 'package:mobile/state/token_store.dart';

import '../helpers/fake_secure_storage_platform.dart';

const _userJson = {
  'id': 'u1',
  'name': 'Ada Lovelace',
  'email': 'ada@example.com',
  'role': 'user',
  'is_active': true,
  'created_at': '2026-08-07T15:44:54.044240',
};

Future<DioAdapter> _pumpLoginScreen(WidgetTester tester) async {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  final tokenStore = TokenStore();
  dio.interceptors.add(AuthInterceptor(tokenStore));
  dio.interceptors.add(ErrorInterceptor(tokenStore));
  final adapter = DioAdapter(dio: dio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [dioProvider.overrideWithValue(dio)],
      child: MaterialApp(theme: AppTheme.light, home: const LoginScreen()),
    ),
  );
  await tester.pump();
  return adapter;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('login_screen_test');
    Hive.init(tempDir.path);
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  testWidgets('AUTH-5: submit sends no request while the form is invalid', (
    tester,
  ) async {
    final adapter = await _pumpLoginScreen(tester);

    // PART-2's taller card (brand lockup + orbit-arc background) pushes the
    // button below the default 800x600 test viewport fold — scroll it into
    // view first, same as a real user would on a short screen.
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Ingresar'));
    await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
    await tester.pump();

    expect(adapter.history, isEmpty);
  });

  testWidgets(
    'AUTH-2: invalid credentials shows the pinned message and keeps focus on the password field',
    (tester) async {
      final adapter = await _pumpLoginScreen(tester);
      adapter.onPost(
        '/auth/login',
        (server) => server.reply(401, {'detail': 'Credenciales inválidas'}),
        data: Matchers.any,
      );

      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        'ada@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        'wrong-password',
      );
      await tester.pump();

      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Ingresar'));
      await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.invalidCredentialsMessage), findsOneWidget);
      final passwordField = tester.widget<TextField>(
        find.byKey(const Key('login_password_field')),
      );
      expect(passwordField.focusNode?.hasFocus, isTrue);
    },
  );

  testWidgets(
    'AUTH-3: a network failure shows a message distinct from AUTH-2',
    (tester) async {
      final adapter = await _pumpLoginScreen(tester);
      adapter.onPost(
        '/auth/login',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/auth/login'),
            type: DioExceptionType.connectionError,
          ),
        ),
        data: Matchers.any,
      );

      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        'ada@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        'secret',
      );
      await tester.pump();

      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Ingresar'));
      await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.networkErrorMessage), findsOneWidget);
      expect(find.text(AppStrings.invalidCredentialsMessage), findsNothing);
    },
  );

  testWidgets(
    'AUTH-4: the password visibility toggle swaps the semantics label',
    (tester) async {
      await _pumpLoginScreen(tester);

      expect(find.byTooltip(AppStrings.showPasswordLabel), findsOneWidget);

      await tester.tap(find.byTooltip(AppStrings.showPasswordLabel));
      await tester.pump();

      expect(find.byTooltip(AppStrings.hidePasswordLabel), findsOneWidget);
    },
  );

  testWidgets(
    'AUTH-5: the submit button is visually disabled until both fields are filled',
    (tester) async {
      await _pumpLoginScreen(tester);

      var button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Ingresar'),
      );
      expect(button.onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        'ada@example.com',
      );
      await tester.pump();

      button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Ingresar'),
      );
      expect(button.onPressed, isNull, reason: 'password is still empty');

      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        'secret',
      );
      await tester.pump();

      button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Ingresar'),
      );
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets(
    'AUTH-6: a second tap while a request is in flight sends nothing else',
    (tester) async {
      final adapter = await _pumpLoginScreen(tester);
      adapter.onPost(
        '/auth/login',
        (server) => server.reply(200, {
          'access_token': 'a.b.c',
          'token_type': 'bearer',
        }, delay: const Duration(milliseconds: 200)),
        data: Matchers.any,
      );
      adapter.onGet('/auth/me', (server) => server.reply(200, _userJson));

      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        'ada@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        'secret',
      );
      await tester.pump();

      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Ingresar'));
      await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
      await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final loginCalls = adapter.history.where(
        (m) => m.request.route == '/auth/login',
      );
      expect(loginCalls, hasLength(1));
    },
  );
}
