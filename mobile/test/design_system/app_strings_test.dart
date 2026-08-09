import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/design_system/strings/app_strings.dart';

void main() {
  group('AppStrings.failureMessage', () {
    test('prefers the server detail for ConflictFailure', () {
      const failure = ConflictFailure(
        field: 'email',
        detail: 'Ese email ya está registrado.',
      );

      expect(
        AppStrings.failureMessage(failure),
        'Ese email ya está registrado.',
      );
    });

    test('falls back to canned copy for ConflictFailure with no detail', () {
      const failure = ConflictFailure(field: 'email', detail: null);

      expect(AppStrings.failureMessage(failure), isNotEmpty);
      expect(AppStrings.failureMessage(failure), isNot(contains('null')));
    });

    test('prefers the server detail for ValidationFailure', () {
      const failure = ValidationFailure(
        fieldErrors: {'password': 'field required'},
        detail: 'Revisa los campos.',
      );

      expect(AppStrings.failureMessage(failure), 'Revisa los campos.');
    });

    test('uses canned copy for NetworkFailure regardless of detail', () {
      const failure = NetworkFailure();

      expect(
        AppStrings.failureMessage(failure),
        AppStrings.networkErrorMessage,
      );
    });

    test('uses canned copy for ServerFailure regardless of detail', () {
      const failure = ServerFailure(detail: 'ignored server text');

      expect(AppStrings.failureMessage(failure), AppStrings.serverErrorMessage);
    });

    test('uses canned copy for UnauthorizedFailure', () {
      const failure = UnauthorizedFailure(detail: 'ignored');

      expect(
        AppStrings.failureMessage(failure),
        AppStrings.sessionExpiredMessage,
      );
    });

    test('uses canned copy for ForbiddenFailure', () {
      const failure = ForbiddenFailure();

      expect(AppStrings.failureMessage(failure), AppStrings.forbiddenMessage);
    });
  });
}
