import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import '../../core/models/asistencia/persona.dart';
import '../../core/utils/qr_encoding_helper.dart';
import '../../core/widgets/professional_app_bar.dart';
import '../../services/asistencia_service.dart';

/// Pantalla para ver códigos QR de personas
class QRCodesScreen extends StatefulWidget {
  const QRCodesScreen({super.key});

  @override
  State<QRCodesScreen> createState() => _QRCodesScreenState();
}

class _QRCodesScreenState extends State<QRCodesScreen> {
  final _service = AsistenciaService();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ProfessionalAppBar(
        title: 'Códigos QR de Socios',
        onNavigateBack: () => Navigator.pop(context),
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o número...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          
          // Lista de personas con QRs
          Expanded(
            child: StreamBuilder<List<PersonaAsistencia>>(
              stream: _service.getAllPersonas(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                var personas = snap.data!;
                
                // Filtrar por búsqueda
                if (_searchQuery.isNotEmpty) {
                  final query = _searchQuery.toLowerCase();
                  personas = personas.where((p) {
                    return p.nombreCompleto.toLowerCase().contains(query) ||
                        (p.identificador?.contains(query) ?? false);
                  }).toList();
                }
                
                if (personas.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        _searchQuery.isNotEmpty
                            ? 'No se encontraron resultados'
                            : 'No hay personas registradas\n\nVe a "Importar desde Excel" para agregar personas',
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: personas.length,
                  itemBuilder: (context, index) {
                    final persona = personas[index];
                    return _PersonaQRCard(
                      persona: persona,
                      onDelete: () => setState(() {}),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta con código QR de una persona
class _PersonaQRCard extends StatefulWidget {
  const _PersonaQRCard({
    required this.persona,
    required this.onDelete,
  });
  
  final PersonaAsistencia persona;
  final VoidCallback onDelete;

  @override
  State<_PersonaQRCard> createState() => _PersonaQRCardState();
}

class _PersonaQRCardState extends State<_PersonaQRCard> {
  final _service = AsistenciaService();
  final _qrKey = GlobalKey();

  void _copiarDatos(BuildContext context) {
    final qrData = QREncodingHelper.generateQRCode(widget.persona);
    Clipboard.setData(ClipboardData(text: qrData));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Código copiado al portapapeles'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _compartirQR() async {
    try {
      // Capturar QR usando RepaintBoundary
      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      
      if (boundary == null) {
        throw Exception('No se pudo capturar el QR');
      }
      
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        throw Exception('Error al generar imagen');
      }
      
      final pngBytes = byteData.buffer.asUint8List();
      
      // Guardar archivo temporal
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/qr_${widget.persona.identificador ?? widget.persona.id}.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);
      
      // Compartir
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Código QR - ${widget.persona.nombreCompleto}\nN°: ${widget.persona.identificador}',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ QR compartido'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error al compartir: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _eliminarPersona(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Eliminar Persona'),
        content: Text(
          '¿Estás seguro de eliminar a ${widget.persona.nombreCompleto}?\n\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _service.deletePersona(widget.persona.id);
        if (mounted) {
          widget.onDelete();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${widget.persona.nombreCompleto} eliminado'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _editarPersona(BuildContext context) async {
    final nombresController = TextEditingController(text: widget.persona.nombres);
    final apellidosController = TextEditingController(text: widget.persona.apellidos);
    final identificadorController = TextEditingController(text: widget.persona.identificador ?? '');

    final resultado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('✏️ Editar Persona'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombresController,
                decoration: const InputDecoration(
                  labelText: 'Nombres *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: apellidosController,
                decoration: const InputDecoration(
                  labelText: 'Apellidos *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: identificadorController,
                decoration: const InputDecoration(
                  labelText: 'N° Trabajador *',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (resultado == true) {
      if (nombresController.text.trim().isEmpty || 
          apellidosController.text.trim().isEmpty ||
          identificadorController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Todos los campos son obligatorios'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      try {
        final personaEditada = PersonaAsistencia(
          id: widget.persona.id,
          nombres: nombresController.text.trim(),
          apellidos: apellidosController.text.trim(),
          identificador: identificadorController.text.trim(),
        );

        await _service.updatePersona(personaEditada);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${personaEditada.nombreCompleto} actualizado'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    nombresController.dispose();
    apellidosController.dispose();
    identificadorController.dispose();
  }

  void _mostrarDetalles(BuildContext context) {
    final qrData = QREncodingHelper.generateQRCode(widget.persona);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Código QR'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // QR grande
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: QrImageView(
                  data: qrData,
                  size: 250,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              // Datos
              Text(
                widget.persona.nombreCompleto,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'N°: ${widget.persona.identificador ?? 'Sin número'}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              // Formato del código
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  qrData,
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qrData = QREncodingHelper.generateQRCode(widget.persona);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Código QR
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: QrImageView(
                  data: qrData,
                  size: 100,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Información
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.persona.nombreCompleto,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'N°: ${widget.persona.identificador ?? 'Sin número'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Botones de acción - Sin overflow
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    alignment: WrapAlignment.start,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _mostrarDetalles(context),
                        icon: const Icon(Icons.qr_code, size: 16),
                        label: const Text('Ver'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: const Size(0, 32),
                        ),
                      ),
                      IconButton(
                        onPressed: _compartirQR,
                        icon: const Icon(Icons.share, size: 18),
                        tooltip: 'Compartir QR',
                        color: Colors.blue,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _editarPersona(context),
                        icon: const Icon(Icons.edit, size: 18),
                        tooltip: 'Editar',
                        color: Colors.orange,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _eliminarPersona(context),
                        icon: const Icon(Icons.delete, size: 18),
                        tooltip: 'Eliminar',
                        color: Colors.red,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
