# Firebase Setup Guide

This guide covers the complete Firebase configuration for the Flutter Voting System.

## Prerequisites

- Node.js and npm installed
- Firebase CLI installed globally (`npm install -g firebase-tools`)
- FlutterFire CLI activated (`dart pub global activate flutterfire_cli`)
- Google account with Firebase access

## Step-by-Step Setup

### 1. Firebase Authentication

1. Open a terminal in the project directory
2. Run: `npx firebase-tools login`
3. Complete authentication in the browser that opens

### 2. Configure FlutterFire

1. Add Pub Cache to PATH (Windows):
   ```bash
   set PATH=%USERPROFILE%\AppData\Local\Pub\Cache\bin;%PATH%
   ```

2. Run FlutterFire configuration:
   ```bash
   flutterfire configure --platforms=android,ios,web,windows
   ```

3. Select your Firebase project when prompted
4. Choose all platforms: android, ios, web, windows

### 3. Platform-Specific Configuration

#### Android
- Package ID: `com.skyrunner.sindicato`
- Ensure `google-services.json` is in `android/app/`
- Minimum SDK: 23

#### Web
- Same project ID as other platforms
- Firebase configuration in `firebase_options.dart`

#### Windows
- Uses same configuration as Web
- Ensure appId matches Web platform

### 4. Firestore Security Rules

Deploy the security rules from `firestore.rules`:

```bash
firebase deploy --only firestore:rules
```

**Important Rules:**
- Users must be authenticated to read/write
- Vote subcollection has special rules for vote casting
- Candidates require electionId field

### 5. Verification

After setup, verify:
- ✅ `lib/firebase_options.dart` exists
- ✅ No Firebase initialization errors in console
- ✅ Can authenticate users
- ✅ Firestore queries work correctly

## Troubleshooting

### Firebase Initialization Timeout
- Check network connection
- Verify Firebase project exists
- Confirm `firebase_options.dart` is correct

### Permission Denied Errors
- Ensure user is authenticated
- Check Firestore security rules are deployed
- Verify user has proper roles in Firebase Console

### Platform-Specific Issues
- **Android**: Check `google-services.json` is correct
- **Web**: Verify Firebase configuration in console
- **Windows**: Use same appId as Web platform

## Next Steps

- [Running the App](../README.md#running-the-app)
- [Deployment Guide](../deployment/deployment-guide.md)
- [Troubleshooting](../troubleshooting/windows-issues.md)
