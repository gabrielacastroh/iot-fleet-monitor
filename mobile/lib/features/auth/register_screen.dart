import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error/failure.dart';
import '../../design_system/components/app_button.dart';
import '../../design_system/components/app_card.dart';
import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_radii.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../../design_system/tokens/app_typography.dart';
import '../../router/routes.dart';
import '../../state/repository_providers.dart';
import '../../state/session_provider.dart';
import 'state/auth_form_provider.dart';

/// AUTH-11: create the account, then immediately run the AUTH-1 login flow
/// with the same credentials — `POST /auth/register` never returns a token.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  Failure? _registerFailure;

  Future<void> _submit() async {
    final formNotifier = ref.read(registerFormProvider.notifier);
    final form = ref.read(registerFormProvider);
    if (!form.isValid || form.isSubmitting) return;

    formNotifier.setSubmitting(true);
    setState(() => _registerFailure = null);

    try {
      await ref
          .read(sessionRepositoryProvider)
          .register(
            name: form.name,
            email: form.email,
            password: form.password,
          );
    } on Failure catch (failure) {
      if (!mounted) return;
      formNotifier.setSubmitting(false);
      setState(() => _registerFailure = failure);
      return;
    }

    if (!mounted) return;
    await ref
        .read(sessionProvider.notifier)
        .login(email: form.email, password: form.password);
    if (!mounted) return;
    formNotifier.setSubmitting(false);

    if (!ref.read(sessionProvider).hasError) {
      context.go(Routes.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(registerFormProvider);
    final formNotifier = ref.read(registerFormProvider.notifier);
    final appColors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: appColors.sidebar,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xxxl),
                Text(
                  'Crear cuenta',
                  style: AppTypography.headlineSmall.copyWith(
                    color: appColors.sidebarForeground,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  lifted: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        key: const Key('register_name_field'),
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        onChanged: formNotifier.setName,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        key: const Key('register_email_field'),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        onChanged: formNotifier.setEmail,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        key: const Key('register_password_field'),
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        onChanged: formNotifier.setPassword,
                        onSubmitted: (_) => _submit(),
                      ),
                      if (_registerFailure != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.destructiveSoft,
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              _registerFailure!.detail ??
                                  'No pudimos crear tu cuenta. Inténtalo de nuevo.',
                              style: AppTypography.bodyMedium.copyWith(
                                color: appColors.onDestructiveSoft,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        label: 'Crear cuenta',
                        isLoading: formState.isSubmitting,
                        // AUTH-5: visually disabled, not just internally
                        // guarded, until all fields are non-empty.
                        onPressed: formState.isValid ? _submit : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextButton(
                  onPressed: () => context.go(Routes.login),
                  child: Text(
                    '¿Ya tienes cuenta? Inicia sesión',
                    style: AppTypography.labelLarge.copyWith(
                      color: appColors.sidebarForeground,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
