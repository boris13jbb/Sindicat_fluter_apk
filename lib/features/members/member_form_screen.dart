import 'package:flutter/material.dart';
import '../../core/models/member.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../services/members_service.dart';

/// Pantalla de formulario para crear/editar socio
class MemberFormScreen extends StatefulWidget {
  final Member? member; // null = crear nuevo

  const MemberFormScreen({super.key, this.member});

  @override
  State<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends State<MemberFormScreen> {
  final MembersService _service = MembersService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _memberNumberController;
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _documentIdController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  bool _isLoading = false;
  bool get _isEditing => widget.member != null;

  @override
  void initState() {
    super.initState();
    _memberNumberController = TextEditingController(
      text: widget.member?.memberNumber ?? '',
    );
    _firstNameController = TextEditingController(
      text: widget.member?.firstName ?? '',
    );
    _lastNameController = TextEditingController(
      text: widget.member?.lastName ?? '',
    );
    _documentIdController = TextEditingController(
      text: widget.member?.documentId ?? '',
    );
    _emailController = TextEditingController(text: widget.member?.email ?? '');
    _phoneController = TextEditingController(text: widget.member?.phone ?? '');
  }

  @override
  void dispose() {
    _memberNumberController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _documentIdController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ProfessionalAppBar(
        title: _isEditing ? 'Editar Socio' : 'Nuevo Socio',
        onNavigateBack: () => Navigator.pop(context),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Número de Socio
                  _buildTextField(
                    controller: _memberNumberController,
                    label: 'Número de Socio *',
                    icon: Icons.badge,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'El número de socio es obligatorio';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Nombres
                  _buildTextField(
                    controller: _firstNameController,
                    label: 'Nombres *',
                    icon: Icons.person,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Los nombres son obligatorios';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Apellidos
                  _buildTextField(
                    controller: _lastNameController,
                    label: 'Apellidos *',
                    icon: Icons.person_outline,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Los apellidos son obligatorios';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Documento/Cédula
                  _buildTextField(
                    controller: _documentIdController,
                    label: 'Documento/Cédula',
                    icon: Icons.credit_card,
                  ),

                  const SizedBox(height: 16),

                  // Email
                  _buildTextField(
                    controller: _emailController,
                    label: 'Correo Electrónico',
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                        if (!emailRegex.hasMatch(value)) {
                          return 'Correo electrónico no válido';
                        }
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Teléfono
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Teléfono',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),

                  const SizedBox(height: 32),

                  // Botón Guardar
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _saveMember,
                      icon: const Icon(Icons.save),
                      label: Text(_isEditing ? 'Actualizar' : 'Crear'),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      keyboardType: keyboardType,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }

  Future<void> _saveMember() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final member = Member(
        id: widget.member?.id ?? '',
        memberNumber: _memberNumberController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        fullName:
            '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
                .trim(),
        documentId: _documentIdController.text.trim().isEmpty
            ? null
            : _documentIdController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        status: widget.member?.status ?? MemberStatus.active,
        createdAt: widget.member?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: widget.member?.createdBy,
      );

      if (_isEditing) {
        await _service.updateMember(member);
      } else {
        await _service.createMember(member);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
