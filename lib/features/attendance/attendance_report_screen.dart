import 'package:flutter/material.dart';
import '../../core/models/member.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../services/attendance_service.dart';

/// Pantalla de reporte de asistencia con cálculo automático de faltas
class AttendanceReportScreen extends StatefulWidget {
  final String eventId;

  const AttendanceReportScreen({super.key, required this.eventId});

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  final AttendanceService _service = AttendanceService();

  bool _isLoading = true;
  AttendanceReport? _report;
  String? _error;
  bool _showAbsentees = false; // Toggle para mostrar solo faltantes

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final report = await _service.generateAttendanceReport(widget.eventId);
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ProfessionalAppBar(
        title: 'Reporte de Asistencia',
        onNavigateBack: () => Navigator.pop(context),
        actions: [
          if (_report != null)
            IconButton(
              icon: Icon(
                _showAbsentees ? Icons.visibility : Icons.visibility_off,
              ),
              tooltip: _showAbsentees
                  ? 'Mostrar todos'
                  : 'Mostrar solo faltantes',
              onPressed: () {
                setState(() => _showAbsentees = !_showAbsentees);
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[700]),
              const SizedBox(height: 16),
              Text(
                'Error al cargar reporte',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadReport,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_report == null) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Información del evento
          _buildEventInfoCard(),

          const SizedBox(height: 16),

          // Estadísticas
          _buildStatisticsCard(),

          const SizedBox(height: 16),

          // Gráfico de asistencia
          _buildAttendanceChart(),

          const SizedBox(height: 16),

          // Lista de asistentes/faltantes
          _buildMembersList(),
        ],
      ),
    );
  }

  Widget _buildEventInfoCard() {
    final event = _report!.event;
    final fecha = DateTime.fromMillisecondsSinceEpoch(event.fecha);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.nombre,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text('${fecha.day}/${fecha.month}/${fecha.year}'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(event.lugar),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.category, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(event.tipo.toUpperCase()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estadísticas',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatBox(
                    'Convocados',
                    '${_report!.totalConvoked}',
                    Colors.blue,
                    Icons.people,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatBox(
                    'Presentes',
                    '${_report!.totalPresent}',
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatBox(
                    'Faltantes',
                    '${_report!.totalAbsent}',
                    Colors.red,
                    Icons.cancel,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tasa de Asistencia',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _report!.attendanceRate / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                _getAttendanceColor(_report!.attendanceRate),
              ),
              minHeight: 24,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_report!.attendanceRate.toStringAsFixed(1)}% asistieron',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getAttendanceColor(_report!.attendanceRate),
                  ),
                ),
                Text(
                  '${_report!.absenceRate.toStringAsFixed(1)}% faltaron',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getAttendanceColor(double rate) {
    if (rate >= 80) return Colors.green;
    if (rate >= 60) return Colors.orange;
    return Colors.red;
  }

  Widget _buildMembersList() {
    final membersToShow = _showAbsentees
        ? _report!.absentMembers
        : _report!.presentMembers + _report!.absentMembers;

    if (membersToShow.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(
                  _showAbsentees ? Icons.check_circle : Icons.people_outline,
                  size: 48,
                  color: Colors.grey,
                ),
                const SizedBox(height: 12),
                Text(
                  _showAbsentees ? '¡Todos asistieron! 🎉' : 'No hay registros',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _showAbsentees
                  ? 'Faltantes (${membersToShow.length})'
                  : 'Lista Completa (${membersToShow.length})',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: membersToShow.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final member = membersToShow[index];
              final isAbsent = _report!.absentMembers.contains(member);

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isAbsent ? Colors.red : Colors.green,
                  child: Text(
                    member.firstName.isNotEmpty
                        ? member.firstName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(
                  member.fullName,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isAbsent ? Colors.red[700] : null,
                  ),
                ),
                subtitle: Text('N° Socio: ${member.memberNumber}'),
                trailing: isAbsent
                    ? const Icon(Icons.cancel, color: Colors.red)
                    : const Icon(Icons.check_circle, color: Colors.green),
              );
            },
          ),
        ],
      ),
    );
  }
}
