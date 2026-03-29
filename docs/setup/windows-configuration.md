# Windows Configuration Guide

Complete guide for building and running the Flutter Voting System on Windows.

## Prerequisites

- Windows 10/11 (64-bit)
- Visual Studio 2022 with "Desktop development with C++" workload
- Flutter SDK (latest stable version)
- Git for Windows

## Build Configuration

### Visual Studio Setup

1. Install Visual Studio 2022 Community or higher
2. Install workload: **Desktop development with C++**
3. Ensure these components are installed:
   - MSVC v143 - VS 2022 C++ x64/x86 build tools
   - Windows 10/11 SDK
   - CMake tools for Windows

### Flutter Configuration

```bash
# Check Flutter installation
flutter doctor -v

# Enable Windows desktop support
flutter config --enable-windows-desktop

# Verify Windows support
flutter devices
```

## Building for Windows

### Development Mode

```bash
# Run on Windows (Debug mode)
flutter run -d windows

# Run with debugging enabled
flutter run -d windows --debug
```

### Release Build

```bash
# Build release version
flutter build windows --release

# Output location
# build\windows\x64\runner\Release\
```

### Common Build Issues & Solutions

#### Issue: CMake Errors
**Error**: `CMake Error at flutter/CMakeLists.txt`

**Solution**:
```powershell
# Clean build artifacts
flutter clean

# Get dependencies
flutter pub get

# Rebuild
flutter build windows --release
```

#### Issue: Firebase Initialization Timeout
**Error**: Firebase initialization timeout on Windows

**Solution**:
1. Ensure same Firebase appId as Web platform
2. Check network connectivity
3. Increase timeout in `lib/main.dart` if needed

#### Issue: Missing DLLs or Runtime Errors
**Error**: The code execution cannot proceed because XXX.dll was not found

**Solution**:
```powershell
# Install Visual C++ Redistributable
# Download from: https://aka.ms/vs/17/release/vc_redist.x64.exe
```

#### Issue: Plugin Compatibility
Some Flutter plugins may not support Windows desktop:

**Check plugin compatibility**:
```bash
flutter pub outdated
```

**Workaround**: Use conditional imports or disable Windows-specific features

## Running the Application

### PowerShell Script (Recommended)

Use the provided script for consistent builds:
```powershell
.\run_windows.ps1
```

### Manual Execution

After building release:
```bash
cd build\windows\x64\runner\Release
fluter_apk.exe
```

## Debugging Windows Builds

### Diagnostic Script

Run the diagnostic tool to identify issues:
```cmd
diagnose_windows.bat
```

### Common Debug Scenarios

1. **App crashes on startup**
   - Check Firebase configuration
   - Verify all required DLLs are present
   - Run with `--verbose` flag

2. **Firestore not working**
   - Confirm Firebase initialization
   - Check security rules
   - Verify internet connection

3. **Authentication fails**
   - Check Firebase Auth is enabled
   - Verify package name matches Firebase console
   - Review Firestore rules

## Performance Optimization

### Build Optimization

```bash
# Clean build for best performance
flutter clean
flutter pub cache repair
flutter build windows --release
```

### Runtime Performance

- Enable Firestore persistence for offline support
- Use stream caching for real-time data
- Minimize rebuilds with proper state management

## Known Limitations

1. **Camera/QR Scanning**: Not available on Windows desktop
   - Use manual code entry instead
   - QR scanner feature only works on mobile

2. **Platform-Specific Plugins**: Some plugins may have limited Windows support
   - Check plugin documentation
   - Use conditional platform checks

## Next Steps

- [Firebase Setup](setup/firebase-setup.md)
- [Deployment Guide](../deployment/deployment-guide.md)
- [Main README](../README.md)
