import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/error/failure_mapper.dart';

DioException _badResponse(int statusCode, Object? data) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: options,
      statusCode: statusCode,
      data: data,
    ),
  );
}

void main() {
  group('mapDioExceptionToFailure — detail shapes', () {
    test('string detail on a 401 maps to UnauthorizedFailure carrying it', () {
      final failure = mapDioExceptionToFailure(
        _badResponse(401, {'detail': 'Credenciales inválidas'}),
      );

      expect(failure, isA<UnauthorizedFailure>());
      expect(failure.detail, 'Credenciales inválidas');
    });

    test(
      'dict detail on a 409 maps to ConflictFailure with field + message',
      () {
        final failure = mapDioExceptionToFailure(
          _badResponse(409, {
            'detail': {'field': 'device_code', 'message': 'ya existe'},
          }),
        );

        expect(failure, isA<ConflictFailure>());
        expect((failure as ConflictFailure).field, 'device_code');
        expect(failure.detail, 'ya existe');
      },
    );

    test('422 array detail flattens by the last non-body loc element', () {
      final failure = mapDioExceptionToFailure(
        _badResponse(422, {
          'detail': [
            {
              'loc': ['body', 'password'],
              'msg': 'field required',
              'type': 'missing',
            },
            {
              'loc': ['query', 'limit'],
              'msg': 'must be positive',
              'type': 'value_error',
            },
          ],
        }),
      );

      expect(failure, isA<ValidationFailure>());
      final fieldErrors = (failure as ValidationFailure).fieldErrors;
      expect(fieldErrors['password'], 'field required');
      expect(fieldErrors['limit'], 'must be positive');
    });
  });

  group('mapDioExceptionToFailure — status codes', () {
    test('403 maps to ForbiddenFailure', () {
      expect(
        mapDioExceptionToFailure(_badResponse(403, null)),
        isA<ForbiddenFailure>(),
      );
    });

    test('404 maps to NotFoundFailure', () {
      expect(
        mapDioExceptionToFailure(_badResponse(404, null)),
        isA<NotFoundFailure>(),
      );
    });

    test('500 maps to ServerFailure', () {
      expect(
        mapDioExceptionToFailure(_badResponse(500, null)),
        isA<ServerFailure>(),
      );
    });

    test('an unrecognized 2xx-adjacent status maps to UnknownFailure', () {
      expect(
        mapDioExceptionToFailure(_badResponse(418, null)),
        isA<UnknownFailure>(),
      );
    });
  });

  group('mapDioExceptionToFailure — DioExceptionType', () {
    final options = RequestOptions(path: '/x');

    test('connectionTimeout maps to NetworkFailure', () {
      final exception = DioException(
        requestOptions: options,
        type: DioExceptionType.connectionTimeout,
      );
      expect(mapDioExceptionToFailure(exception), isA<NetworkFailure>());
    });

    test('sendTimeout maps to NetworkFailure', () {
      final exception = DioException(
        requestOptions: options,
        type: DioExceptionType.sendTimeout,
      );
      expect(mapDioExceptionToFailure(exception), isA<NetworkFailure>());
    });

    test('receiveTimeout maps to NetworkFailure', () {
      final exception = DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
      expect(mapDioExceptionToFailure(exception), isA<NetworkFailure>());
    });

    test('connectionError maps to NetworkFailure', () {
      final exception = DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
      expect(mapDioExceptionToFailure(exception), isA<NetworkFailure>());
    });

    test('badCertificate maps to NetworkFailure', () {
      final exception = DioException(
        requestOptions: options,
        type: DioExceptionType.badCertificate,
      );
      expect(mapDioExceptionToFailure(exception), isA<NetworkFailure>());
    });

    test('cancel is rethrown, never surfaced as a Failure', () {
      final exception = DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
      );
      expect(
        () => mapDioExceptionToFailure(exception),
        throwsA(same(exception)),
      );
    });
  });
}
