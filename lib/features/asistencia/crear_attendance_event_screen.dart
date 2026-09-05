import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/design/widgets/premium_card.dart';
import '../../core/models/asistencia/evento.dart';
import '../../core/models/member.dart';
import '../../core/models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../services/attendance_service.dart';
import '../../services/members_service.dart';
import '../elections/widgets/voto_premium_chrome.dart';

/// Alta / edición de eventos operativos en la colección `attendance_events`.
class CrearAttendanceEventScreen extends StatefulWidget {
  const CrearAttendanceEventScreen({super.key, this.eventId});

  /// When non-null, screen loads and updates the existing event.
  final String? eventId;

  @override
  State<CrearAttendanceEventScreen> createState() =>
      _CrearAttendanceEventScreenState();
}

enum _TipoCrearEvento { ordinaria, extraordinaria, escribir }

class _CrearAttendanceEventScreenState
    extends State<CrearAttendanceEventScreen> {
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _lugarController = TextEditingController();
  final _tipoCustomController = TextEditingController();
  final AttendanceService _service = AttendanceService();

  DateTime _fecha = DateTime.now();
  late DateTime _fechaFin;
  _TipoCrearEvento _tipoCrear = _TipoCrearEvento.ordinaria;
  bool _loading = false;
  bool _loadingEvent = false;
  bool _lockHistoricalFields = false;
  AttendanceEvent? _originalEvent;

  /// UI mock (`03_asistencia_crear_evento`): sin persistencia en modelo actual.
  bool _toggleQrRegistro = true;
  bool _toggleManualRegistro = true;
  bool _toggleBloquearDuplicados = true;

  /// Estado inicial del evento (`AttendanceEvent.estado`).
  String _estadoInicial = 'programado';

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _advancedSectionKey = GlobalKey();

  /// `true`: `miembrosConvocados` vacío → el cálculo usa todos los activos (`AttendanceService`).
  bool _convocatoriaTodosActivos = true;
  final Set<String> _miembrosConvocadosIds = <String>{};

  /// Modalidades excluidas de la convocatoria (`AttendanceEvent.modalidadesNoConvocadas`).
  final Set<Modalidad> _modalidadesNoConvocadas = {};

  bool get _isEditMode =>
      widget.eventId != null && widget.eventId!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final d = _fecha;
    _fechaFin = DateTime(d.year, d.month, d.day, 23, 59);
    if (_isEditMode) {
      _loadingEvent = true;
      _loadExistingEvent();
    }
  }

  Future<void> _loadExistingEvent() async {
    try {
      final event = await _service.getEventById(widget.eventId!.trim());
      if (!mounted) return;
      if (event == null) {
        setState(() => _loadingEvent = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Evento no encontrado')));
        Navigator.pop(context);
        return;
      }
      final hasRecords = await _service.hasAttendanceRecords(event.id);
      if (!mounted) return;
      _applyEventToForm(event);
      setState(() {
        _originalEvent = event;
        // Fail-closed: missing asistenciaCount locks historical fields.
        _lockHistoricalFields = event.historicalFieldsLocked || hasRecords;
        _loadingEvent = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingEvent = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo cargar el evento')));
      Navigator.pop(context);
    }
  }

  void _applyEventToForm(AttendanceEvent event) {
    _nombreController.text = event.nombre;
    _descripcionController.text = event.descripcion;
    _lugarController.text = event.lugar;
    _fecha = DateTime.fromMillisecondsSinceEpoch(event.fecha);
    _fechaFin = DateTime.fromMillisecondsSinceEpoch(
      event.fechaFin ?? event.fechaFinVigenciaMs,
    );
    _estadoInicial = event.estado;
    final tipo = event.tipo.toLowerCase().trim();
    if (tipo == 'ordinaria') {
      _tipoCrear = _TipoCrearEvento.ordinaria;
    } else if (tipo == 'extraordinaria') {
      _tipoCrear = _TipoCrearEvento.extraordinaria;
    } else {
      _tipoCrear = _TipoCrearEvento.escribir;
      _tipoCustomController.text = event.tipo;
    }
    if (event.miembrosConvocados.isEmpty) {
      _convocatoriaTodosActivos = true;
      _miembrosConvocadosIds.clear();
    } else {
      _convocatoriaTodosActivos = false;
      _miembrosConvocadosIds
        ..clear()
        ..addAll(event.miembrosConvocados);
    }
    _modalidadesNoConvocadas
      ..clear()
      ..addAll(
        event.modalidadesNoConvocadas
            .map(Modalidad.tryParse)
            .whereType<Modalidad>(),
      );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _lugarController.dispose();
    _tipoCustomController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Valor persistido en `AttendanceEvent.tipo` (colección `attendance_events`).
  String _tipoParaFirestore() {
    switch (_tipoCrear) {
      case _TipoCrearEvento.ordinaria:
        return 'ordinaria';
      case _TipoCrearEvento.extraordinaria:
        return 'extraordinaria';
      case _TipoCrearEvento.escribir:
        var t = _tipoCustomController.text.trim().replaceAll(
          RegExp(r'\s+'),
          ' ',
        );
        if (t.isEmpty) return 'personalizado';
        if (t.length > 80) t = t.substring(0, 80);
        return t.toLowerCase();
    }
  }

  Future<void> _pickDateOnly() async {
    if (_lockHistoricalFields) return;
    final date = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    setState(() {
      _fecha = DateTime(
        date.year,
        date.month,
        date.day,
        _fecha.hour,
        _fecha.minute,
      );
      if (!_fechaFin.isAfter(_fecha)) {
        _fechaFin = DateTime(_fecha.year, _fecha.month, _fecha.day, 23, 59);
      }
    });
  }

  Future<void> _pickStartTime() async {
    if (_lockHistoricalFields) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fecha),
    );
    if (time == null || !mounted) return;
    setState(() {
      _fecha = DateTime(
        _fecha.year,
        _fecha.month,
        _fecha.day,
        time.hour,
        time.minute,
      );
      if (!_fechaFin.isAfter(_fecha)) {
        _fechaFin = DateTime(_fecha.year, _fecha.month, _fecha.day, 23, 59);
      }
    });
  }

  /// Ajuste conjunto inicio (opciones avanzadas).
  Future<void> _pickDateTimeCombined() async {
    if (_lockHistoricalFields) return;
    final date = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fecha),
    );
    if (time == null || !mounted) return;
    setState(() {
      _fecha = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (!_fechaFin.isAfter(_fecha)) {
        _fechaFin = DateTime(_fecha.year, _fecha.month, _fecha.day, 23, 59);
      }
    });
  }

  Future<void> _pickFechaFin() async {
    if (_lockHistoricalFields) return;
    final date = await showDatePicker(
      context: context,
      initialDate: _fechaFin.isBefore(_fecha) ? _fecha : _fechaFin,
      firstDate: DateTime(_fecha.year, _fecha.month, _fecha.day),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fechaFin),
    );
    if (time == null || !mounted) return;
    final fin = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() => _fechaFin = fin);
  }

  Future<void> _abrirSeleccionConvocados() async {
    final nueva = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final height = MediaQuery.sizeOf(ctx).height * 0.88;
        return SizedBox(
          height: height,
          child: _SeleccionConvocadosSheet(
            initial: {..._miembrosConvocadosIds},
          ),
        );
      },
    );
    if (nueva != null && mounted) {
      setState(
        () => _miembrosConvocadosIds
          ..clear()
          ..addAll(nueva),
      );
    }
  }

  Future<void> _guardar() async {
    final nombre = _nombreController.text.trim();
    final lugar = _lugarController.text.trim();
    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre del evento es obligatorio')),
      );
      return;
    }
    if (lugar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El lugar o sede es obligatorio')),
      );
      return;
    }
    if (!_lockHistoricalFields &&
        !_convocatoriaTodosActivos &&
        _miembrosConvocadosIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Elige convocados específicos o vuelve a «Todos los socios activos».',
          ),
        ),
      );
      return;
    }
    if (!_fechaFin.isAfter(_fecha)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La fecha y hora de fin deben ser posteriores al inicio del evento.',
          ),
        ),
      );
      return;
    }
    if (_tipoCrear == _TipoCrearEvento.escribir &&
        _tipoCustomController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Describe el tipo personalizado o elige Ordinaria / Extraordinaria.',
          ),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      if (_isEditMode) {
        final original = _originalEvent;
        if (original == null) {
          throw Exception('Evento no cargado');
        }
        final updated = original.copyWith(
          nombre: nombre,
          descripcion: _descripcionController.text.trim(),
          lugar: lugar,
          // Preserve identity and archive metadata; never rewrite id/creadoPor/createdAt.
          fecha: _lockHistoricalFields
              ? original.fecha
              : _fecha.millisecondsSinceEpoch,
          fechaFin: _lockHistoricalFields
              ? original.fechaFin
              : _fechaFin.millisecondsSinceEpoch,
          tipo: _lockHistoricalFields ? original.tipo : _tipoParaFirestore(),
          activo: original.activo,
          estado: _lockHistoricalFields ? original.estado : _estadoInicial,
          miembrosConvocados: _lockHistoricalFields
              ? original.miembrosConvocados
              : (_convocatoriaTodosActivos
                    ? <String>[]
                    : _miembrosConvocadosIds.toList()),
          modalidadesNoConvocadas: _lockHistoricalFields
              ? original.modalidadesNoConvocadas
              : _modalidadesNoConvocadas.map((m) => m.value).toList(),
          geofenceEnabled: original.geofenceEnabled,
          latitude: original.latitude,
          longitude: original.longitude,
          geofenceRadiusMeters: original.geofenceRadiusMeters,
          requireScannerLocation: original.requireScannerLocation,
          requireMemberLocation: original.requireMemberLocation,
          secureQrMode: original.secureQrMode,
          archivado: original.archivado,
          archivadoAt: original.archivadoAt,
          archivadoPor: original.archivadoPor,
        );
        await _service.updateEvent(updated);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evento actualizado correctamente')),
        );
        Navigator.pop(context, true);
        return;
      }

      final eventId = await _service.createEvent(
        AttendanceEvent(
          id: '',
          nombre: nombre,
          descripcion: _descripcionController.text.trim(),
          fecha: _fecha.millisecondsSinceEpoch,
          fechaFin: _fechaFin.millisecondsSinceEpoch,
          lugar: lugar,
          tipo: _tipoParaFirestore(),
          activo: true,
          miembrosConvocados: _convocatoriaTodosActivos
              ? []
              : _miembrosConvocadosIds.toList(),
          modalidadesNoConvocadas: _modalidadesNoConvocadas
              .map((m) => m.value)
              .toList(),
          creadoPor: '',
          createdAt: 0,
          estado: _estadoInicial,
        ),
      );
      if (!mounted) return;
      final navigator = Navigator.of(context);
      // Cierra esta ruta con el nuevo id (`Future` del `pushNamed` que abrió la pantalla).
      navigator.pop(eventId);
      // Abre detalle después del frame actual para mantener orden de rutas válido.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigator.pushNamed(
          '/asistencia/attendance_event_detail',
          arguments: eventId,
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _premiumInputDec(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppDesignTokens.primary.withValues(alpha: 0.2),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppDesignTokens.primary.withValues(alpha: 0.2),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppDesignTokens.primary,
          width: 1.6,
        ),
      ),
    );
  }

  String _fechaDMYText() {
    return '${_fecha.day.toString().padLeft(2, '0')}/'
        '${_fecha.month.toString().padLeft(2, '0')}/'
        '${_fecha.year}';
  }

  String _horaInicioText() {
    return '${_fecha.hour.toString().padLeft(2, '0')}:'
        '${_fecha.minute.toString().padLeft(2, '0')}';
  }

  Widget _lavenderSwitchRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppDesignTokens.lavanda,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppDesignTokens.primaryDark,
              ),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: AppDesignTokens.primary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: AppDesignTokens.primaryDark.withValues(
              alpha: 0.25,
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  void _scrollToAdvanced() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _advancedSectionKey.currentContext;
      if (ctx != null && mounted) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          alignment: 0.05,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final role = auth.user?.role ?? UserRole.user;

    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      bottomNavigationBar: VotoModuleBottomNavigation(
        role: role,
        selection: VotoNavSlot.asistencia,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VotoWaveHeader(
            title: _isEditMode ? 'Editar evento' : 'Crear evento',
            subtitle: _isEditMode
                ? 'Actualizar control de asistencia'
                : 'Nuevo control de asistencia',
            onBack: () => Navigator.pop(context),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                VotoCircleIconButton(
                  icon: Icons.help_outline_rounded,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _lockHistoricalFields
                              ? 'Este evento ya tiene registros. Solo puede '
                                    'cambiar nombre, descripción y lugar.'
                              : 'Completa los datos principales. Convocatoria, tipo de '
                                    'reunión y fin de vigencia están en «Más opciones».',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),
                VotoCircleIconButton(
                  icon: Icons.edit_calendar_outlined,
                  onTap: _lockHistoricalFields ? () {} : _pickDateTimeCombined,
                ),
                const SizedBox(width: 6),
                VotoCircleIconButton(
                  icon: Icons.tune_rounded,
                  onTap: _scrollToAdvanced,
                ),
              ],
            ),
          ),
          Expanded(
            child: _loadingEvent
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      AppDesignTokens.horizontalPadding,
                      12,
                      AppDesignTokens.horizontalPadding,
                      32,
                    ),
                    child: PremiumCard(
                      margin: EdgeInsets.zero,
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Datos principales',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppDesignTokens.primaryDark,
                            ),
                          ),
                          if (_lockHistoricalFields) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8E1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFFFE082),
                                ),
                              ),
                              child: const Text(
                                'Este evento ya tiene registros de asistencia. '
                                'Para preservar la integridad histórica, algunos '
                                'campos ya no pueden modificarse.',
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6D4C41),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          TextField(
                            controller: _nombreController,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: _premiumInputDec(
                              'Nombre del evento',
                              hint: 'Asamblea general',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _descripcionController,
                            maxLines: 3,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: _premiumInputDec(
                              'Descripción',
                              hint: 'Control de asistencia mensual',
                            ),
                          ),
                          const SizedBox(height: 14),
                          InkWell(
                            onTap: _pickDateOnly,
                            borderRadius: BorderRadius.circular(14),
                            child: InputDecorator(
                              decoration:
                                  _premiumInputDec(
                                    'Fecha',
                                    hint: 'dd/mm/aaaa',
                                  ).copyWith(
                                    suffixIcon: Icon(
                                      Icons.calendar_today_outlined,
                                      color: AppDesignTokens.primary.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                              child: Text(
                                _fechaDMYText(),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: AppDesignTokens.primaryDark,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          InkWell(
                            onTap: _pickStartTime,
                            borderRadius: BorderRadius.circular(14),
                            child: InputDecorator(
                              decoration:
                                  _premiumInputDec(
                                    'Hora inicio',
                                    hint: '09:00',
                                  ).copyWith(
                                    suffixIcon: Icon(
                                      Icons.schedule_rounded,
                                      color: AppDesignTokens.primary.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                              child: Text(
                                _horaInicioText(),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: AppDesignTokens.primaryDark,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _lugarController,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: _premiumInputDec(
                              'Lugar',
                              hint: 'Auditorio principal',
                            ),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: _estadoInicial,
                            decoration: _premiumInputDec('Estado'),
                            items: const [
                              DropdownMenuItem(
                                value: 'programado',
                                child: Text('Programado'),
                              ),
                              DropdownMenuItem(
                                value: 'en_curso',
                                child: Text('En curso'),
                              ),
                              DropdownMenuItem(
                                value: 'finalizado',
                                child: Text('Finalizado'),
                              ),
                            ],
                            onChanged: (_loading || _lockHistoricalFields)
                                ? null
                                : (v) => setState(
                                    () => _estadoInicial = v ?? 'programado',
                                  ),
                          ),
                          const SizedBox(height: 18),
                          _lavenderSwitchRow(
                            label: 'Permitir registro por QR',
                            value: _toggleQrRegistro,
                            onChanged: _loading
                                ? (_) {}
                                : (v) => setState(() => _toggleQrRegistro = v),
                          ),
                          _lavenderSwitchRow(
                            label: 'Permitir registro manual',
                            value: _toggleManualRegistro,
                            onChanged: _loading
                                ? (_) {}
                                : (v) =>
                                      setState(() => _toggleManualRegistro = v),
                          ),
                          _lavenderSwitchRow(
                            label: 'Bloquear duplicados',
                            value: _toggleBloquearDuplicados,
                            onChanged: _loading
                                ? (_) {}
                                : (v) => setState(
                                    () => _toggleBloquearDuplicados = v,
                                  ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Los interruptores reflejan la configuración deseada; el '
                            'comportamiento efectivo de QR/manual sigue las pantallas de '
                            'registro. Los duplicados ya se bloquean al registrar en Firestore.',
                            style: AppDesignTokens.bodyMuted(context),
                          ),
                          const SizedBox(height: 20),
                          if (_loading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          else
                            FilledButton(
                              onPressed: _guardar,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppDesignTokens.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                _isEditMode
                                    ? 'Guardar cambios'
                                    : 'Crear evento',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          Divider(
                            height: 1,
                            color: AppDesignTokens.primary.withValues(
                              alpha: 0.12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ExpansionTile(
                            key: _advancedSectionKey,
                            tilePadding: EdgeInsets.zero,
                            title: Text(
                              'Más opciones: convocatoria, tipo y vigencia',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppDesignTokens.primaryDark,
                              ),
                            ),
                            subtitle: Text(
                              'Tipo de reunión, modalidades excluidas y fin de vigencia',
                              style: AppDesignTokens.bodyMuted(context),
                            ),
                            childrenPadding: const EdgeInsets.only(bottom: 12),
                            children: [
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Convocatoria'),
                                subtitle: Text(
                                  _convocatoriaTodosActivos
                                      ? 'Todos los socios activos'
                                      : 'Lista personalizada (${_miembrosConvocadosIds.length})',
                                ),
                                value: _convocatoriaTodosActivos,
                                onChanged: (v) => setState(() {
                                  _convocatoriaTodosActivos = v;
                                  if (v) _miembrosConvocadosIds.clear();
                                }),
                              ),
                              if (!_convocatoriaTodosActivos)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: OutlinedButton.icon(
                                    onPressed: _abrirSeleccionConvocados,
                                    icon: const Icon(Icons.group_add_outlined),
                                    label: Text(
                                      _miembrosConvocadosIds.isEmpty
                                          ? 'Elegir convocados'
                                          : 'Editar convocados (${_miembrosConvocadosIds.length})',
                                    ),
                                  ),
                                ),
                              Text('Tipo', style: theme.textTheme.labelLarge),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilterChip(
                                    label: const Text('Ordinaria'),
                                    selected:
                                        _tipoCrear ==
                                        _TipoCrearEvento.ordinaria,
                                    onSelected: (_) => setState(
                                      () => _tipoCrear =
                                          _TipoCrearEvento.ordinaria,
                                    ),
                                  ),
                                  FilterChip(
                                    label: const Text('Extraordinaria'),
                                    selected:
                                        _tipoCrear ==
                                        _TipoCrearEvento.extraordinaria,
                                    onSelected: (_) => setState(
                                      () => _tipoCrear =
                                          _TipoCrearEvento.extraordinaria,
                                    ),
                                  ),
                                  FilterChip(
                                    label: const Text('Escribir…'),
                                    selected:
                                        _tipoCrear == _TipoCrearEvento.escribir,
                                    onSelected: (_) => setState(
                                      () => _tipoCrear =
                                          _TipoCrearEvento.escribir,
                                    ),
                                  ),
                                ],
                              ),
                              if (_tipoCrear == _TipoCrearEvento.escribir) ...[
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _tipoCustomController,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  decoration: _premiumInputDec(
                                    'Tipo personalizado',
                                    hint: 'Ej.: reunión de delegados',
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              Text(
                                'Modalidades no convocadas',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Marca las modalidades que no aplican a esta convocatoria.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _CrearAttendanceInfoBox(
                                icon: Icons.info_outline,
                                color: Colors.blue,
                                text:
                                    'Solo las modalidades marcadas quedan fuera del cómputo de convocatoria.',
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: Modalidad
                                    .valoresParaJustificacionAsistencia
                                    .map((modalidad) {
                                      final selected = _modalidadesNoConvocadas
                                          .contains(modalidad);
                                      return FilterChip(
                                        selected: selected,
                                        avatar: selected
                                            ? const Icon(Icons.check, size: 18)
                                            : null,
                                        label: Text(
                                          JustificacionHelper.etiquetaModalidad(
                                            modalidad,
                                          ),
                                        ),
                                        onSelected: (checked) {
                                          setState(() {
                                            if (checked) {
                                              _modalidadesNoConvocadas.add(
                                                modalidad,
                                              );
                                            } else {
                                              _modalidadesNoConvocadas.remove(
                                                modalidad,
                                              );
                                            }
                                          });
                                        },
                                      );
                                    })
                                    .toList(),
                              ),
                              const SizedBox(height: 8),
                              _CrearAttendanceInfoBox(
                                icon: Icons.rule,
                                color: _modalidadesNoConvocadas.isEmpty
                                    ? Colors.orange
                                    : Colors.green,
                                text: _modalidadesNoConvocadas.isEmpty
                                    ? 'Sin exclusiones: todas las modalidades entran en la convocatoria según la lista de socios.'
                                    : 'No convocadas: ${_modalidadesNoConvocadas.map(JustificacionHelper.etiquetaModalidad).join(', ')}.',
                              ),
                              const SizedBox(height: 12),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                title: const Text(
                                  'Fecha y hora de fin de vigencia',
                                ),
                                subtitle: Text(
                                  '${_fechaFin.day}/${_fechaFin.month}/${_fechaFin.year} '
                                  '${_fechaFin.hour.toString().padLeft(2, '0')}:'
                                  '${_fechaFin.minute.toString().padLeft(2, '0')}',
                                ),
                                trailing: Icon(
                                  Icons.event_available_outlined,
                                  color: AppDesignTokens.primary,
                                ),
                                onTap: _pickFechaFin,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'El evento permanece vigente para vínculos (p. ej. elecciones) '
                                'mientras esté activo y no haya pasado la fecha de fin.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SeleccionConvocadosSheet extends StatefulWidget {
  const _SeleccionConvocadosSheet({required this.initial});

  final Set<String> initial;

  @override
  State<_SeleccionConvocadosSheet> createState() =>
      _SeleccionConvocadosSheetState();
}

class _SeleccionConvocadosSheetState extends State<_SeleccionConvocadosSheet> {
  final MembersService _membersService = MembersService();
  final TextEditingController _filtro = TextEditingController();

  late Set<String> _seleccion;

  @override
  void initState() {
    super.initState();
    _seleccion = {...widget.initial};
    _filtro.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _filtro.dispose();
    super.dispose();
  }

  void _marcarTodos(Iterable<String> ids, bool seleccionar) {
    setState(() {
      for (final id in ids) {
        if (seleccionar) {
          _seleccion.add(id);
        } else {
          _seleccion.remove(id);
        }
      }
    });
  }

  List<Member> _filtrar(List<Member> members) {
    final q = _filtro.text.trim().toLowerCase();
    if (q.isEmpty) return members;
    return members.where((m) {
      return m.fullName.toLowerCase().contains(q) ||
          m.memberNumber.toLowerCase().contains(q) ||
          (m.workerCode?.toLowerCase().contains(q) ?? false) ||
          (m.documentId?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppBar(
          title: const Text('Convocados'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, _seleccion),
              child: const Text('Listo'),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _filtro,
            decoration: const InputDecoration(
              hintText: 'Buscar nombre, número, trabajador, documento…',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        StreamBuilder<List<Member>>(
          stream: _membersService.getAllMembers(status: MemberStatus.active),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Expanded(
                child: Center(child: Text('Error: ${snapshot.error}')),
              );
            }
            if (!snapshot.hasData) {
              return const Expanded(
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final visibles = _filtrar(snapshot.data!);
            final todosIds = visibles.map((m) => m.id).toList();
            return Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: todosIds.isEmpty
                              ? null
                              : () => _marcarTodos(todosIds, true),
                          child: const Text('Seleccionar visibles'),
                        ),
                        TextButton(
                          onPressed: todosIds.isEmpty
                              ? null
                              : () => _marcarTodos(todosIds, false),
                          child: const Text('Limpiar visibles'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: visibles.length,
                      itemBuilder: (context, i) {
                        final m = visibles[i];
                        final marca = _seleccion.contains(m.id);
                        return CheckboxListTile(
                          value: marca,
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _seleccion.add(m.id);
                            } else {
                              _seleccion.remove(m.id);
                            }
                          }),
                          secondary: CircleAvatar(
                            child: Text(
                              m.firstName.isNotEmpty
                                  ? m.firstName[0].toUpperCase()
                                  : '?',
                            ),
                          ),
                          title: Text(m.fullName),
                          subtitle: Text(
                            '${m.memberNumber}'
                            '${m.workerCode?.isNotEmpty == true ? ' · ${m.workerCode}' : ''}',
                          ),
                        );
                      },
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${_seleccion.length} seleccionados'),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, _seleccion),
                            child: const Text('Confirmar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CrearAttendanceInfoBox extends StatelessWidget {
  const _CrearAttendanceInfoBox({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
