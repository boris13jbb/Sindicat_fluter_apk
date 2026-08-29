import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design/app_design_tokens.dart';
import '../../core/design/widgets/premium_card.dart';
import '../../core/models/asistencia/evento.dart';
import '../../core/models/member.dart';
import '../../core/models/user.dart';
import '../../core/models/user_avatar_prefs.dart';
import '../../core/models/user_role.dart';
import '../../features/home/widgets/dashboard_welcome_avatar.dart';
import '../../features/profile/secure_attendance_qr_tab.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/attendance_service.dart';
import '../../services/member_lookup_service.dart';
import '../../services/members_service.dart';

/// Pantalla de perfil del usuario con pestañas
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _userPhoneController = TextEditingController();
  final TextEditingController _memberDocumentController =
      TextEditingController();
  final TextEditingController _memberPhoneController = TextEditingController();
  final MembersService _membersService = MembersService();
  final MemberLookupService _memberLookupService = MemberLookupService();
  final AttendanceService _attendanceService = AttendanceService();
  bool _savingProfile = false;

  /// Socio vinculado al usuario (padrón `members`), si existe.
  Member? _currentMember;
  StreamSubscription<MemberAttendanceSummary>? _attendanceSummarySubscription;
  MemberAttendanceSummary? _attendanceSummary;
  Object? _attendanceSummaryError;
  bool _isLoadingAttendanceSummary = false;
  bool _isLoadingMember = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCurrentMember();
  }

  Future<void> _loadCurrentMember() async {
    try {
      final user = await AuthService().getCurrentUser();
      if (user == null) {
        if (mounted) {
          setState(() => _isLoadingMember = false);
          _syncFormFields(null, null);
        }
        return;
      }

      Member? foundMember;

      if (user.memberId != null && user.memberId!.trim().isNotEmpty) {
        try {
          foundMember = await _membersService.getMemberById(
            user.memberId!.trim(),
          );
        } catch (_) {
          foundMember = null;
        }
      }

      if (foundMember == null &&
          user.employeeNumber != null &&
          user.employeeNumber!.trim().isNotEmpty) {
        try {
          final lookup = await _memberLookupService.lookupByEmployeeNumber(
            user.employeeNumber!,
          );
          foundMember = lookup?.member;
        } on MemberLookupException catch (e) {
          debugPrint(
            'Perfil: lookup de socio denegado o fallido: ${e.message}',
          );
        } catch (e) {
          debugPrint('Perfil: error al resolver socio: $e');
        }
      }

      await _attendanceSummarySubscription?.cancel();
      _attendanceSummarySubscription = null;
      if (mounted) {
        setState(() {
          _currentMember = foundMember;
          _attendanceSummary = null;
          _attendanceSummaryError = null;
          _isLoadingAttendanceSummary = foundMember != null;
          _isLoadingMember = false;
        });
        _syncFormFields(user, foundMember);
      }

      if (foundMember != null) {
        _attendanceSummarySubscription = _attendanceService
            .watchMemberAttendanceSummary(foundMember.id)
            .listen(
              (summary) {
                if (!mounted) return;
                setState(() {
                  _attendanceSummary = summary;
                  _attendanceSummaryError = null;
                  _isLoadingAttendanceSummary = false;
                });
              },
              onError: (Object error, StackTrace stackTrace) {
                debugPrint('Error cargando resumen de asistencia: $error');
                if (!mounted) return;
                setState(() {
                  _attendanceSummaryError = error;
                  _isLoadingAttendanceSummary = false;
                });
              },
            );
      }
    } catch (e, stackTrace) {
      debugPrint('Error cargando miembro en perfil: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isLoadingMember = false);
        final u = await AuthService().getCurrentUser();
        _syncFormFields(u, null);
      }
    }
  }

  @override
  void dispose() {
    _attendanceSummarySubscription?.cancel();
    _tabController.dispose();
    _displayNameController.dispose();
    _userPhoneController.dispose();
    _memberDocumentController.dispose();
    _memberPhoneController.dispose();
    super.dispose();
  }

  void _syncFormFields(AppUser? user, Member? m) {
    if (user != null) {
      _displayNameController.text = user.displayName?.trim() ?? '';
      _userPhoneController.text = (user.phoneNumber ?? '').trim();
    } else {
      _displayNameController.clear();
      _userPhoneController.clear();
    }
    _memberDocumentController.text = (m?.documentId ?? '').trim();
    _memberPhoneController.text = (m?.phone ?? '').trim();
  }

  bool _canPersistMemberFields(UserRole role) {
    return _currentMember != null &&
        (role == UserRole.admin || role == UserRole.superadmin);
  }

  Future<void> _saveProfile(BuildContext context, AuthProvider auth) async {
    final user = auth.user;
    if (user == null) return;

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _savingProfile = true);
    auth.clearMessages();
    try {
      await auth.saveProfileBasics(
        displayName: _displayNameController.text,
        phoneNumber: _userPhoneController.text,
      );
      if (auth.errorMessage != null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(auth.errorMessage!)));
        return;
      }

      if (_canPersistMemberFields(user.role) && _currentMember != null) {
        final m = _currentMember!;
        final ced = _memberDocumentController.text.trim();
        final ph = _memberPhoneController.text.trim();
        final updated = m.copyWith(documentId: ced, phone: ph);
        await _membersService.updateMember(updated);
      }

      await _loadCurrentMember();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cambios guardados correctamente')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _showProfileAvatarSheet(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.man_2_outlined),
                title: const Text('Avatar masculino (por defecto)'),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await auth.saveDefaultAvatar(UserAvatarMode.defaultMale);
                  if (context.mounted && auth.errorMessage == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Preferencia de avatar guardada'),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.woman_2_outlined),
                title: const Text('Avatar femenino (por defecto)'),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await auth.saveDefaultAvatar(UserAvatarMode.defaultFemale);
                  if (context.mounted && auth.errorMessage == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Preferencia de avatar guardada'),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: const Text('Avatar neutro (por defecto)'),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await auth.saveDefaultAvatar(UserAvatarMode.defaultNeutral);
                  if (context.mounted && auth.errorMessage == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Preferencia de avatar guardada'),
                      ),
                    );
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Subir imagen desde galería'),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await auth.pickAndUploadCustomAvatar();
                  if (context.mounted && auth.errorMessage == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Avatar actualizado')),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String? _validateDisplayName(String? v) {
    final t = (v ?? '').trim();
    if (t.length < 2) return 'Ingresa al menos 2 caracteres';
    if (t.length > 120) return 'Nombre demasiado largo';
    return null;
  }

  String? _validateUserPhone(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final digits = t.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) return 'Teléfono: al menos 7 dígitos';
    return null;
  }

  String? _validateMemberDocument(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    if (t.length < 5) return 'Documento demasiado corto';
    return null;
  }

  String? _validateMemberPhone(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final digits = t.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) return 'Teléfono padrón: al menos 7 dígitos';
    return null;
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Deseas salir de la aplicación?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<AuthProvider>().signOut();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  static String _displayNameForCard(AppUser user) {
    final raw = user.displayName?.trim();
    final fallback = user.email.trim().isEmpty ? 'Usuario' : user.email.trim();
    final name = raw?.isNotEmpty == true ? raw! : fallback;
    return _titleCaseIfNeeded(name);
  }

  static String _titleCaseIfNeeded(String value) {
    final letters = value.replaceAll(RegExp(r'[^A-Za-zÁÉÍÓÚÜÑáéíóúüñ]'), '');
    if (letters.isEmpty || value != value.toUpperCase()) return value;
    return value
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) {
          if (part.length == 1) return part.toUpperCase();
          return part[0].toUpperCase() + part.substring(1).toLowerCase();
        })
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('No hay usuario autenticado')),
          );
        }
        final role = user.role;

        return Scaffold(
          backgroundColor: AppDesignTokens.background,
          bottomNavigationBar: _ProfileBottomNavigation(role: role),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProfileWaveHeader(
                onBack: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacementNamed(context, '/home');
                  }
                },
                onProfileTap: () {
                  _tabController.animateTo(0);
                  if (mounted) setState(() {});
                },
                onLogout: () => _confirmSignOut(context),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDesignTokens.horizontalPadding,
                  10,
                  AppDesignTokens.horizontalPadding,
                  8,
                ),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppDesignTokens.lavanda,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: AppDesignTokens.primary,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: const EdgeInsets.all(4),
                    labelColor: Colors.white,
                    unselectedLabelColor: AppDesignTokens.primaryDark,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    tabAlignment: TabAlignment.fill,
                    tabs: const [
                      Tab(text: 'Información'),
                      Tab(text: 'Asistencia segura'),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SafeArea(
                  top: false,
                  left: false,
                  right: false,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildProfileDataTab(context, auth),
                      _buildQRCodeTab(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _premiumInputDecoration(String label) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: AppDesignTokens.primary.withValues(alpha: 0.14),
      ),
    );
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppDesignTokens.primary,
          width: 1.6,
        ),
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
    );
  }

  Widget _premiumReadonlyValue(String label, String value) {
    final shown = value.trim().isEmpty ? 'No registrado' : value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InputDecorator(
        decoration: _premiumInputDecoration(label),
        child: Text(
          shown,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF141632),
          ),
        ),
      ),
    );
  }

  String _displayOr(String value, {bool useSinAsignar = false}) {
    final t = value.trim();
    if (t.isEmpty) return useSinAsignar ? 'Sin asignar' : 'No registrado';
    return t;
  }

  Widget _buildSocioMiniCell(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppDesignTokens.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppDesignTokens.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppDesignTokens.primaryDark.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppDesignTokens.primaryDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceStatStrip(
    BuildContext context,
    MemberAttendanceSummary summary,
  ) {
    final presentes = summary.totalAsistencias;
    final faltas = summary.totalFaltas;
    final denom = presentes + faltas;
    final pct = denom == 0
        ? 0
        : ((100 * presentes) / denom).round().clamp(0, 100);

    Widget box(String title, String value, Color valueColor) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppDesignTokens.primary.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            children: [
              Text(
                value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: valueColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppDesignTokens.primaryDark.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        box('Presentes', '$presentes', Colors.green.shade700),
        const SizedBox(width: 8),
        box('Faltas', '$faltas', Colors.red.shade700),
        const SizedBox(width: 8),
        box('Cumplimiento', '$pct%', Colors.blue.shade700),
      ],
    );
  }

  Widget _buildProfileSummaryCard(
    BuildContext context,
    AppUser user,
    UserRole role, {
    required VoidCallback onAvatarEdit,
  }) {
    return PremiumCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              DashboardWelcomeAvatar(user: user, size: 88),
              Positioned(
                right: -2,
                bottom: -2,
                child: Material(
                  color: Colors.white,
                  elevation: 3,
                  shadowColor: Colors.black26,
                  shape: CircleBorder(
                    side: BorderSide(
                      color: AppDesignTokens.primary.withValues(alpha: 0.22),
                    ),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onAvatarEdit,
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: Icon(
                        Icons.edit_rounded,
                        size: 18,
                        color: AppDesignTokens.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayNameForCard(user),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppDesignTokens.primaryDark,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEBDDFF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    role.displayName,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppDesignTokens.primaryDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _displayOr(user.email),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppDesignTokens.bodyMuted(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDataTab(BuildContext context, AuthProvider auth) {
    final user = auth.user!;
    final canEditMember = _canPersistMemberFields(user.role);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppDesignTokens.horizontalPadding,
        12,
        AppDesignTokens.horizontalPadding,
        108,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProfileSummaryCard(
              context,
              user,
              user.role,
              onAvatarEdit: () => _showProfileAvatarSheet(context),
            ),
            const SizedBox(height: 20),
            PremiumCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Información de cuenta',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppDesignTokens.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Los datos de cuenta se guardan en tu perfil. '
                    'Cédula y teléfono del padrón solo los actualizan administradores.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppDesignTokens.primaryDark.withValues(
                        alpha: 0.55,
                      ),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _premiumReadonlyValue('Email', _displayOr(user.email)),
                  TextFormField(
                    controller: _displayNameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: _premiumInputDecoration('Nombre'),
                    validator: _validateDisplayName,
                  ),
                  const SizedBox(height: 12),
                  _premiumReadonlyValue(
                    'Rol del sistema',
                    user.role.displayName,
                  ),
                  TextFormField(
                    controller: _userPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: _premiumInputDecoration(
                      'Teléfono de contacto (tu cuenta)',
                    ),
                    validator: _validateUserPhone,
                  ),
                ],
              ),
            ),
            if (user.employeeNumber != null &&
                user.employeeNumber!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'N° empleado: ${user.employeeNumber}',
                  style: AppDesignTokens.bodyMuted(context),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 18),
            if (_isLoadingMember)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_currentMember != null) ...[
              PremiumCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Información de socio',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppDesignTokens.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildSocioMiniCell(
                            context,
                            'Nº Socio',
                            _displayOr(_currentMember!.memberNumber),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildSocioMiniCell(
                            context,
                            'Estado',
                            _currentMember!.status.displayName,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildSocioMiniCell(
                            context,
                            'Cédula',
                            _displayOr(_currentMember!.documentId ?? ''),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildSocioMiniCell(
                            context,
                            'WorkerCode',
                            _displayOr(
                              _currentMember!.workerCode ?? '',
                              useSinAsignar: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_currentMember!.modalidad != null)
                      _premiumReadonlyValue(
                        'Modalidad',
                        JustificacionHelper.etiquetaModalidad(
                          _currentMember!.modalidad!,
                        ),
                      )
                    else
                      _premiumReadonlyValue('Modalidad', 'Sin asignar'),
                    if (!canEditMember) ...[
                      const SizedBox(height: 8),
                      _premiumReadonlyValue(
                        'Teléfono en padrón',
                        _displayOr(_currentMember!.phone ?? ''),
                      ),
                    ],
                  ],
                ),
              ),
              if (canEditMember) ...[
                const SizedBox(height: 14),
                PremiumCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Editar padrón (administrador)',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppDesignTokens.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _memberDocumentController,
                        keyboardType: TextInputType.text,
                        decoration: _premiumInputDecoration(
                          'Cédula / documento (padrón)',
                        ),
                        validator: _validateMemberDocument,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _memberPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: _premiumInputDecoration(
                          'Teléfono en padrón de socios',
                        ),
                        validator: _validateMemberPhone,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _buildAttendanceSummaryCard(context),
            ] else
              PremiumCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(18),
                child: Text(
                  'Sin vínculo al padrón de socios. Cuando el administrador te '
                  'asocie, verás aquí número de socio, estado y resumen de asistencia.',
                  style: AppDesignTokens.bodyMuted(context),
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _savingProfile
                    ? null
                    : () => _saveProfile(context, auth),
                style: FilledButton.styleFrom(
                  backgroundColor: AppDesignTokens.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _savingProfile
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Guardar cambios',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _confirmSignOut(context),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFE8EC),
                  foregroundColor: const Color(0xFFC62828),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Cerrar sesión',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Pestaña de asistencia segura (SATT2). Reemplaza el QR estático legacy.
  Widget _buildQRCodeTab() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.user == null) {
          return const Center(child: Text('No hay usuario autenticado'));
        }
        if (_isLoadingMember && _currentMember == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
          child: SecureAttendanceQrTab(
            hasLinkedMember: _currentMember != null,
            memberDisplayName: _currentMember?.fullName.trim() ?? '',
          ),
        );
      },
    );
  }

  Widget _buildAttendanceSummaryCard(BuildContext context) {
    if (_currentMember == null) {
      return _buildInfoCard(context, 'Resumen de asistencia', [
        _buildInfoRow('Estado', 'No disponible'),
      ]);
    }

    if (_attendanceSummaryError != null) {
      return _buildInfoCard(context, 'Resumen de asistencia', [
        _buildAttendanceSummaryError(context, _attendanceSummaryError!),
      ]);
    }

    final summary = _attendanceSummary;
    if (_isLoadingAttendanceSummary || summary == null) {
      return _buildInfoCard(context, 'Resumen de asistencia', [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Expanded(child: Text('Calculando resumen...')),
            ],
          ),
        ),
      ]);
    }

    final recentDetails = summary.detalles.take(3).toList();

    return _buildInfoCard(context, 'Resumen de asistencia', [
      _buildAttendanceStatStrip(context, summary),
      const SizedBox(height: 16),
      const Divider(height: 1),
      const SizedBox(height: 12),
      _buildInfoRow('Eventos convocados', summary.totalConvocados.toString()),
      _buildInfoRow('Asistencias', summary.totalAsistencias.toString()),
      _buildInfoRow('Faltas injustificadas', summary.totalFaltas.toString()),
      _buildInfoRow('No convocado', summary.totalNoConvocado.toString()),
      if (recentDetails.isNotEmpty) ...[
        const SizedBox(height: 8),
        const Divider(),
        const SizedBox(height: 8),
        Text(
          'Últimos eventos',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (final detail in recentDetails)
          _buildAttendanceDetailRow(context, detail),
      ],
    ]);
  }

  Widget _buildAttendanceDetailRow(
    BuildContext context,
    AsistenciaDetalle detail,
  ) {
    final color = _attendanceStatusColor(context, detail.estado);
    final subtitle = [
      _formatAttendanceDate(detail.fecha),
      if (detail.justificacion != null &&
          detail.justificacion!.trim().isNotEmpty)
        detail.justificacion!.trim(),
      if (detail.isLegacy) 'Legacy',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.eventName,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${detail.estado} · $subtitle',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceSummaryError(BuildContext context, Object error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Theme.of(context).colorScheme.error,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumen temporalmente no disponible',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppDesignTokens.primaryDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _attendanceSummaryErrorMessage(error),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppDesignTokens.primaryDark.withValues(alpha: 0.78),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _attendanceSummaryErrorMessage(Object error) {
    final raw = error.toString();
    if (raw.contains('permission-denied')) {
      return 'No tienes permisos para consultar este resumen de asistencia.';
    }
    if (raw.contains('failed-precondition') ||
        raw.contains('COLLECTION_GROUP') ||
        raw.contains('index')) {
      return 'La consulta de asistencia necesita actualizarse. Reinicia la pantalla o vuelve a ingresar al perfil.';
    }
    return 'No se pudo calcular el resumen. Intenta nuevamente o contacta al administrador.';
  }

  Color _attendanceStatusColor(BuildContext context, String status) {
    if (status == 'Presente') return Colors.green.shade700;
    if (status == 'No convocado') return Colors.blue.shade700;
    if (status == 'Ausente justificado') return Colors.orange.shade700;
    return Theme.of(context).colorScheme.error;
  }

  String _formatAttendanceDate(int millis) {
    if (millis <= 0) return 'Fecha no identificada';
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  /// Widget para fila de información
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  /// Widget para tarjeta de información
  Widget _buildInfoCard(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return PremiumCard(
      margin: EdgeInsets.zero,
      borderRadius: AppDesignTokens.radiusMedium,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppDesignTokens.primaryDark,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

/// Encabezado ondulado morado (diseño premium perfil).
class _ProfileWaveHeader extends StatelessWidget {
  const _ProfileWaveHeader({
    required this.onBack,
    required this.onProfileTap,
    required this.onLogout,
  });

  final VoidCallback onBack;
  final VoidCallback onProfileTap;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _ProfileWaveClipper(),
      child: Container(
        height: 198,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppDesignTokens.primaryDark, AppDesignTokens.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 8, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfileCircleIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: onBack,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        Text(
                          'Perfil de usuario',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Datos personales, socio y código QR',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ProfileCircleIconButton(
                      icon: Icons.person_rounded,
                      onTap: onProfileTap,
                    ),
                    const SizedBox(width: 8),
                    _ProfileCircleIconButton(
                      icon: Icons.logout_rounded,
                      onTap: onLogout,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileCircleIconButton extends StatelessWidget {
  const _ProfileCircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black26,
      shape: CircleBorder(
        side: BorderSide(
          color: AppDesignTokens.primary.withValues(alpha: 0.15),
        ),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: AppDesignTokens.primary, size: 22),
        ),
      ),
    );
  }
}

class _ProfileWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(0, size.height - 42)
      ..cubicTo(
        size.width * 0.22,
        size.height - 12,
        size.width * 0.64,
        size.height - 88,
        size.width,
        size.height - 36,
      )
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Barra inferior alineada visualmente con [HomeScreen] (perfil seleccionado).
class _ProfileBottomNavigation extends StatelessWidget {
  const _ProfileBottomNavigation({required this.role});

  final UserRole role;

  static const Color _primary = AppDesignTokens.primary;
  static const Color _muted = Color(0xFF6D6E8D);

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == UserRole.admin || role == UserRole.superadmin;
    final canManageAttendance = isAdmin || role == UserRole.operadorAsistencia;
    final entries = <_ProfileBottomNavEntry>[
      const _ProfileBottomNavEntry(
        label: 'Inicio',
        icon: Icons.home_outlined,
        route: '__pop__',
      ),
      const _ProfileBottomNavEntry(
        label: 'Voto',
        icon: Icons.how_to_vote_outlined,
        route: '/voto/elections',
      ),
      if (canManageAttendance)
        const _ProfileBottomNavEntry(
          label: 'Asist.',
          icon: Icons.check_rounded,
          route: '/asistencia',
        ),
      if (isAdmin)
        const _ProfileBottomNavEntry(
          label: 'Socios',
          icon: Icons.groups_rounded,
          route: '/members',
        ),
      const _ProfileBottomNavEntry(
        label: 'Perfil',
        icon: Icons.person_outline_rounded,
        route: null,
      ),
    ];

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFECE5F6)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14271B5E),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: entries
              .map((e) => _ProfileBottomNavItem(entry: e))
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _ProfileBottomNavEntry {
  const _ProfileBottomNavEntry({
    required this.label,
    required this.icon,
    this.route,
  });

  final String label;
  final IconData icon;

  /// `null` indica la pantalla actual (Perfil): resaltado y sin navegación.
  final String? route;
}

class _ProfileBottomNavItem extends StatelessWidget {
  const _ProfileBottomNavItem({required this.entry});

  final _ProfileBottomNavEntry entry;

  @override
  Widget build(BuildContext context) {
    final isProfile = entry.route == null;
    final foreground = isProfile
        ? _ProfileBottomNavigation._primary
        : _ProfileBottomNavigation._muted;

    return Expanded(
      child: Tooltip(
        message: entry.label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: isProfile
                ? null
                : () {
                    if (entry.route == '__pop__') {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushReplacementNamed(context, '/home');
                      }
                    } else if (entry.route != null) {
                      Navigator.pushNamed(context, entry.route!);
                    }
                  },
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                constraints: const BoxConstraints(minHeight: 46),
                padding: EdgeInsets.symmetric(
                  horizontal: isProfile ? 10 : 4,
                  vertical: 6,
                ),
                decoration: isProfile
                    ? BoxDecoration(
                        color: AppDesignTokens.lavanda,
                        borderRadius: BorderRadius.circular(22),
                      )
                    : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(entry.icon, color: foreground, size: 18),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        entry.label,
                        maxLines: 1,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 11,
                          fontWeight: isProfile
                              ? FontWeight.w900
                              : FontWeight.w600,
                          height: 1,
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
    );
  }
}
