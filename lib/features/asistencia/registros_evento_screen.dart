import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/design/app_design_tokens.dart';
import '../../core/design/widgets/premium_card.dart';
import '../../core/models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../services/attendance_service.dart';
import '../elections/widgets/voto_premium_chrome.dart';
import 'attendance_event_records_list.dart';

/// Pantalla premium de registros de un evento (`10_asistencia_registros`).
class RegistrosEventoScreen extends StatefulWidget {
  const RegistrosEventoScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<RegistrosEventoScreen> createState() => _RegistrosEventoScreenState();
}

class _RegistrosEventoScreenState extends State<RegistrosEventoScreen> {
  final AttendanceService _attendanceSvc = AttendanceService();
  String _busqueda = '';

  void _mostrarAyuda() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
            children: [
              Text(
                'Registros del evento',
                style: AppDesignTokens.titleLarge(ctx),
              ),
              const SizedBox(height: 12),
              Text(
                'Los contadores Presentes, Ausentes y Avance usan el mismo resumen '
                'operativo que el detalle del evento (convocados frente a asistencias).\n\n'
                'Toca una fila para ver la fecha completa, el método y los datos del padrón.',
                style: AppDesignTokens.bodyMuted(ctx),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final role = auth.user?.role ?? UserRole.user;
    final eventId = widget.eventId;

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: VotoModuleBottomNavigation(
        role: role,
        selection: VotoNavSlot.asistencia,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('attendance_events')
            .doc(eventId)
            .snapshots(),
        builder: (context, evSnap) {
          if (evSnap.hasError) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                VotoWaveHeader(
                  title: 'Asistencias',
                  subtitle: 'Registros del evento',
                  onBack: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Error: ${evSnap.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          if (!evSnap.hasData || !evSnap.data!.exists) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                VotoWaveHeader(
                  title: 'Asistencias',
                  subtitle: 'Registros del evento',
                  onBack: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Cargando evento…'),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          final map = evSnap.data!.data() ?? {};
          final nombreEv = map['nombre'] as String? ?? '(sin nombre)';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              VotoWaveHeader(
                title: 'Asistencias',
                subtitle: 'Registros del evento',
                onBack: () => Navigator.pop(context),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VotoCircleIconButton(
                      icon: Icons.help_outline_rounded,
                      onTap: _mostrarAyuda,
                    ),
                    const SizedBox(width: 6),
                    VotoCircleIconButton(
                      icon: Icons.share_rounded,
                      onTap: () {
                        Share.share(
                          'Asistencias — $nombreEv\n'
                          'ID evento: $eventId',
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    VotoCircleIconButton(
                      icon: Icons.sync_rounded,
                      onTap: () => setState(() {}),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppDesignTokens.horizontalPadding,
                    12,
                    AppDesignTokens.horizontalPadding,
                    12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        nombreEv,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppDesignTokens.titleLarge(
                          context,
                        ).copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<AttendanceHubDashboardData?>(
                        future: _attendanceSvc.buildHubDashboardData(eventId),
                        builder: (context, hubSnap) {
                          final data = hubSnap.data;
                          final loading =
                              hubSnap.connectionState ==
                                  ConnectionState.waiting &&
                              !hubSnap.hasData;
                          return Row(
                            children: [
                              Expanded(
                                child: _RegistroKpiCell(
                                  label: 'Presentes',
                                  value: loading
                                      ? '…'
                                      : data != null
                                      ? '${data.presentes}'
                                      : '—',
                                  valueColor: const Color(0xFF2ECC71),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _RegistroKpiCell(
                                  label: 'Ausentes',
                                  value: loading
                                      ? '…'
                                      : data != null
                                      ? '${data.ausentes}'
                                      : '—',
                                  valueColor: const Color(0xFFE74C3C),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _RegistroKpiCell(
                                  label: 'Avance',
                                  value: loading
                                      ? '…'
                                      : data != null && data.totalConvocados > 0
                                      ? '${data.porcentajePresentes.round()}%'
                                      : '—',
                                  valueColor: const Color(0xFF3498DB),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        onChanged: (v) => setState(() => _busqueda = v),
                        decoration: InputDecoration(
                          hintText: 'Buscar o filtrar registros...',
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: AppDesignTokens.primary.withValues(
                              alpha: 0.65,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: AppDesignTokens.primary.withValues(
                                alpha: 0.12,
                              ),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: AppDesignTokens.primary.withValues(
                                alpha: 0.12,
                              ),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: AppDesignTokens.primary.withValues(
                                alpha: 0.45,
                              ),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Listado',
                        style: AppDesignTokens.titleLarge(context),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: AttendanceEventRecordsList(
                          eventId: eventId,
                          attendanceSvc: _attendanceSvc,
                          searchQuery: _busqueda,
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.paddingOf(context).bottom + 8,
                          ),
                        ),
                      ),
                    ],
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

class _RegistroKpiCell extends StatelessWidget {
  const _RegistroKpiCell({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppDesignTokens.bodyMuted(context),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
