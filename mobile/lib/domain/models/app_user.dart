import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/time/app_time.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

/// An unrecognized role gets the least privilege — the backend adding a
/// third role must never be silently treated as admin.
@JsonEnum()
enum UserRole {
  @JsonValue('admin')
  admin,
  @JsonValue('user')
  user,
}

/// Mirrors the backend's `UserRead` schema.
@freezed
sealed class AppUser with _$AppUser {
  const factory AppUser({
    required String id,
    required String name,
    required String email,
    @JsonKey(unknownEnumValue: UserRole.user) required UserRole role,
    required bool isActive,
    @JsonKey(fromJson: parseBackendDateTime, toJson: serializeUtc)
    required DateTime createdAt,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);
}
