import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error/failure.dart';
import '../../design_system/components/app_button.dart';
import '../../design_system/strings/app_strings.dart';
import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_radii.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../../design_system/tokens/app_typography.dart';
import '../../router/routes.dart';
import '../../state/session_provider.dart';
import 'state/auth_form_provider.dart';

/// `primary` itself is only 2.2:1 on this dark card — below AA for text and
/// below 3:1 for icons. Every blue accent on this screen is therefore
/// `primary` tinted toward `primarySoft`, which lands at 8.3:1 and matches
/// the lighter blue the approved mockup uses for its icons and links.
final _accent = Color.lerp(AppColors.primary, AppColors.primarySoft, 0.45)!;

/// AUTH-1..AUTH-6: the login form, built to the approved mockup — brand
/// lockup over a translucent auth card over the register line, on a navy
/// gradient with ambient orbit arcs.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({this.from, super.key});

  final String? from;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formNotifier = ref.read(loginFormProvider.notifier);
    final form = ref.read(loginFormProvider);
    if (!form.isValid || form.isSubmitting) return;

    formNotifier.setSubmitting(true);
    await ref
        .read(sessionProvider.notifier)
        .login(email: form.email, password: form.password);
    if (!mounted) return;
    formNotifier.setSubmitting(false);

    if (ref.read(sessionProvider).hasError) {
      _passwordFocusNode.requestFocus();
    } else {
      final destination = widget.from ?? Routes.dashboard;
      if (mounted) context.go(destination);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(loginFormProvider);
    final formNotifier = ref.read(loginFormProvider.notifier);
    final sessionState = ref.watch(sessionProvider);
    final appColors = Theme.of(context).extension<AppColors>()!;
    final missingPassword =
        formState.email.isNotEmpty && formState.password.isEmpty;
    final failure = sessionState.hasError
        ? (sessionState.error is Failure
              ? sessionState.error! as Failure
              : UnknownFailure(cause: sessionState.error!))
        : null;

    return Scaffold(
      backgroundColor: appColors.sidebar,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              appColors.sidebar,
              Color.lerp(appColors.sidebar, AppColors.primary, 0.13)!,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _OrbitArcsPainter(color: _accent)),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg + AppSpacing.xs,
                    vertical: AppSpacing.xl,
                  ),
                  child: ConstrainedBox(
                    // Centers the stack on tall screens without trapping it
                    // there: once the keyboard shrinks the viewport the
                    // column overflows and the scroll view takes over.
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - AppSpacing.xl * 2,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Brand(appColors: appColors),
                            const SizedBox(height: AppSpacing.xl),
                            _AuthCard(
                              appColors: appColors,
                              children: [
                                Text(
                                  'Iniciar sesión',
                                  style: AppTypography.titleLarge.copyWith(
                                    color: appColors.sidebarForeground,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs + 2),
                                Text(
                                  // Short enough to hold one line down to a
                                  // 360dp phone. The full "en tiempo real"
                                  // phrasing is already the brand tagline
                                  // three lines above, so the wrap it caused
                                  // bought a repetition.
                                  'Accede al monitoreo de tu flota.',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: appColors.sidebarMuted,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                _FieldLabel('Email', appColors: appColors),
                                const SizedBox(height: AppSpacing.sm),
                                Semantics(
                                  label: 'Email',
                                  child: TextField(
                                    key: const Key('login_email_field'),
                                    autofillHints: const [AutofillHints.email],
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    style: _inputStyle(appColors),
                                    decoration: _fieldDecoration(
                                      hint: 'nombre@empresa.com',
                                      icon: Icons.mail_outlined,
                                      appColors: appColors,
                                    ),
                                    onChanged: formNotifier.setEmail,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                _FieldLabel('Contraseña', appColors: appColors),
                                const SizedBox(height: AppSpacing.sm),
                                Semantics(
                                  label: 'Contraseña',
                                  child: TextField(
                                    key: const Key('login_password_field'),
                                    focusNode: _passwordFocusNode,
                                    obscureText: _obscurePassword,
                                    autofillHints: const [
                                      AutofillHints.password,
                                    ],
                                    textInputAction: TextInputAction.done,
                                    style: _inputStyle(appColors),
                                    decoration: _fieldDecoration(
                                      hint: '••••••••',
                                      icon: Icons.lock_outlined,
                                      appColors: appColors,
                                      hasError: missingPassword,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          size: 18,
                                        ),
                                        color: _accent,
                                        padding: EdgeInsets.zero,
                                        tooltip: _obscurePassword
                                            ? AppStrings.showPasswordLabel
                                            : AppStrings.hidePasswordLabel,
                                        onPressed: () => setState(
                                          () => _obscurePassword =
                                              !_obscurePassword,
                                        ),
                                      ),
                                    ),
                                    onChanged: formNotifier.setPassword,
                                    onSubmitted: (_) => _submit(),
                                  ),
                                ),
                                if (missingPassword) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    'Ingresa tu contraseña.',
                                    // The field's red outline carries the
                                    // alarm; this line only has to stay
                                    // readable, and `destructive` itself is
                                    // 4.4:1 on the card.
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.destructiveSoft,
                                    ),
                                  ),
                                ],
                                if (failure != null) ...[
                                  const SizedBox(height: AppSpacing.md),
                                  Container(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.md,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.destructiveSoft,
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.lg,
                                      ),
                                    ),
                                    child: Semantics(
                                      liveRegion: true,
                                      child: Text(
                                        _loginErrorMessage(failure),
                                        style: AppTypography.bodySmall.copyWith(
                                          color: appColors.onDestructiveSoft,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: AppSpacing.xl),
                                _SubmitButton(
                                  isEnabled: formState.isValid,
                                  isLoading: formState.isSubmitting,
                                  onPressed: _submit,
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                _SecurityNote(appColors: appColors),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            Center(
                              child: TextButton(
                                onPressed: () => context.go(Routes.register),
                                child: Text.rich(
                                  TextSpan(
                                    text: '¿No tienes cuenta? ',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: appColors.sidebarMuted,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'Regístrate',
                                        style: AppTypography.bodySmall.copyWith(
                                          color: _accent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

TextStyle _inputStyle(AppColors appColors) =>
    AppTypography.bodyMedium.copyWith(color: appColors.sidebarForeground);

/// Fields read as outlines, not as filled blocks: the fill is barely a step
/// off the card and the hairline edge does the work, so the only saturated
/// outline on the screen belongs to the field that has focus.
InputDecoration _fieldDecoration({
  required String hint,
  required IconData icon,
  required AppColors appColors,
  Widget? suffixIcon,
  bool hasError = false,
}) {
  OutlineInputBorder outline(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadii.lg),
    borderSide: BorderSide(color: color, width: width),
  );

  final idle = hasError
      ? AppColors.destructive.withValues(alpha: 0.75)
      : appColors.sidebarForeground.withValues(alpha: 0.12);

  return InputDecoration(
    hintText: hint,
    hintStyle: AppTypography.bodyMedium.copyWith(color: appColors.sidebarMuted),
    filled: true,
    fillColor: appColors.sidebar.withValues(alpha: 0.35),
    isDense: true,
    prefixIcon: Icon(icon, size: 18, color: _accent),
    // minHeight drives the field's overall height: 48 is the A11Y-1 minimum
    // tap target (accessibility_test.dart asserts it), not a visual choice.
    prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 48),
    suffixIcon: suffixIcon,
    suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    contentPadding: const EdgeInsets.symmetric(
      vertical: AppSpacing.md,
      horizontal: AppSpacing.md,
    ),
    border: outline(idle, 1),
    enabledBorder: outline(idle, 1),
    focusedBorder: outline(_accent, 1.5),
  );
}

/// AUTH-2 vs AUTH-3: on `/auth/login` a 401 always means wrong credentials
/// (there is no prior session to expire), so this deliberately does not
/// reuse [AppStrings.failureMessage] — that mapper's `UnauthorizedFailure`
/// case is scoped to a mid-session 401 (AUTH-9), a different user-facing
/// meaning from the same [Failure] subtype here.
String _loginErrorMessage(Failure failure) {
  if (failure is UnauthorizedFailure) {
    return AppStrings.invalidCredentialsMessage;
  }
  return AppStrings.networkErrorMessage;
}

/// Three orbit arcs sweeping out of the top-right corner with a few tracked
/// points on them — the fleet-tracking motif the mockup uses to keep the
/// background from reading as an empty rectangle. Deliberately near the
/// noise floor: at 10% it registers as texture, not as content.
class _OrbitArcsPainter extends CustomPainter {
  const _OrbitArcsPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width * 1.02, -size.height * 0.04);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: 0.10);
    final dot = Paint()..color = color.withValues(alpha: 0.35);

    for (final factor in [0.42, 0.62, 0.86]) {
      canvas.drawCircle(origin, size.width * factor, stroke);
    }
    for (final offset in [
      Offset(size.width * 0.62, size.height * 0.12),
      Offset(size.width * 0.78, size.height * 0.14),
      Offset(size.width * 0.84, size.height * 0.24),
    ]) {
      canvas.drawCircle(offset, 2, dot);
    }
  }

  @override
  bool shouldRepaint(_OrbitArcsPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Translucent rather than opaque so the background gradient and arcs stay
/// visible through it — that is what keeps the card from reading as a plain
/// grey box dropped on a photo.
class _AuthCard extends StatelessWidget {
  const _AuthCard({required this.appColors, required this.children});

  final AppColors appColors;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg + AppSpacing.xs),
      decoration: BoxDecoration(
        color: appColors.sidebarActive.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        border: Border.all(
          color: appColors.sidebarForeground.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            offset: const Offset(0, 12),
            blurRadius: 32,
            spreadRadius: -14,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {required this.appColors});

  final String text;
  final AppColors appColors;

  @override
  Widget build(BuildContext context) {
    // ExcludeSemantics: the label is repeated onto the field itself, so
    // leaving it in the tree would make a screen reader announce it twice.
    return ExcludeSemantics(
      child: Text(
        text,
        style: AppTypography.bodySmall.copyWith(
          fontWeight: FontWeight.w500,
          color: appColors.sidebarForeground.withValues(alpha: 0.92),
        ),
      ),
    );
  }
}

/// The reassurance line under the CTA, rules and all.
class _SecurityNote extends StatelessWidget {
  const _SecurityNote({required this.appColors});

  final AppColors appColors;

  @override
  Widget build(BuildContext context) {
    // Fixed width, deliberately not `Expanded`: three flex children at flex
    // 1 split the row in thirds, which left the label a third of the width
    // and clipped it to "Tu infor…". The rules are decoration, so they take
    // a fixed sliver and the label keeps everything else.
    final rule = SizedBox(
      width: 24,
      child: Divider(
        color: appColors.sidebarForeground.withValues(alpha: 0.1),
        height: 1,
      ),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        rule,
        // `Flexible` (not a rigid `Padding`) so this middle block is a flex
        // participant in the outer row and can shrink under the test font,
        // a narrow phone, or 2.0x text scale — otherwise a non-flex child
        // of a `Row` measures itself at its unbounded natural width first,
        // which is exactly what overflowed here (SAFE-1/PART-2 regression).
        Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user_outlined, size: 14, color: _accent),
                const SizedBox(width: AppSpacing.xs + 2),
                Flexible(
                  // No ellipsis: at a large text scale this should wrap to a
                  // second line rather than hide the sentence behind "…".
                  child: Text(
                    'Tu información está protegida',
                    textAlign: TextAlign.center,
                    style: AppTypography.labelSmall.copyWith(
                      color: appColors.sidebarMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        rule,
      ],
    );
  }
}

/// AUTH-5's disabled state has to stay legible: `FilledButton`'s default
/// disabled fill is `onSurface` at 12%, which on this dark card is all but
/// invisible. The gradient is painted by the wrapper and the button itself
/// is transparent, so the disabled state dims the gradient instead of
/// replacing it.
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.isEnabled,
    required this.isLoading,
    required this.onPressed,
  });

  final bool isEnabled;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isLive = isEnabled && !isLoading;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppColors.primary,
            Color.lerp(AppColors.primary, AppColors.primarySoft, 0.22)!,
          ],
        ),
        boxShadow: isLive
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.45),
                  offset: const Offset(0, 8),
                  blurRadius: 24,
                  spreadRadius: -6,
                ),
              ]
            : null,
      ),
      child: Opacity(
        // Dimmed, not greyed: the CTA stays the brightest thing in the card
        // even while it is unavailable (AUTH-5).
        opacity: isEnabled ? 1 : 0.55,
        child: Theme(
          data: Theme.of(context).copyWith(
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                foregroundColor: AppColors.primaryForeground,
                disabledForegroundColor: AppColors.primaryForeground,
                shadowColor: Colors.transparent,
                textStyle: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // The spinner sits on the blue fill, not on the app surface.
            progressIndicatorTheme: const ProgressIndicatorThemeData(
              color: AppColors.primaryForeground,
            ),
          ),
          child: SizedBox(
            height: 50,
            child: AppButton(
              label: 'Ingresar',
              isLoading: isLoading,
              // Matches the field radius so the CTA belongs to the same form.
              borderRadius: AppRadii.lg,
              trailing: const Icon(Icons.arrow_forward, size: 18),
              // AUTH-5: visually disabled, not just internally guarded,
              // until both fields are non-empty.
              onPressed: isEnabled ? onPressed : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.appColors});

  final AppColors appColors;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.xl),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(AppColors.primary, AppColors.primarySoft, 0.18)!,
                AppColors.primary,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.45),
                offset: const Offset(0, 10),
                blurRadius: 36,
                spreadRadius: -4,
              ),
            ],
          ),
          child: const Icon(
            Icons.satellite_alt_outlined,
            color: AppColors.primaryForeground,
            size: 32,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'IoT Fleet Monitor',
          style: AppTypography.titleLarge.copyWith(
            color: appColors.sidebarForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Monitoreo de flota en tiempo real',
          style: AppTypography.bodySmall.copyWith(
            color: appColors.sidebarMuted,
          ),
        ),
      ],
    );
  }
}
