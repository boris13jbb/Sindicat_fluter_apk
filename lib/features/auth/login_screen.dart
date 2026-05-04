import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/design/widgets/premium_card.dart';
import '../../core/design/widgets/primary_button.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  final _resetEmailController = TextEditingController();

  bool _isValidEmail(String email) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
  }

  InputDecoration _fieldDecoration({
    required String label,
    Widget? suffixIcon,
    Widget? prefixIcon,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDesignTokens.radiusMedium),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );
    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusMedium),
        borderSide: const BorderSide(color: AppDesignTokens.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusMedium),
        borderSide: BorderSide(color: Colors.red.shade300),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusMedium),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
      ),
      labelStyle: TextStyle(
        color: AppDesignTokens.primaryDark.withValues(alpha: 0.55),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _resetEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (_, auth, __) {
        if (auth.isSignedIn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/home', (r) => false);
            }
          });
        }
        return _buildBody(context);
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      resizeToAvoidBottomInset: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final headerH = (constraints.maxHeight * 0.34).clamp(200.0, 280.0);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: headerH,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: AppDesignTokens.primary,
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(28),
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDesignTokens.horizontalPadding,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const _LoginHeaderLogo(),
                              const SizedBox(height: 18),
                              Text(
                                'Sistema Integrado Sindicato',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ColoredBox(color: AppDesignTokens.background),
                  ),
                ],
              ),
              SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppDesignTokens.horizontalPadding,
                  headerH - 56,
                  AppDesignTokens.horizontalPadding,
                  24 + bottomInset,
                ),
                physics: const BouncingScrollPhysics(),
                child: PremiumCard(
                  margin: EdgeInsets.zero,
                  borderRadius: 28,
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Iniciar sesión',
                          style: AppDesignTokens.titleLarge(context).copyWith(
                            fontSize: 24,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Accede de forma segura a tu panel sindical.',
                          style: AppDesignTokens.bodyMuted(context).copyWith(
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _emailController,
                          decoration: _fieldDecoration(
                            label: 'Correo electrónico',
                            prefixIcon: const Icon(
                              Icons.mail_outline_rounded,
                              color: AppDesignTokens.primary,
                            ),
                            suffixIcon: const Icon(
                              Icons.alternate_email_rounded,
                              color: AppDesignTokens.primary,
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            final email = v?.trim() ?? '';
                            if (email.isEmpty) return 'Ingresa tu email';
                            if (!_isValidEmail(email)) {
                              return 'Ingresa un email válido';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) =>
                              FocusScope.of(context).nextFocus(),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          decoration: _fieldDecoration(
                            label: 'Contraseña',
                            prefixIcon: const Icon(
                              Icons.lock_outline_rounded,
                              color: AppDesignTokens.primary,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppDesignTokens.primary,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          obscureText: _obscurePassword,
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Ingresa tu contraseña'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        Consumer<AuthProvider>(
                          builder: (_, auth, __) {
                            if (auth.errorMessage != null) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  auth.errorMessage!,
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                    fontSize: 13,
                                  ),
                                ),
                              );
                            }
                            if (auth.successMessage != null) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  auth.successMessage!,
                                  style: const TextStyle(
                                    color: AppDesignTokens.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                        Consumer<AuthProvider>(
                          builder: (_, auth, __) {
                            return PrimaryButton(
                              label: 'Ingresar al sistema',
                              isLoading: auth.isLoading,
                              onPressed: () {
                                auth.clearMessages();
                                if (_formKey.currentState?.validate() ?? false) {
                                  auth.signIn(
                                    _emailController.text.trim(),
                                    _passwordController.text,
                                  );
                                }
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: TextButton(
                            onPressed: () {
                              _resetEmailController.text =
                                  _emailController.text;
                              _showForgotPasswordDialog();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AppDesignTokens.primary,
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            child: const Text('¿Olvidaste tu contraseña?'),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Divider(
                            height: 1,
                            thickness: 1,
                            color: Colors.grey.shade200,
                          ),
                        ),
                        Center(
                          child: TextButton(
                            onPressed: () =>
                                Navigator.of(context).pushNamed('/signup'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppDesignTokens.primaryDark,
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            child: const Text('Crear nueva cuenta'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final email = _resetEmailController.text.trim();
            final isEmailValid = _isValidEmail(email);
            return AlertDialog(
              title: const Text('Recuperar contraseña'),
              content: TextField(
                controller: _resetEmailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  errorText: email.isEmpty || isEmailValid
                      ? null
                      : 'Ingresa un email válido',
                ),
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setDialogState(() {}),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                Consumer<AuthProvider>(
                  builder: (_, auth, __) {
                    return FilledButton(
                      onPressed:
                          email.isEmpty || !isEmailValid || auth.isLoading
                          ? null
                          : () async {
                              await auth.sendPasswordResetEmail(email);
                              if (context.mounted) Navigator.pop(context);
                            },
                      child: auth.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Enviar'),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Marca visual del login (misma línea que splash, tamaño compacto).
class _LoginHeaderLogo extends StatelessWidget {
  const _LoginHeaderLogo();

  @override
  Widget build(BuildContext context) {
    const size = 88.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppDesignTokens.cardShadow,
      ),
      padding: const EdgeInsets.all(14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppDesignTokens.lavanda,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.groups_rounded,
          size: 40,
          color: AppDesignTokens.primary,
        ),
      ),
    );
  }
}
