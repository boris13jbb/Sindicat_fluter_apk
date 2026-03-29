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
# Run static analysis
flutter analyze

# Run tests (if available)
flutter test

# Check for issues
flutter doctor
```

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
firebase deploy --only firestore:rules
```

### 4. Environment Variables

Review any hardcoded values:
- API endpoints
- Feature flags
- Debug settings

## Platform-Specific Deployment

### Android APK

#### Build Release APK

```bash
flutter build apk --release
```

**Output**: `build/app/outputs/flutter-apk/app-release.apk`

#### Build App Bundle (Recommended for Play Store)

```bash
flutter build appbundle --release
```

**Output**: `build/app/outputs/bundle/release/app-release.aab`

#### Signing Configuration

1. **Generate Keystore** (if first time):
   ```bash
   keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. **Configure in `android/key.properties`**:
   ```properties
   storePassword=<password>
   keyPassword=<password>
   keyAlias=upload
   storeFile=<path-to-keystore>
   ```

3. **Update `android/app/build.gradle.kts`**:
   ```kotlin
   android {
       signingConfigs {
           create("release") {
               // Load from key.properties
           }
       }
       buildTypes {
           release {
               signingConfig = signingConfigs.getByName("release")
           }
       }
   }
   ```

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
flutter build web --release
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
flutter build windows --release
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
