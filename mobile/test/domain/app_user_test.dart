import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/models/app_user.dart';

void main() {
  final json = {
    'id': 'u1',
    'name': 'Ada Lovelace',
    'email': 'ada@example.com',
    'role': 'admin',
    'is_active': true,
    'created_at': '2026-08-07T15:44:54.044240',
  };

  test('round trips through JSON', () {
    final user = AppUser.fromJson(json);

    expect(user.id, 'u1');
    expect(user.name, 'Ada Lovelace');
    expect(user.email, 'ada@example.com');
    expect(user.role, UserRole.admin);
    expect(user.isActive, isTrue);
    expect(user.createdAt.isUtc, isTrue);

    final roundTripped = AppUser.fromJson(user.toJson());
    expect(roundTripped, user);
  });

  test('an unrecognized role fails safe to UserRole.user', () {
    final user = AppUser.fromJson({...json, 'role': 'superadmin'});

    expect(user.role, UserRole.user);
  });
}
