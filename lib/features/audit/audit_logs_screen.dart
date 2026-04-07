import 'package:flutter/material.dart';
import '../../core/models/audit_log.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../services/audit_service.dart';

/// Pantalla de visualización de logs de auditoría
class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  final AuditService _service = AuditService();

  AuditAction? _actionFilter;
  AuditEntityType? _entityTypeFilter;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ProfessionalAppBar(
        title: 'Registro de Auditoría',
        onNavigateBack: () => Navigator.pop(context),
        actions: [
          // Filtros
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFiltersDialog,
            tooltip: 'Filtros',
          ),
          // Limpiar filtros
          if (_hasActiveFilters())
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _clearFilters,
              tooltip: 'Limpiar filtros',
            ),
        ],
      ),
      body: StreamBuilder<List<AuditLog>>(
        stream: _service.getAuditLogs(
          action: _actionFilter,
          entityType: _entityTypeFilter,
          startDate: _startDate,
          endDate: _endDate,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[700]),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar logs',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(snapshot.error.toString()),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final logs = snapshot.data!;

          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No hay registros de auditoría',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_hasActiveFilters()) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Intenta ajustar los filtros',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return _AuditLogCard(log: log);
            },
          );
        },
      ),
    );
  }

  bool _hasActiveFilters() {
    return _actionFilter != null ||
        _entityTypeFilter != null ||
        _startDate != null ||
        _endDate != null;
  }

  void _clearFilters() {
    setState(() {
      _actionFilter = null;
      _entityTypeFilter = null;
      _startDate = null;
      _endDate = null;
    });
  }

  Future<void> _showFiltersDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtros'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filtro por acción
              DropdownButtonFormField<AuditAction?>(
                value: _actionFilter,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Acción',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todas')),
                  ...AuditAction.values.map((action) {
                    return DropdownMenuItem(
                      value: action,
                      child: Text(action.displayName),
                    );
                  }),
                ],
                onChanged: (value) => setState(() => _actionFilter = value),
              ),
              const SizedBox(height: 16),

              // Filtro por tipo de entidad
              DropdownButtonFormField<AuditEntityType?>(
                value: _entityTypeFilter,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Entidad',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todas')),
                  ...AuditEntityType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.displayName),
                    );
                  }),
                ],
                onChanged: (value) => setState(() => _entityTypeFilter = value),
              ),
              const SizedBox(height: 16),

              // Filtro por fecha inicio
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _startDate != null
                      ? 'Desde: ${_formatDate(_startDate!)}'
                      : 'Fecha inicial',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _startDate = date);
                  }
                },
              ),

              // Filtro por fecha fin
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _endDate != null
                      ? 'Hasta: ${_formatDate(_endDate!)}'
                      : 'Fecha final',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() => _endDate = date);
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _clearFilters();
              Navigator.pop(context);
            },
            child: const Text('Limpiar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ==================== WIDGET DE TARJETA DE LOG ====================

class _AuditLogCard extends StatelessWidget {
  final AuditLog log;

  const _AuditLogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con acción y timestamp
            Row(
              children: [
                Icon(
                  _getActionIcon(log.action),
                  color: _getActionColor(log.action),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    log.action.displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _getActionColor(log.action),
                    ),
                  ),
                ),
                Text(
                  _formatTimestamp(log.timestamp),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),

            const Divider(height: 24),

            // Descripción
            if (log.description != null) ...[
              Text(log.description!, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
            ],

            // Detalles
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    'Entidad',
                    '${log.entityType.displayName}: ${log.entityId.substring(0, log.entityId.length > 8 ? 8 : log.entityId.length)}...',
                  ),
                ),
                Expanded(
                  child: _buildDetailItem(
                    'Usuario',
                    log.userName ?? log.userId.substring(0, 8),
                  ),
                ),
              ],
            ),

            // Cambios (si existen)
            if (log.changes != null && log.changes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Cambios:',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  log.changes.toString(),
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ],

            // Platform badge
            if (log.platform != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Text(
                  log.platform!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  IconData _getActionIcon(AuditAction action) {
    switch (action) {
      case AuditAction.create:
        return Icons.add_circle_outline;
      case AuditAction.update:
        return Icons.edit_outlined;
      case AuditAction.delete:
        return Icons.delete_outline;
      case AuditAction.vote:
        return Icons.how_to_vote;
      case AuditAction.import_:
        return Icons.upload_file;
      case AuditAction.login:
        return Icons.login;
      case AuditAction.logout:
        return Icons.logout;
      case AuditAction.attendance:
        return Icons.event_available;
    }
  }

  Color _getActionColor(AuditAction action) {
    switch (action) {
      case AuditAction.create:
        return Colors.green;
      case AuditAction.update:
        return Colors.blue;
      case AuditAction.delete:
        return Colors.red;
      case AuditAction.vote:
        return Colors.purple;
      case AuditAction.import_:
        return Colors.orange;
      case AuditAction.login:
        return Colors.teal;
      case AuditAction.logout:
        return Colors.grey;
      case AuditAction.attendance:
        return Colors.indigo;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Ahora';
    } else if (diff.inHours < 1) {
      return 'hace ${diff.inMinutes}m';
    } else if (diff.inDays < 1) {
      return 'hace ${diff.inHours}h';
    } else if (diff.inDays < 7) {
      return 'hace ${diff.inDays}d';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}
