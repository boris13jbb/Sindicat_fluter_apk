/// Script de utilidad para actualizar miembros existentes en Firestore
/// que no tienen el campo workerCode, copiando memberNumber como fallback.
/// 
/// Uso: dart run scripts/update_missing_worker_codes.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../lib/firebase_options.dart';

Future<void> main() async {
  print('🚀 Iniciando actualización de workerCode faltantes...\n');

  // Inicializar Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase inicializado correctamente\n');
  } catch (e) {
    print('❌ Error al inicializar Firebase: $e');
    return;
  }

  final firestore = FirebaseFirestore.instance;

  try {
    // Obtener todos los miembros
    print('📋 Obteniendo todos los miembros de Firestore...');
    final snapshot = await firestore.collection('members').get();
    final totalMembers = snapshot.docs.length;
    print('   Total de miembros encontrados: $totalMembers\n');

    if (totalMembers == 0) {
      print('⚠️ No hay miembros en la base de datos.');
      print('   Importa socios primero usando la función de importación CSV/Excel.\n');
      return;
    }

    int updatedCount = 0;
    int skippedCount = 0;
    int errorCount = 0;
    final errors = <String>[];

    // Procesar cada miembro
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final memberId = doc.id;
      final memberNumber = data['memberNumber'] as String?;
      final workerCode = data['workerCode'] as String?;

      // Verificar si necesita actualización
      if (workerCode == null || workerCode.isEmpty) {
        if (memberNumber != null && memberNumber.isNotEmpty) {
          try {
            // Actualizar el documento con workerCode = memberNumber
            await firestore.collection('members').doc(memberId).update({
              'workerCode': memberNumber,
              'updatedAt': DateTime.now().millisecondsSinceEpoch,
            });
            updatedCount++;
            print('   ✅ Actualizado: ID=$memberId, workerCode=$memberNumber');
          } catch (e) {
            errorCount++;
            errors.add('Error actualizando ID=$memberId: $e');
            print('   ❌ Error actualizando ID=$memberId: $e');
          }
        } else {
          skippedCount++;
          print('   ⚠️ Omitido: ID=$memberId (sin memberNumber válido)');
        }
      } else {
        // Ya tiene workerCode, omitir
        skippedCount++;
      }
    }

    // Mostrar resumen
    print('\n' + '=' * 60);
    print('📊 RESUMEN DE ACTUALIZACIÓN');
    print('=' * 60);
    print('   Total de miembros procesados: $totalMembers');
    print('   Miembros actualizados:        $updatedCount');
    print('   Miembros omitidos:            $skippedCount');
    print('   Errores:                      $errorCount');
    print('=' * 60);

    if (errors.isNotEmpty) {
      print('\n❌ ERRORES DETALLADOS:');
      for (final error in errors) {
        print('   - $error');
      }
    }

    if (updatedCount > 0) {
      print('\n✅ ¡Actualización completada exitosamente!');
      print('   $updatedCount miembros ahora tienen workerCode configurado.');
    } else if (errorCount == 0) {
      print('\nℹ️  No fue necesario actualizar ningún miembro.');
      print('   Todos ya tienen workerCode configurado.');
    } else {
      print('\n⚠️ La actualización tuvo errores. Revisa los detalles arriba.');
    }
  } catch (e) {
    print('\n❌ Error fatal: $e');
    print('   Stack trace: ${StackTrace.current}');
  }
}
