import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Script para actualizar miembros que no tienen workerCode
/// 
/// PROBLEMA: Socios creados manualmente desde la app no tienen el campo
/// workerCode, lo cual es necesario para:
/// - Generación de códigos QR
/// - Elegibilidad de votación por asistencia
/// - Búsqueda en el sistema de asistencia
///
/// SOLUCIÓN: Este script actualiza todos los miembros sin workerCode
/// usando su memberNumber como valor por defecto.
///
/// USO: Ejecutar como script independiente o integrar en una función temporal
/// en la app para que superadmin lo ejecute una vez.
class FixMissingWorkerCodeScript {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Ejecutar la corrección de workerCode faltante
  Future<void> run() async {
    debugPrint('=' * 60);
    debugPrint('🔧 INICIANDO CORRECCIÓN DE WORKERCODE FALTANTE');
    debugPrint('=' * 60);

    try {
      // 1. Obtener todos los miembros
      debugPrint('\n📊 Paso 1: Obteniendo todos los miembros...');
      final membersSnapshot = await _firestore.collection('members').get();
      debugPrint('   Total miembros encontrados: ${membersSnapshot.docs.length}');

      if (membersSnapshot.docs.isEmpty) {
        debugPrint('   ⚠️ No hay miembros en la base de datos');
        return;
      }

      // 2. Identificar miembros sin workerCode
      debugPrint('\n🔍 Paso 2: Identificando miembros sin workerCode...');
      final membersToUpdate = <Map<String, dynamic>>[];

      for (final doc in membersSnapshot.docs) {
        final data = doc.data();
        final workerCode = data['workerCode'];
        final memberNumber = data['memberNumber'];
        final fullName = data['fullName'] ?? 'N/A';

        if (workerCode == null || workerCode.toString().isEmpty) {
          debugPrint('   ❌ SIN WORKERCODE: $fullName (${doc.id})');
          debugPrint('      memberNumber: $memberNumber');
          
          // Preparar actualización
          membersToUpdate.add({
            'id': doc.id,
            'workerCode': memberNumber, // Usar memberNumber como fallback
            'fullName': fullName,
            'memberNumber': memberNumber,
          });
        } else {
          debugPrint('   ✅ CON WORKERCODE: $fullName - workerCode: $workerCode');
        }
      }

      debugPrint('\n📝 Total miembros a actualizar: ${membersToUpdate.length}');

      if (membersToUpdate.isEmpty) {
        debugPrint('   ✅ Todos los miembros ya tienen workerCode');
        return;
      }

      // 3. Actualizar miembros sin workerCode
      debugPrint('\n💾 Paso 3: Actualizando miembros...');
      int successCount = 0;
      int errorCount = 0;

      for (final member in membersToUpdate) {
        try {
          debugPrint(
            '   📝 Actualizando: ${member['fullName']} (${member['id']})',
          );
          debugPrint(
            '      workerCode: ${member['memberNumber']} (usando memberNumber)',
          );

          await _firestore.collection('members').doc(member['id']).update({
            'workerCode': member['workerCode'],
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          });

          successCount++;
          debugPrint('      ✅ Actualizado correctamente');
        } catch (e) {
          errorCount++;
          debugPrint('      ❌ Error: $e');
        }
      }

      // 4. Resumen final
      debugPrint('\n' + '=' * 60);
      debugPrint('📊 RESUMEN DE EJECUCIÓN');
      debugPrint('=' * 60);
      debugPrint('   Total miembros procesados: ${membersSnapshot.docs.length}');
      debugPrint('   Miembros actualizados: $successCount');
      debugPrint('   Errores: $errorCount');
      debugPrint('   Miembros ya correctos: ${membersSnapshot.docs.length - membersToUpdate.length}');
      debugPrint('=' * 60);

      if (errorCount > 0) {
        debugPrint('⚠️ Hubo $errorCount errores durante la actualización');
      } else {
        debugPrint('✅ ¡Todas las actualizaciones completadas exitosamente!');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ ERROR FATAL: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Ejecutar solo para un miembro específico (útil para debugging)
  Future<void> runForMember(String memberId) async {
    debugPrint('\n🔧 Corrigiendo miembro: $memberId');

    try {
      final doc = await _firestore.collection('members').doc(memberId).get();
      
      if (!doc.exists) {
        debugPrint('   ❌ Miembro no encontrado');
        return;
      }

      final data = doc.data()!;
      final workerCode = data['workerCode'];
      final memberNumber = data['memberNumber'];
      final fullName = data['fullName'] ?? 'N/A';

      if (workerCode != null && workerCode.toString().isNotEmpty) {
        debugPrint('   ✅ Miembro ya tiene workerCode: $workerCode');
        return;
      }

      debugPrint('   📝 Actualizando: $fullName');
      debugPrint('      workerCode: $memberNumber (usando memberNumber)');

      await _firestore.collection('members').doc(memberId).update({
        'workerCode': memberNumber,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      debugPrint('   ✅ Miembro actualizado correctamente');
    } catch (e) {
      debugPrint('   ❌ Error: $e');
    }
  }
}

/// Función de ejemplo para ejecutar el script
/// Puedes llamar a esta función desde una pantalla temporal o desde la consola
Future<void> fixAllMissingWorkerCodes() async {
  final script = FixMissingWorkerCodeScript();
  await script.run();
}
