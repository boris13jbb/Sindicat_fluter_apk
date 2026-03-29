# Troubleshooting Guide

Common issues and solutions for the Flutter Voting System.

## Firebase Issues

### Issue 1: Firebase Initialization Timeout

**Symptoms**:
```
❌ Error inicializando Firebase: Firebase initialization timeout
```

**Causes**:
- Network connectivity issues
- Incorrect Firebase configuration
- Wrong appId in firebase_options.dart

**Solutions**:

1. **Check Network Connection**
   ```bash
   ping firebase.google.com
   ```

2. **Verify Firebase Configuration**
   - Open `lib/firebase_options.dart`
   - Compare appId with Firebase Console
   - Ensure project ID matches

3. **Re-run FlutterFire Configure**
   ```bash
   flutterfire configure --platforms=android,ios,web,windows
   ```

4. **Increase Timeout (if needed)**
   In `lib/main.dart`, increase timeout from 10s to 30s

### Issue 2: Permission Denied Errors

**Symptoms**:
```
PERMISSION_DENIED: Missing or insufficient permissions
```

**Causes**:
- User not authenticated
- Firestore rules not deployed
- Incorrect rule configuration

**Solutions**:

1. **Verify Authentication**
   ```dart
   print(FirebaseAuth.instance.currentUser);
   // Should not be null
   ```

2. **Deploy Firestore Rules**
   ```bash
   firebase deploy --only firestore:rules
   ```

3. **Check Rule Syntax**
   - Open Firebase Console → Firestore → Rules
   - Look for syntax errors
   - Ensure `isAuthenticated()` function exists

### Issue 3: Firestore Queries Return Empty Results

**Symptoms**:
- No data displayed despite data existing in console
- Stream shows empty list

**Causes**:
- Missing indexes
- Wrong query structure
- Security rules blocking access

**Solutions**:

1. **Check for Index Requirements**
   - Error message will include index creation link
   - Click link to create required index
   - Wait 5-10 minutes for index to build

2. **Verify Query Structure**
   ```dart
   // Correct: orderBy requires field to exist in all documents
   .orderBy('order', descending: false)
   
   // Ensure all candidate documents have 'order' field
   ```

3. **Test Security Rules**
   - Use Firebase Console → Firestore → Data
   - Try reading document manually
   - Check rules simulator

## Windows Build Issues

### Issue 1: CMake Errors

**Symptoms**:
```
CMake Error at flutter/CMakeLists.txt: ...
```

**Solutions**:

1. **Clean Build**
   ```powershell
   flutter clean
   flutter pub get
   flutter build windows --release
   ```

2. **Verify Visual Studio Installation**
   - Open Visual Studio Installer
   - Ensure "Desktop development with C++" is installed
   - Repair if necessary

3. **Check CMake Path**
   ```powershell
   # CMake should be in VS installation
   Test-Path "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
   ```

### Issue 2: App Crashes on Startup (Windows)

**Symptoms**:
- App closes immediately after launch
- No error message displayed

**Solutions**:

1. **Run from Command Line**
   ```cmd
   cd build\windows\x64\runner\Release
   fluter_apk.exe
   ```
   - Check for error output

2. **Check Dependencies**
   - Install Visual C++ Redistributable
   - Download: https://aka.ms/vs/17/release/vc_redist.x64.exe

3. **Debug Mode**
   ```bash
   flutter run -d windows --verbose
   ```

### Issue 3: Firebase Not Working on Windows

**Symptoms**:
- Firebase works on other platforms but not Windows
- Initialization succeeds but queries fail

**Solutions**:

1. **Verify Platform Configuration**
   - Windows must use same appId as Web
   - Check `firebase_options.dart` has Windows config

2. **Enable Windows in Firebase Console**
   - Add Windows platform to project
   - Use Web app configuration

3. **Network Issues**
   - Check firewall settings
   - Proxy configuration if behind corporate network

## Authentication Issues

### Issue 1: Cannot Sign Up

**Symptoms**:
- Registration fails with generic error
- User not created in Firebase

**Solutions**:

1. **Enable Email/Password Auth**
   - Firebase Console → Authentication → Sign-in method
   - Enable "Email/Password" provider

2. **Check Employee Number Format**
   - Must be non-empty string
   - No special validation currently

3. **Review Error Message**
   ```dart
   try {
     await authProvider.signUp(...);
   } catch (e) {
     print(e.toString()); // Detailed error
   }
   ```

### Issue 2: Login Fails

**Symptoms**:
- "Usuario no encontrado" or "Contraseña incorrecta"

**Solutions**:

1. **Verify User Exists**
   - Firebase Console → Authentication → Users
   - Check email address exactly

2. **Reset Password**
   - Use "Recuperar contraseña" feature
   - Check email for reset link

3. **Check Auth Provider Status**
   ```dart
   print(authProvider.errorMessage);
   ```

## Voting Issues

### Issue 1: Candidates Disappear After Loading

**Symptoms**:
- Candidates appear briefly then vanish
- No error message

**Solutions**:

1. **Check Stream Implementation**
   - Verify stream caching is working
   - Check for duplicate stream creation

2. **Verify All Documents Have Required Fields**
   - Field `order` must exist in all candidate documents
   - Add missing fields via Firebase Console

3. **Check Firestore Indexes**
   - Create composite index for `candidates.order`
   - Wait for index to build

### Issue 2: Cannot Cast Vote

**Symptoms**:
- Vote button doesn't work
- Error when attempting to vote

**Solutions**:

1. **Check Attendance Requirement**
   - If election requires attendance, verify user is registered
   - Admin may need to add user to event

2. **Verify Not Already Voted**
   - Check `/elections/{id}/votes/{userId}` exists
   - Users can only vote once

3. **Check Document Structure**
   ```javascript
   {
     "electionId": "correct-election-id",
     "userId": "current-user-uid",
     "candidateId": "selected-candidate-id",
     "timestamp": 1234567890
   }
   ```

## Attendance Module Issues

### Issue 1: QR Scanner Not Working (Windows)

**Symptoms**:
- Camera not accessible
- Scanner screen doesn't open

**Solution**: This is expected - cameras not supported on Windows desktop

**Workaround**: Use manual code entry instead:
- Open event detail screen
- Select "Registrar por código"
- Enter person's ID manually

### Issue 2: Cannot Export PDF (Web)

**Symptoms**:
- Export button doesn't work
- No file download

**Solutions**:

1. **Check Browser Permissions**
   - Allow downloads in browser settings
   - Check popup blocker

2. **Use CSV Instead**
   - CSV export works on all platforms
   - Can be opened in Excel/Sheets

3. **Platform-Specific Handling**
   - Web uses different export mechanism
   - Mobile/Desktop use native file system

## Performance Issues

### Issue 1: Slow Initial Load

**Symptoms**:
- App takes long time to start
- Firebase initialization hangs

**Solutions**:

1. **Disable Persistence (Web)**
   ```dart
   if (!kIsWeb) {
     FirebaseFirestore.instance.settings = Settings(
       persistenceEnabled: true,
     );
   }
   ```

2. **Reduce Initial Queries**
   - Load only essential data on startup
   - Defer heavy queries until needed

3. **Check Network Speed**
   - Test on different networks
   - Consider CDN for static assets

### Issue 2: Memory Leaks

**Symptoms**:
- App slows down over time
- Memory usage keeps increasing

**Solutions**:

1. **Check Stream Subscriptions**
   - Ensure all streams are properly disposed
   - Use `StreamBuilder` which auto-manages subscriptions

2. **Profile with DevTools**
   ```bash
   flutter pub global activate devtools
   flutter pub global run devtools
   ```

3. **Check for Listener Leaks**
   - Remove ChangeNotifier listeners in dispose
   - Use `addListener` carefully

## Debugging Tools

### Built-in Diagnostics

1. **Diagnostic Script (Windows)**
   ```cmd
   diagnose_windows.bat
   ```

2. **Verbose Logging**
   ```bash
   flutter run -d windows --verbose
   ```

3. **Firebase Debug Mode**
   ```dart
   Firebase.initializeApp(
     options: DefaultFirebaseOptions.currentPlatform,
   ).then((_) {
     print('Firebase initialized');
   }).catchError((e) {
     print('Firebase error: $e');
   });
   ```

### Firebase Console Tools

1. **Firestore Data Viewer**
   - Browse collections/documents
   - Edit data directly
   - Check field types

2. **Authentication Users**
   - View registered users
   - Reset passwords
   - Delete test users

3. **Rules Simulator**
   - Test security rules
   - Simulate different users
   - Debug permission issues

## Getting Help

### Before Asking for Help

1. ✅ Check this troubleshooting guide
2. ✅ Review error messages carefully
3. ✅ Try suggested solutions
4. ✅ Gather relevant information:
   - Error messages (full text)
   - Steps to reproduce
   - Platform (Windows/Web/Android)
   - Firebase project configuration

### Useful Information to Provide

```markdown
**Platform**: Windows / Web / Android
**Error Message**: [Full error text]
**Steps to Reproduce**:
1. 
2. 
3. 

**What I've Tried**:
- 
- 
- 

**Screenshots**: [If applicable]
```

## Related Documentation

- [Firebase Setup](../setup/firebase-setup.md)
- [Windows Configuration](../setup/windows-configuration.md)
- [Deployment Guide](../deployment/deployment-guide.md)
- [Project Overview](../architecture/project-overview.md)
