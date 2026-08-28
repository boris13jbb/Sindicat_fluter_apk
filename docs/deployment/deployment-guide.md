# Deployment Guide

Complete guide for deploying the Flutter Voting System to production.

## Prerequisites

Before deploying, ensure:
- ✅ All features tested and working
- ✅ Firebase project configured for production
- ✅ Firestore security rules ready
- ✅ Build environment set up

## Pre-Deployment Checklist

### 1. Code Quality

```bash
# Ejecuta formato, análisis, pruebas Flutter, dry-run de reglas y Emulator.
./tool/verify.ps1
```

En Linux/macOS o antes de abrir un PR:

```bash
bash tool/verify.sh
```

El pipeline de CI (`.github/workflows/ci.yml`) ejecuta las mismas comprobaciones
críticas en cada push/PR. Ver `docs/deployment/ci.md`.

La entrega no debe continuar si este comando falla. Para una comprobación
rápida sin Emulator se permite `./tool/verify.ps1 -SkipRules`, pero no sustituye
la certificación previa al despliegue.

### 2. Update Version Information

Edit `pubspec.yaml`:
```yaml
version: 1.0.0+1  # version+build_number
```

Increment build number for each deployment.

### 3. Firebase Configuration

**Production vs Development**:
- Consider using separate Firebase projects
- Update `firebase_options.dart` with production config
- Deploy production Firestore rules

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```

Ejecuta primero el mismo comando con `--dry-run`. El despliegue real requiere
una ventana controlada, respaldo y aprobación del responsable del proyecto.

### 4. Environment Variables

Review any hardcoded values:
- API endpoints
- Feature flags
- Debug settings

## Platform-Specific Deployment

### Android APK

#### Firma obligatoria

1. **Generar el keystore de carga** si aún no existe:
   ```bash
   keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. Copiar `android/key.properties.example` como `android/key.properties` y
   completar sus cuatro valores. El archivo real y los keystores están
   ignorados por Git.

3. Ejecutar los dos artefactos Android:
   ```powershell
   ./tool/build_release.ps1 -Android
   ```

El Gradle del proyecto bloquea cualquier tarea `release` Android si no existe
firma productiva. Sólo para QA local se puede usar:

```powershell
./tool/build_release.ps1 -Android -AllowDebugAndroidSigning
```

No distribuir artefactos generados con `-AllowDebugAndroidSigning`.

**Outputs**:
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- App Bundle: `build/app/outputs/bundle/release/app-release.aab`

#### Testing APK

```bash
# Install on connected device
flutter install --release

# Or manually
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Web Deployment

#### Build for Web

```bash
./tool/build_release.ps1 -Web
```

**Output**: `build/web/` directory

#### Deploy to Firebase Hosting

1. **Initialize Firebase Hosting** (first time only):
   ```bash
   firebase init hosting
   ```

2. **Configure `firebase.json`**:
   ```json
   {
     "hosting": {
       "public": "build/web",
       "ignore": [],
       "rewrites": [
         {
           "source": "**",
           "destination": "/index.html"
         }
       ]
     }
   }
   ```

3. **Deploy**:
   ```bash
   firebase deploy --only hosting
   ```

#### Deploy to Other Web Servers

Copy contents of `build/web/` to your web server:
- Apache/Nginx
- AWS S3 + CloudFront
- Vercel, Netlify, etc.

**Important**: Configure SPA routing (rewrite all routes to `index.html`)

### Windows Desktop

#### Build Executable

```bash
./tool/build_release.ps1 -Windows
```

**Output**: `build/windows/x64/runner/Release/`

#### Create Installer (Optional)

Using Inno Setup or similar:

1. **Include Files**:
   - `fluter_apk.exe`
   - `data/` folder
   - Required DLLs

2. **Create Installer Script**

3. **Build MSI/EXE**

#### Distribution Options

1. **Direct Download**
   - ZIP the Release folder
   - Provide download link
   - Include installation instructions

2. **Microsoft Store** (Advanced)
   - Requires MSIX packaging
   - Follow Store guidelines
   - Submit for certification

3. **Enterprise Distribution**
   - Internal distribution via SCCM/Intune
   - Group Policy deployment
   - Network share installation

## Post-Deployment Verification

### 1. Smoke Tests

Immediately after deployment:

**Authentication**:
- ✅ Can register new user
- ✅ Can login with existing user
- ✅ Password reset works

**Core Features**:
- ✅ Can view elections
- ✅ Can cast vote (if eligible)
- ✅ Can view results
- ✅ Attendance tracking (if admin)

**Error Handling**:
- ✅ Proper error messages display
- ✅ No crashes on invalid input
- ✅ Network errors handled gracefully

### 2. Monitor Analytics

If Firebase Analytics enabled:
- Check user adoption
- Monitor crash reports
- Track feature usage

### 3. Performance Monitoring

Use Firebase Performance Monitoring:
- Track app startup time
- Monitor network requests
- Identify slow screens

## Rollback Strategy

### If Issues Found

1. **Immediate Action**:
   - Stop distribution if critical bug
   - Notify users of known issues
   - Prepare hotfix

2. **Rollback Steps**:

   **Web**:
   ```bash
   # Deploy previous version
   firebase hosting:rollback
   ```

   **Android**:
   - Remove APK from distribution
   - Publish previous stable version

   **Windows**:
   - Remove download link
   - Provide previous version

3. **Communication**:
   - Notify stakeholders
   - Update status page
   - Document issue and resolution

## Continuous Integration (Optional)

### GitHub Actions Example

Create `.github/workflows/build.yml`:

```yaml
name: Build and Deploy

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'

      - name: Install dependencies
        run: flutter pub get

      - name: Analyze
        run: flutter analyze

      - name: Build Web
        run: flutter build web --release

      - name: Deploy to Firebase
        uses: w9jds/firebase-action@master
        with:
          args: deploy --only hosting
        env:
          FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}
```

## Best Practices

### 1. Version Management

- Use semantic versioning
- Keep changelog updated
- Tag releases in git

### 2. Testing Before Release

- Test on all target platforms
- Use beta testing group
- Gradual rollout (10% → 50% → 100%)

### 3. User Communication

- Release notes for each version
- In-app update notifications
- Email announcements for major updates

### 4. Monitoring Setup

- Enable Crashlytics
- Set up performance monitoring
- Configure alerts for critical issues

## Maintenance

### Regular Tasks

1. **Monthly**:
   - Review crash reports
   - Update dependencies
   - Check Firebase usage limits

2. **Quarterly**:
   - Security audit
   - Performance review
   - User feedback analysis

3. **Yearly**:
   - Major version upgrade planning
   - Architecture review
   - Technology stack evaluation

## Support & Updates

### Providing User Support

1. **In-App Feedback**
   - Add feedback button
   - Collect error reports
   - User satisfaction surveys

2. **Documentation**
   - User manual
   - FAQ section
   - Video tutorials

3. **Support Channels**
   - Email support
   - Help desk system
   - Community forum

## Related Documentation

- [Firebase Setup](../setup/firebase-setup.md)
- [Windows Configuration](../setup/windows-configuration.md)
- [Firestore Rules](../setup/firestore-rules.md)
- [Troubleshooting](../troubleshooting/common-issues.md)
