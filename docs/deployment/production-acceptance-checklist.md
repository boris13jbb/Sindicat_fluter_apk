# Checklist de aceptación productiva

Este checklist separa las validaciones automatizables de las que requieren
cuentas reales, datos representativos o dispositivos físicos.

## Puerta automática obligatoria

- [ ] `./tool/verify.ps1` termina correctamente.
- [ ] `git -c core.whitespace=cr-at-eol diff --check` no reporta problemas.
- [ ] Firestore Rules e índices compilan en dry-run.
- [ ] Storage Rules compilan en dry-run.
- [ ] La suite Firebase Emulator valida permisos positivos y negativos.
- [ ] Los builds release requeridos terminan correctamente.
- [ ] Android se genera con `android/key.properties` productivo, sin
      `-AllowDebugAndroidSigning`.

## Matriz manual por rol

Validar con cuentas QA separadas:

| Acción | SUPERADMIN | ADMIN | OPERADOR_ASISTENCIA | VOTER | USER |
|---|---:|---:|---:|---:|---:|
| Ver perfil propio | Sí | Sí | Sí | Sí | Sí |
| Gestionar socios | Sí | Sí | No | No | No |
| Crear/editar elección | Sí | Sí | No | No | No |
| Emitir voto elegible | Sí | Sí | Sí | Sí | Según negocio |
| Operar asistencia | Sí | Sí | Sí | No | No |
| Ver auditoría | Sí | Sí | No | No | No |
| Configurar marca PDF | Sí | No | No | No | No |

## Dispositivos y plataformas

- [ ] Android físico: permisos de cámara, QR válido, QR inválido y doble escaneo.
- [ ] Android físico: compartir/abrir PDF, CSV, XLSX y QR.
- [ ] Web: login, rutas protegidas, importación y descargas.
- [ ] Windows: login, perfil, voto, asistencia, exportación y cierre.
- [ ] iOS: validar antes de declarar soporte productivo.
- [ ] Tamaño de fuente grande, contraste, teclado y lector de pantalla básicos.

## Datos y concurrencia

- [ ] Padrón real o anonimizado de volumen representativo.
- [ ] Usuarios históricos sin `memberId` migrados o reparados.
- [ ] Eventos legacy y `attendance_events` verificados.
- [ ] Voto doble/concurrente rechazado.
- [ ] Conteos de candidato y elección permanecen sincronizados.
- [ ] Exportaciones y reportes coinciden con los datos de Firestore.

## Despliegue controlado

- [ ] Responsable y ventana de despliegue aprobados.
- [ ] Backup/export de Firestore disponible.
- [ ] `firebase deploy --only firestore:rules,firestore:indexes,storage --dry-run`.
- [ ] Deploy real aprobado y ejecutado.
- [ ] Smoke test posterior al deploy.
- [ ] Plan de rollback comunicado.
- [ ] Keystore, contraseñas y recuperación de la clave de carga custodiados
      fuera del repositorio.
