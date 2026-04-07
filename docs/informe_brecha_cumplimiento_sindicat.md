# Informe de brecha de cumplimiento

## Proyecto
Sindicat_fluter_apk-main

## Resultado general
Cumplimiento parcial. El proyecto ya tiene una base sólida, pero todavía no cumple por completo el Global Project Rules File. La mayor deuda está en seguridad, permisos, compatibilidad multiplataforma real, auditoría completa, navegación protegida y exportaciones por plataforma.

## Lo que ya tiene
- Flutter + Firebase + Provider + Firestore + Firebase Auth.
- Estructura por `features`, `providers`, `services`, `core/models`, `core/theme`, `core/widgets`.
- Autenticación.
- Elecciones, candidatos, votación, resultados.
- Gestión de socios.
- Importación CSV/Excel.
- Asistencia manual y por escaneo.
- Reportes PDF.
- Firestore Rules.
- Documentación inicial en `docs/`.

## Lo más crítico que falta o está mal
1. **Escalación de privilegios en `users`**: un usuario puede editar su propio documento y cambiar su `role`.
2. **Lectura abierta de votos**: cualquier usuario autenticado puede leer votos y ver `userId` + `candidateId`.
3. **Bypass de elegibilidad**: `VoteService.castVote()` valida asistencia solo si recibe `memberId`, pero la pantalla de votación no lo envía.
4. **Error visible de compilación**: `AttendanceService.registerAttendance()` repite `entityId` dos veces en la llamada a auditoría.
5. **Permisos desalineados**: la UI deja entrar a módulos que Firestore Rules luego bloquea.
6. **macOS y Linux no existen en el proyecto**, aunque el archivo global los exige.
7. **Exportación incompleta**: el CSV no siempre sale como archivo real; en algunos casos solo va al portapapeles. También hay un flujo que comparte un `.xlsx` usando `Printing.sharePdf`, lo cual no es correcto.
8. **Auditoría incompleta**: faltan eventos clave como creación/edición de elecciones, candidatos, emisión de voto y exportaciones.
9. **Navegación sin guards centralizados**: no hay manejo sólido de acceso denegado o ruta inválida.
10. **Pruebas insuficientes**: solo existe `test/widget_test.dart`.

## Matriz resumida
| Área | Estado |
|---|---|
| Stack tecnológico | Parcial |
| Estructura | Cumple |
| Principios de desarrollo | Parcial |
| Idioma y UX | Parcial |
| Roles y permisos | No cumple |
| Modelo de datos | Parcial |
| Reglas de negocio | Parcial |
| Importación de socios | Cumple |
| Seguridad y Rules | No cumple |
| Convenciones de código | Parcial |
| Navegación | No cumple |
| Compatibilidad multiplataforma | No cumple |
| Exportación y reportes | Parcial |
| Auditoría | Parcial |
| Pruebas y calidad | No cumple |
| MVP global | Parcial |

## Lo que sí cumple bien
- `order` en candidatos y `orderBy('order')`.
- ID determinista del voto.
- Importación CSV/Excel bastante avanzada.
- Cálculo automático de faltas.
- Separación razonable entre UI y servicios.

## Lo que debe tener para cumplir realmente
- Reglas seguras para `users`, `votes` y `audit_logs`.
- Guardas de navegación por sesión/rol/permiso.
- Soporte real o alcance oficial para macOS/Linux.
- Exportación PDF/CSV con flujos distintos por Web, móvil y escritorio.
- Auditoría completa de elecciones, candidatos, voto, asistencia e importación/exportación.
- Pruebas unitarias y checklist real de calidad.
- Coherencia total entre UI, services y Firestore Rules.

## Prioridad recomendada
### P0
- Bloquear auto-escalación de roles.
- Cerrar lectura de votos.
- Corregir bypass de elegibilidad.
- Corregir el error de compilación en asistencia.

### P1
- Unificar permisos entre UI, servicios y rules.
- Agregar route guards y pantallas de acceso denegado.
- Corregir exportaciones por plataforma.
- Completar auditoría.

### P2
- Añadir macOS y Linux o ajustar alcance oficialmente.
- Agregar pruebas unitarias.
- Actualizar README y docs para reflejar el estado real.

## Veredicto final
El repositorio **ya es una buena base**, pero **todavía no cumple completamente** el Global Project Rules File. Mi estimación es que está aproximadamente en **60–70%** del objetivo, con una brecha importante en seguridad y endurecimiento profesional.
