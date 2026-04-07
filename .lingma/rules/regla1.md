---
trigger: always_on
alwaysApply: true
---

Global Project Rules File

Project name:
Sistema de votaciones y asistencia multiplataforma para sindicato / asociación

Project purpose:
Construir y mantener una aplicación multiplataforma en Flutter con backend Firebase para:
- autenticación
- gestión de roles
- gestión de socios
- importación de socios por CSV/Excel
- elecciones y candidatos
- votación online con un voto por usuario por elección
- elegibilidad de voto según asistencia
- control de asistencia manual y por escaneo
- generación automática de faltas
- reportes y exportación PDF/CSV

==================================================
1. STACK TECNOLÓGICO OBLIGATORIO
==================================================

1. Frontend principal: Flutter
2. Lenguaje: Dart moderno
3. Estado: provider
4. Backend: Firebase
5. Base de datos: Cloud Firestore
6. Autenticación: Firebase Auth
7. Exportación: PDF y CSV
8. Plataformas objetivo obligatorias:
   - Web
   - Android
   - iOS
   - Windows
   - macOS
   - Linux

No reemplazar este stack sin justificarlo claramente.

==================================================
2. ESTRUCTURA DEL PROYECTO
==================================================

Respetar esta estructura base:

- lib/features/
- lib/providers/
- lib/services/
- lib/core/models/
- lib/core/theme/
- lib/core/widgets/

Reglas:
- UI dentro de features
- providers solo para estado y coordinación con servicios
- services para lógica de negocio y acceso a Firebase
- models en core/models con fromMap, toMap y copyWith si aplica
- evitar mezclar lógica de negocio dentro de widgets
- evitar archivos gigantes con múltiples responsabilidades

==================================================
3. PRINCIPIOS DE DESARROLLO
==================================================

1. Priorizar claridad sobre complejidad.
2. Implementar primero el MVP funcional.
3. No sobreingenierizar.
4. Todo cambio debe ser mantenible y coherente con la arquitectura actual.
5. Evitar duplicación innecesaria.
6. Toda decisión ambigua debe resolverse con la opción más simple y segura.
7. Comentar solo donde realmente aporte valor.
8. No introducir dependencias nuevas sin necesidad real.

==================================================
4. IDIOMA Y UX
==================================================

1. Toda la interfaz debe estar en español.
2. Los textos deben ser claros para usuarios no técnicos.
3. El diseño debe ser responsive y usable en:
   - móvil
   - tablet
   - web
   - escritorio
4. No diseñar pantallas pensadas solo para Android.
5. Siempre considerar experiencia multiplataforma real.

==================================================
5. ROLES Y PERMISOS
==================================================

El sistema debe trabajar al menos con estos roles:

- superadmin
- admin
- votante
- operador_asistencia
- usuario

Permisos mínimos:

superadmin:
- control total
- crear y administrar socios
- importar socios por CSV/Excel
- crear y administrar elecciones
- gestionar eventos y asistencia
- ver y exportar reportes
- administrar configuraciones clave

admin:
- gestionar elecciones
- gestionar candidatos
- gestionar eventos y asistencia
- ver resultados y reportes

votante:
- iniciar sesión
- ver elecciones habilitadas
- votar solo si cumple elegibilidad
- no administrar datos sensibles

operador_asistencia:
- registrar asistencia manual
- registrar asistencia por escaneo
- consultar listados y generar reportes
- no administrar elecciones ni roles

usuario:
- acceso autenticado básico según permisos configurados

Nunca confiar solo en la UI para permisos.
Validar permisos en:
- navegación
- servicios
- reglas de Firestore

==================================================
6. MODELO DE DATOS OBLIGATORIO
==================================================

Colecciones mínimas:

- users
- members o socios
- elections
- candidates
- votes
- audit_logs
- attendance_events
- attendances
- import_logs si aplica

Reglas obligatorias del modelo:

1. Cada candidato debe tener el campo `order`.
2. Las consultas de candidatos deben usar `orderBy('order')`.
3. El voto debe tener ID determinista, por ejemplo:
   `electionId_userId`
4. Un usuario solo puede votar una vez por elección.
5. Las asistencias deben estar vinculadas a:
   - evento
   - socio
   - método de registro
   - usuario que registró
   - fecha/hora
6. La elección debe poder configurarse con elegibilidad:
   - todos los socios activos
   - solo asistentes de un evento específico

==================================================
7. REGLAS DE NEGOCIO CRÍTICAS
==================================================

7.1 Votación
- Un usuario solo puede votar una vez por elección.
- No permitir actualizar o borrar votos después de creados.
- El registro del voto debe ser atómico.
- Usar WriteBatch o transacción para:
  - guardar voto
  - actualizar contador de candidato
  - actualizar contador general de elección
  - registrar auditoría si aplica

7.2 Elegibilidad de voto
Cada elección debe permitir definir:
- todos_los_socios_activos
- solo_asistentes_de_evento

Si la elección usa `solo_asistentes_de_evento`:
- debe existir `attendanceEventId`
- solo puede votar quien tenga asistencia válida en ese evento
- no permitir activar ese modo sin evento asociado

7.3 Asistencia
- La asistencia puede registrarse manualmente o por escaneo
- El sistema debe permitir generar reporte de:
  - asistentes
  - faltantes
- Las faltas deben calcularse automáticamente al generar reporte
- No cargar faltas manualmente una por una en el MVP salvo necesidad justificada

7.4 Socios
- El superadmin puede crear socios manualmente
- El superadmin puede importar socios por CSV/Excel
- Debe existir validación de duplicados por identificador único
- Debe existir soporte para socio activo/inactivo

==================================================
8. IMPORTACIÓN DE SOCIOS
==================================================

El sistema debe permitir importación masiva desde:
- CSV
- Excel (.xlsx)

La importación debe incluir:
- selección de archivo
- lectura segura
- validación de columnas
- validación de campos obligatorios
- detección de duplicados
- resumen final con:
  - importados correctamente
  - omitidos
  - errores
  - duplicados detectados

No asumir formatos ambiguos.
Documentar claramente las columnas esperadas.

==================================================
9. SEGURIDAD Y FIRESTORE RULES
==================================================

Obligatorio:
- todo acceso requiere autenticación, salvo pantallas públicas mínimas si existen
- cada usuario solo puede leer/escribir lo permitido
- votos no se actualizan ni se borran
- solo admin/superadmin gestionan elecciones y candidatos
- solo roles autorizados gestionan asistencia y reportes
- proteger contra escritura de datos ajenos
- proteger contra escalación de privilegios desde cliente

Nunca implementar lógica sensible solo en frontend.
Toda lógica crítica debe reforzarse con:
- Firestore Rules
- estructura de datos
- servicios/transacciones

==================================================
10. CONVENCIONES DE CÓDIGO
==================================================

1. Nombres claros y consistentes.
2. No usar abreviaciones confusas.
3. Métodos cortos y con una responsabilidad principal.
4. Preferir clases pequeñas y reutilizables.
5. Mantener separación entre:
   - UI
   - estado
   - lógica
   - acceso a datos
6. Modelos con:
   - fromMap
   - toMap
   - copyWith cuando sea útil
7. Evitar lógica Firestore directamente en widgets.

==================================================
11. NAVEGACIÓN
==================================================

Usar rutas nombradas organizadas por módulos, por ejemplo:

- /auth/...
- /socios/...
- /voto/...
- /asistencia/...
- /admin/...

Las rutas protegidas deben validar:
- sesión activa
- rol
- permisos mínimos

Debe existir manejo para:
- acceso denegado
- ruta inválida
- errores básicos de navegación

==================================================
12. COMPATIBILIDAD MULTIPLATAFORMA
==================================================

Toda implementación debe considerar compatibilidad real con:
- Web
- Android
- iOS
- Windows
- macOS
- Linux

Antes de usar paquetes o APIs:
- verificar si funcionan en todas las plataformas objetivo
- si no funcionan, documentar fallback o alternativa

Casos sensibles:
- file picker
- permisos
- impresión
- share
- path_provider
- escaneo QR/código
- persistencia local
- exportación y descarga de archivos

No usar soluciones exclusivas de móvil cuando se requiera soporte web o escritorio.

==================================================
13. EXPORTACIÓN Y REPORTES
==================================================

Debe existir exportación en:
- PDF
- CSV

Reportes mínimos para asistencia:
- asistentes
- faltantes
- total asistentes
- total faltantes
- porcentaje de asistencia
- porcentaje de inasistencia
- nombre del evento
- fecha y hora
- método de registro

Considerar diferencias por plataforma:
- Web: descarga
- Android/iOS: compartir o guardar
- escritorio: guardar/abrir archivo

==================================================
14. AUDITORÍA
==================================================

Registrar eventos importantes como mínimo para:
- login relevante si aplica
- creación de elección
- edición de elección
- creación de candidatos
- emisión de voto
- creación de evento
- registro de asistencia
- importación de socios
- exportación de reportes

Cada evento de auditoría debe intentar guardar:
- quién
- qué acción
- sobre qué entidad
- cuándo
- resultado
- detalles mínimos útiles

==================================================
15. PRUEBAS Y CALIDAD
==================================================

Antes de cerrar cambios importantes:
- ejecutar `flutter analyze`
- mantener el código formateado
- agregar al menos pruebas mínimas cuando el cambio lo justifique

No dejar warnings graves ignorados sin explicación.

==================================================
16. REGLAS PARA EL AGENTE
==================================================

1. No reestructurar todo el proyecto sin necesidad.
2. No romper compatibilidad multiplataforma.
3. No eliminar reglas de seguridad existentes sin reemplazo equivalente.
4. No introducir dependencias innecesarias.
5. No mover lógica crítica a la UI.
6. No asumir que todos los usuarios pueden votar.
7. No asumir que toda elección usa la misma regla de elegibilidad.
8. No asumir que solo existe asistencia manual.
9. No usar datos mock en producción sin dejarlo explícito.
10. No modificar archivos sensibles de configuración sin explicar por qué.

==================================================
17. CUANDO IMPLEMENTES UNA NUEVA FUNCIÓN
==================================================

Siempre:
1. Explica brevemente el objetivo.
2. Indica archivos creados o modificados.
3. Mantén coherencia con la arquitectura.
4. Considera permisos y seguridad.
5. Considera impacto multiplataforma.
6. Considera impacto en Firestore Rules.
7. Considera si requiere auditoría.
8. Considera si requiere actualización de README.

==================================================
18. PRIORIDAD DE DESARROLLO
==================================================

Priorizar siempre en este orden:

1. Seguridad
2. Correctitud de lógica de negocio
3. Compatibilidad multiplataforma
4. Claridad del código
5. UX clara
6. Optimización secundaria

==================================================
19. DEFINICIÓN DE MVP
==================================================

El MVP debe cumplir como mínimo:

- registro e inicio de sesión
- roles funcionales
- gestión de socios
- importación CSV/Excel
- creación de elecciones
- candidatos ordenados por `order`
- voto único por usuario
- elegibilidad de voto por asistencia opcional
- registro de asistencia
- cálculo automático de faltas
- reporte de asistencia
- exportación PDF/CSV
- reglas Firestore básicas y seguras

==================================================
20. ESTILO DE RESPUESTA DEL AGENTE
==================================================

Cuando propongas cambios:
- responde en español
- sé técnico pero claro
- evita explicaciones vagas
- da soluciones implementables
- si algo es ambiguo, elige la opción más simple que cumpla el MVP y documéntala