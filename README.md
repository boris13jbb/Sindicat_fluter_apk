# Flutter Voting System - Sistema Integrado Sindicato

A comprehensive Flutter-based voting system with real-time updates, attendance management, and audit tracking.

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Platform](https://img.shields.io/badge/platform-android%20%7C%20ios%20%7C%20web%20%7C%20windows-green)
![Flutter](https://img.shields.io/badge/Flutter-%5E3.8.1-lightblue)

## 🎯 Features

### Core Modules

#### 🗳️ **Voting System**
- Create and manage elections
- Add/edit/delete candidates
- Real-time vote casting with Firestore streams
- One vote per user enforcement
- Live results visualization
- Attendance requirement option

#### 👤 **Authentication**
- Email/password authentication via Firebase Auth
- Employee number registration
- Password recovery
- Role-based access control (Admin/Voter)
- User profile management

#### 📋 **Attendance Management** (Admin Only)
- Create events/meetings
- QR code scanning for check-in
- Manual attendance registration
- Export reports (PDF/CSV)
- Real-time attendance tracking

#### 📊 **Audit Trail**
- Complete event logging
- Track all voting operations
- Filter by event type
- Timestamp and user tracking

## 🏗️ Architecture

Built with clean architecture principles:
- **Presentation Layer**: Feature-first organization
- **State Management**: Provider pattern
- **Business Logic**: Service layer
- **Data**: Firebase Firestore with real-time streams

See [Architecture Overview](docs/architecture/project-overview.md) for detailed information.

## 📱 Supported Platforms

- ✅ **Android** (API 23+) - Production Ready
- ✅ **iOS** (iOS 12+) - Production Ready  
- ✅ **Web** (Modern browsers) - Production Ready
- ✅ **Windows** (10/11) - Production Ready

## 🚀 Quick Start

### Prerequisites

- Flutter SDK ^3.8.1
- Firebase project with Authentication and Firestore enabled
- For Android: Android Studio / VS Code
- For Windows: Visual Studio 2022 with C++ workload
- For Web: Chrome/Firefox/Edge

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd Sindicat_fluter_apk
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   
   Follow the complete guide: [Firebase Setup](docs/setup/firebase-setup.md)
   
   Quick steps:
   ```bash
   # Login to Firebase
   npx firebase-tools login
   
   # Configure FlutterFire
   flutterfire configure --platforms=android,ios,web,windows
   ```

4. **Deploy Firestore Rules**
   ```bash
   firebase deploy --only firestore:rules
   ```

5. **Run the app**
   ```bash
   # Choose your target platform
   flutter run -d chrome           # Web
   flutter run -d windows          # Windows Desktop
   flutter run                     # Android device/emulator
   ```

## 📖 Documentation

Comprehensive documentation is available in the [`docs/`](docs/) directory:

### Setup Guides
- **[Firebase Setup](docs/setup/firebase-setup.md)** - Complete Firebase configuration
- **[Windows Configuration](docs/setup/windows-configuration.md)** - Build on Windows
- **[Firestore Rules](docs/setup/firestore-rules.md)** - Security rules reference

### Architecture
- **[Project Overview](docs/architecture/project-overview.md)** - System design and structure

### Deployment
- **[Deployment Guide](docs/deployment/deployment-guide.md)** - Production deployment

### Troubleshooting
- **[Common Issues](docs/troubleshooting/common-issues.md)** - Solutions to problems

## 🔧 Development

### Running Tests

```bash
# Run static analysis
flutter analyze

# Run unit tests (when available)
flutter test
```

### Building for Production

```bash
# Android APK
flutter build apk --release

# Web
flutter build web --release

# Windows
flutter build windows --release
```

See [Deployment Guide](docs/deployment/deployment-guide.md) for detailed instructions.

## 📂 Project Structure

```
lib/
├── main.dart                 # App entry point
├── firebase_options.dart     # Firebase config
├── core/                     # Shared components
│   ├── models/              # Data models
│   ├── widgets/             # Reusable widgets
│   └── theme/               # Theme config
├── features/                # Feature modules
│   ├── auth/               # Authentication
│   ├── home/               # Home screen
│   ├── elections/          # Election management
│   ├── voting/             # Vote casting
│   ├── results/            # Results display
│   ├── voto/               # Audit trail
│   └── asistencia/         # Attendance
├── services/               # Business logic
│   ├── auth_service.dart
│   ├── election_service.dart
│   ├── event_service.dart
│   └── asistencia_service.dart
└── providers/              # State management
    └── auth_provider.dart
```

## 🔐 Security

- Firebase Authentication for all users
- Firestore security rules enforce access control
- Role-based permissions (Admin vs Voter)
- Vote immutability guaranteed
- Audit trail for all operations

See [Firestore Rules](docs/setup/firestore-rules.md) for detailed security configuration.

## 🛠️ Tech Stack

- **Framework**: Flutter ^3.8.1
- **Backend**: Firebase
  - Authentication
  - Firestore Database
  - Hosting (Web)
- **State Management**: Provider ^6.1.2
- **Additional Packages**:
  - `pdf` - Report generation
  - `printing` - Print functionality
  - `share_plus` - Share exports
  - `path_provider` - File system access

## 👥 User Roles

### Voter
- View elections
- Cast vote (one per election)
- View live results
- Check own profile

### Administrator
- All Voter features PLUS:
- Create/manage elections
- Add/edit/delete candidates
- Create attendance events
- Manage attendee lists
- View audit logs
- Export reports

## 🔍 Key Features in Detail

### Real-Time Updates
- Firestore streams provide instant updates
- Vote counts update automatically
- No manual refresh needed
- Optimized with stream caching

### Offline Support
- Firestore persistence enabled (non-web)
- Queue operations when offline
- Sync when connection restored

### Attendance Integration
- Optional attendance requirement for voting
- QR code scanning for quick check-in
- Manual registration fallback
- Admin can verify eligibility

## ⚠️ Known Limitations

1. **QR Scanning**: Not available on Windows/Web (camera access limited)
   - Workaround: Manual code entry available

2. **Platform Plugins**: Some plugins have limited desktop support
   - Check plugin compatibility before adding features

## 🐛 Troubleshooting

Common issues and solutions:

### Firebase Initialization Timeout
- Check network connection
- Verify `firebase_options.dart` is correct
- See [Firebase Setup Guide](docs/setup/firebase-setup.md)

### Permission Denied Errors
- Ensure user is authenticated
- Deploy Firestore rules
- Check [Security Rules](docs/setup/firestore-rules.md)

### Build Errors (Windows)
- Install Visual Studio with C++ workload
- Run diagnostic: `diagnose_windows.bat`
- See [Windows Guide](docs/setup/windows-configuration.md)

For more issues, see [Troubleshooting Guide](docs/troubleshooting/common-issues.md)

## 📝 Changelog

### Version 1.0.0
- ✅ Complete authentication system
- ✅ Full election management
- ✅ Real-time voting with streams
- ✅ Results visualization
- ✅ Attendance tracking module
- ✅ Audit trail logging
- ✅ Multi-platform support
- ✅ Stream caching optimization
- ✅ Enhanced error handling

## 🤝 Contributing

### Reporting Bugs
1. Check existing issues
2. Use issue template
3. Include reproduction steps
4. Specify platform and version

### Pull Requests
1. Fork the repository
2. Create feature branch
3. Make changes
4. Test thoroughly
5. Submit PR with description

### Code Style
- Follow Dart style guide
- Use meaningful names
- Comment complex logic
- Write tests when applicable

## 📄 License

[Add your license here]

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase team for backend services
- All contributors and maintainers
- Community feedback and testing

## 📞 Support

- **Documentation**: [`docs/`](docs/) directory
- **Issues**: GitHub Issues
- **Emergency Contact**: [Add contact info]

## 🔗 Useful Links

- [Flutter Documentation](https://docs.flutter.dev/)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Provider Package](https://pub.dev/packages/provider)
- [Cloud Firestore](https://firebase.google.com/docs/firestore)

---

**Last Updated**: March 28, 2026  
**Current Version**: 1.0.0  
**Maintained By**: [Your Name/Organization]
