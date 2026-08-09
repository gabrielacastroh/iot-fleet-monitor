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
import 'package:mobile/data/local/secure_store.dart';
import 'package:mobile/design_system/app_theme.dart';
import 'package:mobile/features/auth/register_screen.dart';
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

Future<DioAdapter> _pumpRegisterScreen(WidgetTester tester) async {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  final tokenStore = TokenStore();
  dio.interceptors.add(AuthInterceptor(tokenStore));
  dio.interceptors.add(ErrorInterceptor(tokenStore));
  final adapter = DioAdapter(dio: dio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [dioProvider.overrideWithValue(dio)],
      child: MaterialApp(theme: AppTheme.light, home: const RegisterScreen()),
    ),
  );
  await tester.pump();
  return adapter;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('register_screen_test');
    Hive.init(tempDir.path);
    FlutterSecureStoragePlatform.instance = FakeSecureStoragePlatform();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  testWidgets('AUTH-11: success auto-logs in (AUTH-1 flow)', (tester) async {
    final adapter = await _pumpRegisterScreen(tester);
    adapter.onPost(
      '/auth/register',
      (server) => server.reply(200, _userJson),
      data: Matchers.any,
    );
    adapter.onPost(
      '/auth/login',
      (server) =>
          server.reply(200, {'access_token': 'a.b.c', 'token_type': 'bearer'}),
      data: Matchers.any,
    );
    adapter.onGet('/auth/me', (server) => server.reply(200, _userJson));

    await tester.enterText(
      find.byKey(const Key('register_name_field')),
      'Ada Lovelace',
    );
    await tester.enterText(
      find.byKey(const Key('register_email_field')),
      'ada@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('register_password_field')),
      'secret',
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await tester.pumpAndSettle();

    final loginCalls = adapter.history.where(
      (m) => m.request.route == '/auth/login',
    );
    expect(loginCalls, hasLength(1));
    expect(await SecureStore().readToken(), 'a.b.c');
  });

  testWidgets(
    'AUTH-5: the submit button is visually disabled until all fields are filled',
    (tester) async {
      await _pumpRegisterScreen(tester);

      var button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Crear cuenta'),
      );
      expect(button.onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('register_name_field')),
        'Ada Lovelace',
      );
      await tester.enterText(
        find.byKey(const Key('register_email_field')),
        'ada@example.com',
      );
      await tester.pump();

      button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Crear cuenta'),
      );
      expect(button.onPressed, isNull, reason: 'password is still empty');

      await tester.enterText(
        find.byKey(const Key('register_password_field')),
        'secret',
      );
      await tester.pump();

      button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Crear cuenta'),
      );
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets('a 409 shows an inline message and stores no token', (
    tester,
  ) async {
    final adapter = await _pumpRegisterScreen(tester);
    adapter.onPost(
      '/auth/register',
      (server) =>
          server.reply(409, {'detail': 'Ese email ya está registrado.'}),
      data: Matchers.any,
    );

    await tester.enterText(
      find.byKey(const Key('register_name_field')),
      'Ada Lovelace',
    );
    await tester.enterText(
      find.byKey(const Key('register_email_field')),
      'ada@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('register_password_field')),
      'secret',
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('Ese email ya está registrado.'), findsOneWidget);
    final loginCalls = adapter.history.where(
      (m) => m.request.route == '/auth/login',
    );
    expect(loginCalls, isEmpty);
    expect(await SecureStore().readToken(), isNull);
  });
}
