# Build en Windows (desktop) – Error "Unable to find git in your PATH"

El build de Flutter para Windows usa MSBuild/Visual Studio, que a veces no ve el PATH donde está Git. Prueba estas opciones **en este orden**.

## Opción 1: Añadir Git al PATH del sistema (recomendado)

1. Pulsa **Win + R**, escribe `sysdm.cpl` y Enter.
2. Pestaña **Opciones avanzadas** → **Variables de entorno**.
3. En **Variables del sistema**, selecciona **Path** → **Editar** → **Nuevo**.
4. Añade: `C:\Program Files\Git\cmd`
5. Añade también (si no está): `C:\Program Files\Git\bin`
6. Aceptar en todas las ventanas.
7. **Cierra por completo** Cursor/PowerShell y vuelve a abrirlos.
8. En la carpeta del proyecto ejecuta:
   ```bash
   flutter run -d windows
   ```

## Opción 2: Reinstalar Git con la opción correcta

1. Desinstala Git desde "Configuración → Aplicaciones".
2. Instala de nuevo desde https://git-scm.com/download/win
3. En el asistente, elige **"Git from the command line and also from 3rd-party software"** (no "Bash only").
4. Tras instalar, añade Git al PATH del sistema como en la Opción 1 y reinicia la terminal/IDE.

## Opción 3: Usar la Símbolo del sistema para desarrolladores de VS

1. Abre el menú Inicio y busca **"Developer Command Prompt for VS 2022"** o **"Developer PowerShell for VS 2022"**.
2. En esa ventana:
   ```bash
   cd D:\proyecto_voto_sindicato\fluter_apk
   set "PATH=C:\Program Files\Git\cmd;%PATH%"
   flutter run -d windows
   ```

## Opción 4: Ejecutar en Chrome (sin build de Windows)

Si solo quieres probar la app sin compilar para Windows:

```bash
flutter run -d chrome
```

O para que pregunte cada vez por el dispositivo:

```bash
flutter run
```
y elige **[2] Chrome**.
