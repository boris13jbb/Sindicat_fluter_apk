// ignore_for_file: avoid_print

// Script de utilidad para actualizar campos workerCode faltantes en Firestore.
//
// Este script recorre todos los miembros en la colección 'members' y:
// 1. Si falta workerCode pero existe documentId, copia documentId a workerCode.
// 2. Si ambos existen, mantiene los valores actuales.
// 3. Registra estadísticas de actualización.
//
// USO:
// - Ejecutar este script desde la consola con: dart update_worker_codes.dart.
// - Requiere Firebase CLI configurado y acceso al proyecto.
// - IMPORTANTE: Hacer backup de Firestore antes de ejecutar.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Configuración de Firebase del proyecto

void main() async {
  print('🚀 Iniciando actualización de workerCode en Firestore...\n');

  try {
    // Inicializar Firebase con la configuración del proyecto
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase inicializado correctamente\n');

    final firestore = FirebaseFirestore.instance;

    // Obtener todos los miembros
    print('📊 Obteniendo todos los miembros de Firestore...');
    final snapshot = await firestore.collection('members').get();
    final members = snapshot.docs;

    print('   Total de miembros encontrados: ${members.length}\n');

    if (members.isEmpty) {
      print('⚠️  No se encontraron miembros en la base de datos.');
      print('   Por favor, importe socios primero desde CSV/Excel.\n');
      return;
    }

    int updatedCount = 0;
    int skippedCount = 0;
    int errorCount = 0;
    List<String> errors = [];

    // Procesar cada miembro
    for (final doc in members) {
      final data = doc.data();
      final docId = doc.id;

      final workerCode = data['workerCode'] as String?;
      final documentId = data['documentId'] as String?;
      final memberNumber = data['memberNumber'] as String?;

      try {
        // Caso 1: Ya tiene workerCode - saltar
        if (workerCode != null && workerCode.isNotEmpty) {
          skippedCount++;
          continue;
        }

        // Caso 2: No tiene workerCode pero sí documentId - copiar
        if (documentId != null && documentId.isNotEmpty) {
          print(
            '🔄 Actualizando miembro $docId (Nº $memberNumber): '
            'workerCode = "$documentId" (desde documentId)',
          );

          await doc.reference.update({
            'workerCode': documentId,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          updatedCount++;
        } else {
          // Caso 3: No tiene ni workerCode ni documentId - error
          errorCount++;
          final errorMsg =
              '❌ Miembro $docId (Nº $memberNumber): '
              'No tiene workerCode ni documentId';
          print(errorMsg);
          errors.add(errorMsg);
        }
      } catch (e) {
        errorCount++;
        final errorMsg = '❌ Error actualizando miembro $docId: $e';
        print(errorMsg);
        errors.add(errorMsg);
      }
    }

    // Resumen final
    print('\n${'=' * 60}');
    print('📋 RESUMEN DE ACTUALIZACIÓN');
    print('=' * 60);
    print('   ✅ Actualizados: $updatedCount miembros');
    print('   ⏭️  Omitidos (ya tenían workerCode): $skippedCount miembros');
    print('   ❌ Errores: $errorCount miembros');
    print('   📊 Total procesados: ${members.length} miembros');
    print('=' * 60);

    if (errors.isNotEmpty) {
      print('\n⚠️  ERRORES DETALLADOS:');
      for (final error in errors) {
        print('   $error');
      }
    }

    if (updatedCount > 0) {
      print('\n✅ ¡Actualización completada exitosamente!');
      print('   Los códigos QR deberían generarse correctamente ahora.');
    } else if (errorCount == 0) {
      print('\nℹ️  No fue necesario actualizar ningún miembro.');
      print('   Todos ya tienen workerCode configurado.');
    } else {
      print('\n⚠️  La actualización tuvo errores.');
      print('   Revise los mensajes de error arriba.');
    }
  } catch (e, stackTrace) {
    print('\n❌ ERROR CRÍTICO: $e');
    print('Stack trace: $stackTrace');
    print('\nPosibles causas:');
    print('   1. Firebase no está configurado correctamente');
    print('   2. No hay conexión a internet');
    print('   3. Permisos insuficientes en Firestore');
    print('   4. La colección "members" no existe');
  }
}
