import 'package:dio/dio.dart';

import '../../core/error/failure.dart';
import '../../domain/models/app_user.dart';

/// `/auth/login`, `/auth/register`, `/auth/me` — every method returns a
/// model or throws a [Failure], never a [DioException] (design §3.3).
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  /// `POST /auth/login` is `OAuth2PasswordRequestForm`: form-urlencoded
  /// fields `username`/`password`, NOT JSON — a JSON body returns 422
  /// (design §3.2, the known trap). `username` is the email.
  Future<String> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: <String, String>{'username': email, 'password': password},
        // AuthInterceptor exempts this path by name, so no bearer token is
        // ever attached here regardless of session state.
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      return response.data!['access_token']! as String;
    } on DioException catch (e) {
      throw _asFailure(e);
    }
  }

  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: <String, dynamic>{
          'name': name,
          'email': email,
          'password': password,
        },
      );
      return AppUser.fromJson(response.data!);
    } on DioException catch (e) {
      throw _asFailure(e);
    }
  }

  Future<AppUser> me() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/auth/me');
      return AppUser.fromJson(response.data!);
    } on DioException catch (e) {
      throw _asFailure(e);
    }
  }
}

Failure _asFailure(DioException exception) => exception.error is Failure
    ? exception.error as Failure
    : UnknownFailure(cause: exception);
