import 'package:flutter_riverpod/flutter_riverpod.dart';

/// AUTH-5 (non-empty email + password) / AUTH-6 (in-flight guard) for the
/// login form.
class LoginFormState {
  const LoginFormState({
    this.email = '',
    this.password = '',
    this.isSubmitting = false,
  });

  final String email;
  final String password;
  final bool isSubmitting;

  bool get isValid => email.trim().isNotEmpty && password.isNotEmpty;

  LoginFormState copyWith({
    String? email,
    String? password,
    bool? isSubmitting,
  }) {
    return LoginFormState(
      email: email ?? this.email,
      password: password ?? this.password,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class LoginFormNotifier extends AutoDisposeNotifier<LoginFormState> {
  @override
  LoginFormState build() => const LoginFormState();

  void setEmail(String value) => state = state.copyWith(email: value);

  void setPassword(String value) => state = state.copyWith(password: value);

  void setSubmitting(bool value) => state = state.copyWith(isSubmitting: value);
}

final loginFormProvider =
    NotifierProvider.autoDispose<LoginFormNotifier, LoginFormState>(
      LoginFormNotifier.new,
    );

/// The same shape plus `name`, for the registration form.
class RegisterFormState {
  const RegisterFormState({
    this.name = '',
    this.email = '',
    this.password = '',
    this.isSubmitting = false,
  });

  final String name;
  final String email;
  final String password;
  final bool isSubmitting;

  bool get isValid =>
      name.trim().isNotEmpty && email.trim().isNotEmpty && password.isNotEmpty;

  RegisterFormState copyWith({
    String? name,
    String? email,
    String? password,
    bool? isSubmitting,
  }) {
    return RegisterFormState(
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class RegisterFormNotifier extends AutoDisposeNotifier<RegisterFormState> {
  @override
  RegisterFormState build() => const RegisterFormState();

  void setName(String value) => state = state.copyWith(name: value);

  void setEmail(String value) => state = state.copyWith(email: value);

  void setPassword(String value) => state = state.copyWith(password: value);

  void setSubmitting(bool value) => state = state.copyWith(isSubmitting: value);
}

final registerFormProvider =
    NotifierProvider.autoDispose<RegisterFormNotifier, RegisterFormState>(
      RegisterFormNotifier.new,
    );
