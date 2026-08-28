import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/user_role.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../services/users_admin_service.dart';
import 'widgets/role_assignment_sheet.dart';

/// Formulario para que un superadmin cree cuentas reales en Firebase Auth.
class InviteUserScreen extends StatefulWidget {
  const InviteUserScreen({super.key});

  @override
  State<InviteUserScreen> createState() => _InviteUserScreenState();
}

class _InviteUserScreenState extends State<InviteUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = UsersAdminService();

  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _employeeController = TextEditingController();

  UserRole _role = UserRole.voter;
  bool _saving = false;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _employeeController.dispose();
    super.dispose();
  }

  Future<void> _pickRole() async {
    final selected = await RoleAssignmentSheet.show(
      context,
      currentRole: _role,
      userLabel: _emailController.text.trim().isEmpty
          ? 'Nuevo usuario'
          : _emailController.text.trim(),
    );
    if (selected != null) {
      setState(() => _role = selected);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final result = await _service.inviteUser(
        email: _emailController.text.trim(),
        role: _role,
        displayName: _nameController.text.trim(),
        employeeNumber: _employeeController.text.trim(),
      );

      if (!mounted) return;

      if (result.emailSent) {
        await _showResultDialog(
          title: 'Cuenta creada',
          message:
              'Se creó la cuenta de ${result.email} con rol '
              '${result.role.displayName}.\n\n'
              'Se envió un correo con la contraseña temporal.',
        );
      } else {
        await _showResultDialog(
          title: 'Cuenta creada (sin correo)',
          message:
              'Se creó la cuenta de ${result.email}.\n\n'
              'No se pudo enviar el correo. Entrega esta contraseña temporal '
              'de forma segura:\n\n${result.temporaryPassword ?? '—'}',
          copyText: result.temporaryPassword,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } on UsersAdminException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showResultDialog({
    required String title,
    required String message,
    String? copyText,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          if (copyText != null && copyText.isNotEmpty)
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: copyText));
                if (context.mounted) {
                  Navigator.pop(context);
                  _showSnack('Contraseña copiada al portapapeles.');
                }
              },
              child: const Text('Copiar contraseña'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: ProfessionalAppBar(
        title: 'Invitar usuario',
        onNavigateBack: () => Navigator.pop(context),
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Crear cuenta',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Se creará una cuenta real en Firebase Auth y se vinculará al '
                  'padrón si indicas el número de trabajador.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) return 'El correo es obligatorio';
                          if (!email.contains('@')) return 'Correo no válido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nombre para mostrar',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _employeeController,
                        decoration: const InputDecoration(
                          labelText: 'Número de trabajador (opcional)',
                          helperText:
                              'Si lo indicas, debe existir en el padrón de socios.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_role.displayName),
                        subtitle: Text(_role.assignmentDescription),
                        trailing: OutlinedButton(
                          onPressed: _saving ? null : _pickRole,
                          child: const Text('Elegir rol'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_saving)
              const ColoredBox(
                color: Color(0x33000000),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Crear e invitar'),
          ),
        ),
      ),
    );
  }
}
