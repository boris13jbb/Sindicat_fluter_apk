import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/utils/qr_encoding_helper.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
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
  final MembersService _membersService = MembersService();
  
  // Datos del socio actual (si existe)
  dynamic _currentMember;
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
        debugPrint('❌ UserProfile: Usuario no autenticado');
        if (mounted) {
          setState(() => _isLoadingMember = false);
        }
        return;
      }

      debugPrint('🔍 UserProfile: Iniciando búsqueda de socio...');
      debugPrint('   Datos del usuario autenticado:');
      debugPrint('   - ID: ${user.id}');
      debugPrint('   - Email: ${user.email}');
      debugPrint('   - EmployeeNumber: ${user.employeeNumber ?? "N/A"}');
      debugPrint('   - DisplayName: ${user.displayName ?? "N/A"}');
      
      dynamic foundMember;
      String searchMethod = 'ninguno';

      // ESTRATEGIA 1: Buscar por email del usuario (búsqueda parcial)
      if (user.email.isNotEmpty) {
        debugPrint('\n📧 Estrategia 1: Búsqueda por email...');
        try {
          final membersByEmail = await _membersService.searchMembers(user.email);
          debugPrint('   Resultados de searchMembers: ${membersByEmail.length} encontrados');
          if (membersByEmail.isNotEmpty) {
            foundMember = membersByEmail.first;
            searchMethod = 'email';
            debugPrint('   ✅ Encontrado por email: ${foundMember.fullName}');
            debugPrint('      Email del miembro: ${foundMember.email ?? "N/A"}');
          }
        } catch (e) {
          debugPrint('   ❌ Error en búsqueda por email: $e');
        }
      }

      // ESTRATEGIA 2: Buscar por employeeNumber/workerCode
      if (foundMember == null && 
          user.employeeNumber != null && 
          user.employeeNumber!.isNotEmpty) {
        debugPrint('\n🔢 Estrategia 2: Búsqueda por employeeNumber...');
        try {
          final memberByWorkerCode = await _membersService.getMemberByWorkerCode(user.employeeNumber!);
          if (memberByWorkerCode != null) {
            foundMember = memberByWorkerCode;
            searchMethod = 'employeeNumber';
            debugPrint('   ✅ Encontrado por employeeNumber: ${foundMember.fullName}');
            debugPrint('      WorkerCode del miembro: ${foundMember.workerCode ?? "N/A"}');
          } else {
            debugPrint('   ❌ No se encontró miembro con workerCode=${user.employeeNumber}');
          }
        } catch (e) {
          debugPrint('   ❌ Error en búsqueda por employeeNumber: $e');
        }
      }

      // ESTRATEGIA 3: Buscar por ID del usuario como documentId
      if (foundMember == null) {
        debugPrint('\n🆔 Estrategia 3: Búsqueda por userId como documentId...');
        try {
          final memberByDoc = await _membersService.getMemberByDocument(user.id);
          if (memberByDoc != null) {
            foundMember = memberByDoc;
            searchMethod = 'userId';
            debugPrint('   ✅ Encontrado por userId: ${foundMember.fullName}');
            debugPrint('      DocumentId del miembro: ${foundMember.documentId ?? "N/A"}');
          } else {
            debugPrint('   ❌ No se encontró miembro con documentId=${user.id}');
          }
        } catch (e) {
          debugPrint('   ❌ Error en búsqueda por documentId: $e');
        }
      }

      // ESTRATEGIA 4: Escaneo completo de TODOS los miembros (con logging detallado)
      if (foundMember == null) {
        debugPrint('\n🔎 Estrategia 4: Escaneo completo de miembros...');
        try {
          final allMembersStream = _membersService.getActiveMembers();
          final allMembers = await allMembersStream.first;
          
          debugPrint('   Total miembros activos en Firestore: ${allMembers.length}');
          
          if (allMembers.isEmpty) {
            debugPrint('   ⚠️ NO HAY MIEMBROS ACTIVOS en la base de datos');
          } else {
            // Mostrar primeros 5 miembros para diagnóstico
            debugPrint('\n   📋 Primeros 5 miembros activos:');
            for (var i = 0; i < allMembers.length && i < 5; i++) {
              final m = allMembers[i];
              debugPrint('   [$i] ${m.fullName}');
              debugPrint('       - workerCode: ${m.workerCode ?? "N/A"}');
              debugPrint('       - documentId: ${m.documentId ?? "N/A"}');
              debugPrint('       - email: ${m.email ?? "N/A"}');
              debugPrint('       - memberNumber: ${m.memberNumber}');
            }
            if (allMembers.length > 5) {
              debugPrint('   ... y ${allMembers.length - 5} más');
            }
            
            // Buscar por email (comparación case-insensitive)
            debugPrint('\n   🔍 Buscando coincidencias de email...');
            for (final member in allMembers) {
              if (member.email != null && member.email!.isNotEmpty) {
                final memberEmail = member.email!.toLowerCase().trim();
                final userEmail = user.email.toLowerCase().trim();
                
                if (memberEmail == userEmail) {
                  foundMember = member;
                  searchMethod = 'email_exact';
                  debugPrint('   ✅ COINCIDENCIA EXACTA de email encontrada!');
                  debugPrint('      Email usuario: "$userEmail"');
                  debugPrint('      Email miembro: "$memberEmail"');
                  break;
                } else if (memberEmail.contains(userEmail) || userEmail.contains(memberEmail)) {
                  debugPrint('   ⚠️ Coincidencia PARCIAL de email (no usada):');
                  debugPrint('      Usuario: "$userEmail" vs Miembro: "$memberEmail"');
                }
              }
            }
            
            // Buscar por employeeNumber/workerCode
            if (foundMember == null && user.employeeNumber != null && user.employeeNumber!.isNotEmpty) {
              debugPrint('\n   🔍 Buscando coincidencias de employeeNumber...');
              final userEmpNum = user.employeeNumber!.toLowerCase().trim();
              
              for (final member in allMembers) {
                // Comparar con workerCode
                if (member.workerCode != null && member.workerCode!.isNotEmpty) {
                  final workerCode = member.workerCode!.toLowerCase().trim();
                  if (workerCode == userEmpNum) {
                    foundMember = member;
                    searchMethod = 'workerCode_exact';
                    debugPrint('   ✅ COINCIDENCIA EXACTA de workerCode encontrada!');
                    debugPrint('      User employeeNumber: "$userEmpNum"');
                    debugPrint('      Member workerCode: "$workerCode"');
                    break;
                  }
                }
                
                // Comparar con documentId
                if (member.documentId != null && member.documentId!.isNotEmpty) {
                  final docId = member.documentId!.toLowerCase().trim();
                  if (docId == userEmpNum) {
                    foundMember = member;
                    searchMethod = 'documentId_exact';
                    debugPrint('   ✅ COINCIDENCIA EXACTA de documentId encontrada!');
                    debugPrint('      User employeeNumber: "$userEmpNum"');
                    debugPrint('      Member documentId: "$docId"');
                    break;
                  }
                }
              }
            }
            
            // ESTRATEGIA 5: Búsqueda por nombre (si displayName existe)
            if (foundMember == null && user.displayName != null && user.displayName!.isNotEmpty) {
              debugPrint('\n   👤 Estrategia 5: Búsqueda por nombre/displayName...');
              final userName = user.displayName!.toLowerCase().trim();
              
              for (final member in allMembers) {
                final memberFullName = member.fullName.toLowerCase().trim();
                final memberFirstName = member.firstName.toLowerCase().trim();
                
                // Coincidencia exacta del nombre completo
                if (memberFullName == userName) {
                  foundMember = member;
                  searchMethod = 'fullName_exact';
                  debugPrint('   ✅ COINCIDENCIA EXACTA de nombre completo!');
                  debugPrint('      User displayName: "$userName"');
                  debugPrint('      Member fullName: "$memberFullName"');
                  break;
                }
                
                // Coincidencia parcial: el nombre del usuario está contenido en el nombre del miembro
                if (memberFullName.contains(userName) || userName.contains(memberFirstName)) {
                  debugPrint('   ⚠️ Coincidencia PARCIAL de nombre detectada (no usada automáticamente):');
                  debugPrint('      User: "$userName"');
                  debugPrint('      Member: "$memberFullName"');
                  debugPrint('      💡 Si este es tu socio, verifica que el email o workerCode coincidan');
                }
              }
            }
          }
        } catch (e, stackTrace) {
          debugPrint('   ❌ Error en escaneo completo: $e');
          debugPrint('   Stack: $stackTrace');
        }
      }

      // RESULTADO FINAL
      debugPrint('\n${'=' * 60}');
      if (foundMember != null) {
        debugPrint('✅ RESULTADO: Socio encontrado vía "$searchMethod"');
        debugPrint('   Nombre completo: ${foundMember.fullName}');
        debugPrint('   memberNumber: ${foundMember.memberNumber}');
        debugPrint('   workerCode: ${foundMember.workerCode ?? "N/A"}');
        debugPrint('   documentId: ${foundMember.documentId ?? "N/A"}');
        debugPrint('   email: ${foundMember.email ?? "N/A"}');
        debugPrint('   status: ${foundMember.status.displayName}');
        debugPrint('=' * 60 + '\n');
      } else {
        debugPrint('❌ RESULTADO: NO SE ENCONTRÓ SOCIO');
        debugPrint('   Se intentaron 5 estrategias de búsqueda:');
        debugPrint('   1. Búsqueda por email (searchMembers)');
        debugPrint('   2. Búsqueda por employeeNumber/workerCode');
        debugPrint('   3. Búsqueda por userId como documentId');
        debugPrint('   4. Escaneo completo con comparación exacta (email, workerCode, documentId)');
        debugPrint('   5. Búsqueda por nombre/displayName');
        debugPrint('\n   Datos del usuario que se usaron para buscar:');
        debugPrint('   - Email: "${user.email}"');
        debugPrint('   - EmployeeNumber: "${user.employeeNumber ?? "N/A"}"');
        debugPrint('   - UserID: "${user.id}"');
        debugPrint('   - DisplayName: "${user.displayName ?? "N/A"}"');
        debugPrint('\n   💡 Posibles causas:');
        debugPrint('   1. El usuario no ha sido importado como socio aún');
        debugPrint('   2. El email del usuario no coincide con el email del socio importado');
        debugPrint('   3. El employeeNumber del usuario no coincide con workerCode del socio');
        debugPrint('   4. El campo email está vacío en el registro del socio importado');
        debugPrint('   5. El displayName del usuario no coincide con fullName del socio');
        debugPrint('   6. El socio existe pero está marcado como inactivo');
        debugPrint('=' * 60 + '\n');
      }

      // Actualizar estado de la UI
      if (mounted) {
        setState(() {
          _currentMember = foundMember;
          _isLoadingMember = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error fatal cargando miembro: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isLoadingMember = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Provider.of<AuthProvider>(context, listen: false).signOut();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Información'),
            Tab(icon: Icon(Icons.qr_code), text: 'Código QR'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInfoTab(),
          _buildQRCodeTab(),
        ],
      ),
    );
  }

  /// Pestaña de Información del Usuario
  Widget _buildInfoTab() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;
        if (user == null) {
          return const Center(child: Text('No hay usuario autenticado'));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    (user.displayName?.isNotEmpty ?? false)
                        ? user.displayName![0].toUpperCase()
                        : user.email[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Información básica
              _buildInfoCard(context, 'Información de Cuenta', [
                _buildInfoRow('Email', user.email),
                if (user.displayName != null && user.displayName!.isNotEmpty)
                  _buildInfoRow('Nombre', user.displayName!),
                _buildInfoRow('Rol', user.role.displayName),
                if (user.employeeNumber != null && user.employeeNumber!.isNotEmpty)
                  _buildInfoRow('N° Empleado', user.employeeNumber!),
              ]),

              const SizedBox(height: 16),

              // Información de socio (si existe)
              if (_isLoadingMember)
                const Center(child: CircularProgressIndicator())
              else if (_currentMember != null)
                _buildInfoCard(context, 'Información de Socio', [
                  _buildInfoRow('Nombre Completo', _currentMember.fullName),
                  _buildInfoRow('N° Socio', _currentMember.memberNumber),
                  if (_currentMember.workerCode != null)
                    _buildInfoRow('Código Trabajador', _currentMember.workerCode),
                  if (_currentMember.documentId != null)
                    _buildInfoRow('Cédula', _currentMember.documentId),
                  _buildInfoRow('Estado', _currentMember.status.displayName),
                ]),
            ],
          ),
        );
      },
    );
  }

  /// Pestaña de Código QR
  Widget _buildQRCodeTab() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;
        if (user == null) {
          return const Center(child: Text('No hay usuario autenticado'));
        }

        // Si no hay socio encontrado, mostrar mensaje detallado
        if (!_isLoadingMember && _currentMember == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.qr_code_2,
                    size: 80,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Código QR no disponible',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Posibles causas:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Tu email no coincide con el registrado en el sistema\n'
                          '• Falta el campo workerCode en tu registro\n'
                          '• Aún no has sido importado como socio',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Contacta al administrador para verificar tu registro.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Si hay socio, mostrar su código QR
        if (_currentMember != null) {
          // Verificar que workerCode existe antes de generar QR
          if (_currentMember!.workerCode == null || _currentMember!.workerCode!.isEmpty) {
            debugPrint('⚠️ Socio encontrado pero sin workerCode:');
            debugPrint('   Member ID: ${_currentMember!.id}');
            debugPrint('   Nombre: ${_currentMember!.fullName}');
            debugPrint('   Email: ${_currentMember!.email ?? "N/A"}');
            debugPrint('   workerCode: ${_currentMember!.workerCode ?? "NULO"}');
            debugPrint('   workerCode en DB: "${_currentMember!.workerCode}"');
            debugPrint('   💡 SOLUCIÓN: Actualiza el campo workerCode en Firestore para este socio');
            debugPrint('=' * 60 + '\n');
            
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 64,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Código QR no disponible',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '⚠️ Tu registro de socio está incompleto',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'El campo "workerCode" (Número de Trabajador) es requerido para generar el código QR.\n\n'
                            'Datos detectados:\n'
                            '• Nombre: ${_currentMember!.fullName}\n'
                            '• Email: ${_currentMember!.email ?? "No registrado"}\n'
                            '• workerCode: ${_currentMember!.workerCode?.isNotEmpty == true ? _currentMember!.workerCode : "NO ASIGNADO"}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Contacta al administrador para que actualice tu Número de Trabajador.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          
          // Generar QR de forma segura
          String qrData;
          try {
            qrData = QREncodingHelper.generateMemberQRCode(_currentMember!);
          } catch (e) {
            debugPrint('❌ Error generando QR: $e');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red.shade700,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error generando QR',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.red.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('$e', style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            );
          }
          
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                
                // Tarjeta del código QR
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          'Tu Código QR de Asistencia',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Escanea este código para registrar tu asistencia',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        
                        // Código QR
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                            ),
                          ),
                          child: QrImageView(
                            data: qrData,
                            version: QrVersions.auto,
                            size: 250,
                            gapless: false,
                            eyeStyle: QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            dataModuleStyle: QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            backgroundColor: Colors.white,
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Información del socio
                        Divider(),
                        const SizedBox(height: 16),
                        _buildInfoRow('Nombre', _currentMember.fullName),
                        if (_currentMember.workerCode != null)
                          _buildInfoRow('Código Trabajador', _currentMember.workerCode),
                        if (_currentMember.documentId != null)
                          _buildInfoRow('Cédula', _currentMember.documentId),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Nota informativa
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Este código QR contiene tu información de identificación. Preséntalo al escáner de asistencia para registrar tu presencia en eventos.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Loading state
        return const Center(child: CircularProgressIndicator());
      },
    );
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
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// Widget para tarjeta de información
  Widget _buildInfoCard(BuildContext context, String title, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}
