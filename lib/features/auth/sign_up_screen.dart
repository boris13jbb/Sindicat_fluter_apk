import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/design/widgets/premium_card.dart';
import '../../core/design/widgets/primary_button.dart';
import '../../providers/auth_provider.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _employeeNumberController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  bool _isValidEmail(String email) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
  }

  InputDecoration _fieldDecoration({
    required String label,
    Widget? suffixIcon,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDesignTokens.radiusMedium),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );
    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
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
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    _employeeNumberController.dispose();
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
          final headerH = (constraints.maxHeight * 0.26).clamp(168.0, 220.0);

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
                          padding: const EdgeInsets.fromLTRB(
                            8,
                            4,
                            AppDesignTokens.horizontalPadding,
                            12,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Material(
                                color: Colors.white,
                                shape: const CircleBorder(),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => Navigator.of(context).maybePop(),
                                  child: const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: Icon(
                                      Icons.arrow_back_rounded,
                                      color: AppDesignTokens.primary,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Crear cuenta',
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Registro seguro de usuario',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.white.withValues(alpha: 0.88),
                                      ),
                                    ),
                                  ],
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
                  headerH - 44,
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
                          'Datos del socio',
                          style: AppDesignTokens.titleLarge(context).copyWith(
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Complete la información para solicitar acceso.',
                          style: AppDesignTokens.bodyMuted(context).copyWith(
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 22),
                        TextFormField(
                          controller: _displayNameController,
                          decoration: _fieldDecoration(
                            label: 'Nombres completos',
                            suffixIcon: const Icon(
                              Icons.person_outline_rounded,
                              color: AppDesignTokens.primary,
                            ),
                          ),
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _employeeNumberController,
                          decoration: _fieldDecoration(
                            label: 'Cédula / número de trabajador',
                            suffixIcon: const Icon(
                              Icons.tag_rounded,
                              color: AppDesignTokens.primary,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'El número de trabajador es obligatorio'
                              : null,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          decoration: _fieldDecoration(
                            label: 'Correo electrónico',
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
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          decoration: _fieldDecoration(
                            label: 'Contraseña',
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
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Ingresa una contraseña';
                            }
                            if (v.length < 6) return 'Mínimo 6 caracteres';
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPasswordController,
                          decoration: _fieldDecoration(
                            label: 'Confirmar contraseña',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppDesignTokens.primary,
                              ),
                              onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm,
                              ),
                            ),
                          ),
                          obscureText: _obscureConfirm,
                          validator: (v) {
                            if (v != _passwordController.text) {
                              return 'Las contraseñas no coinciden';
                            }
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                        if (_passwordController.text.isNotEmpty &&
                            _passwordController.text.length < 6)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'La contraseña debe tener al menos 6 caracteres',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppDesignTokens.primaryDark
                                    .withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                        Consumer<AuthProvider>(
                          builder: (_, auth, __) {
                            if (auth.errorMessage != null) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Text(
                                  auth.errorMessage!,
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                    fontSize: 13,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                        const SizedBox(height: 20),
                        Consumer<AuthProvider>(
                          builder: (_, auth, __) {
                            final email = _emailController.text.trim();
                            final canSubmit =
                                email.isNotEmpty &&
                                _isValidEmail(email) &&
                                _employeeNumberController.text.trim().isNotEmpty &&
                                _passwordController.text.isNotEmpty &&
                                _passwordController.text ==
                                    _confirmPasswordController.text &&
                                _passwordController.text.length >= 6;
                            return PrimaryButton(
                              label: 'Crear cuenta',
                              isLoading: auth.isLoading,
                              onPressed: auth.isLoading || !canSubmit
                                  ? null
                                  : () {
                                      auth.clearMessages();
                                      if (_formKey.currentState?.validate() ??
                                          false) {
                                        auth.signUpWithEmployeeNumber(
                                          email: _emailController.text.trim(),
                                          password: _passwordController.text,
                                          employeeNumber:
                                              _employeeNumberController.text
                                                  .trim(),
                                          displayName:
                                              _displayNameController.text
                                                  .trim()
                                                  .isEmpty
                                              ? null
                                              : _displayNameController.text
                                                  .trim(),
                                        );
                                      }
                                    },
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            style: TextButton.styleFrom(
                              foregroundColor: AppDesignTokens.primary,
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            child: const Text('Ya tengo una cuenta'),
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
}
