# Archivos apartados del proyecto

Fecha de organización: 2026-06-07

Los archivos que no participan en la compilación, ejecución, pruebas ni
despliegue fueron movidos fuera de la raíz del proyecto a:

```text
D:\Sindicat_fluter_apk_archivos_apartados
```

No se eliminaron archivos. La carpeta externa conserva el contenido original
organizado por categoría.

## Contenido apartado

### Diseños de referencia

- `disenos-pantallas/`
- `disenos_sindicato_premium_pantallas.zip`

Estos archivos se usaron como referencias visuales, pero Flutter no los declara
como recursos en `pubspec.yaml` y el código activo no los consulta.

### Datos históricos de importación

- `socios.csv`
- `socios_corregido.csv`
- `socios_corregido_con_numero.csv`
- `socios.xlsx`
- `socios_plantilla.xlsx`

Son archivos de trabajo e importaciones anteriores. La aplicación genera y
descarga sus plantillas desde la interfaz. Si se necesita regenerar la plantilla
local, se puede ejecutar:

```powershell
dart run tool/generate_socios_template.dart
```

### Documentación histórica

- `SOLUCION_RAPIDA.md`
- `SOLUCION_WORKERCODE_RESUMEN.md`
- `UPDATE_WORKER_CODE_INSTRUCTIONS.md`

Estas guías documentan una corrección antigua de `workerCode`. El script activo
de mantenimiento permanece en:

```text
scripts/update_missing_worker_codes.dart
```

### Depuración y archivos inválidos

- `firestore-debug.log`
- `flutter_01.png`

`firestore-debug.log` es un registro generado localmente y `flutter_01.png` era
un archivo vacío de cero bytes.

## Componentes conservados en la raíz

Permanecen en el proyecto todos los componentes activos:

- código Flutter y plataformas: `lib/`, `android/`, `ios/`, `web/`, `windows/`;
- backend: `functions/`;
- configuración Firebase y reglas;
- pruebas: `test/`, `firebase_rules_test/`;
- herramientas: `tool/`, `scripts/`;
- documentación técnica: `docs/`, `expediente_tecnico_aplicacion.md`;
- archivos de dependencias y configuración necesarios para desarrollo.

## Restauración

Para recuperar un archivo, moverlo desde su categoría dentro de
`D:\Sindicat_fluter_apk_archivos_apartados` a la ubicación requerida. No se
debe restaurar todo el contenido automáticamente, porque algunos archivos son
duplicados, históricos o generados.
