# Project Architecture Overview

Comprehensive overview of the Flutter Voting System architecture and structure.

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────┐
│          Presentation Layer             │
│  (features/, widgets, screens)          │
├─────────────────────────────────────────┤
│         State Management Layer          │
│         (providers/)                    │
├─────────────────────────────────────────┤
│           Business Logic Layer          │
│           (services/)                   │
├─────────────────────────────────────────┤
│            Data Layer                   │
│        (models/, Firebase)              │
└─────────────────────────────────────────┘
```

## Project Structure

```
lib/
├── main.dart                      # App entry point
├── firebase_options.dart          # Firebase configuration
│
├── core/                          # Shared components
│   ├── models/                    # Data models
│   │   ├── user.dart             # User model
│   │   ├── user_role.dart        # User roles enum
│   │   ├── election.dart         # Election model
│   │   ├── candidate.dart        # Candidate model
│   │   ├── voto_event.dart       # Audit event model
│   │   └── asistencia/           # Attendance models
│   │
│   ├── widgets/                   # Reusable widgets
│   │   └── professional_app_bar.dart
│   │
│   └── theme/                     # Theme configuration
│       └── app_theme.dart
│
├── features/                      # Feature modules
│   ├── auth/                      # Authentication
│   │   ├── login_screen.dart
│   │   └── sign_up_screen.dart
│   │
│   ├── home/                      # Home screen
│   │   └── home_screen.dart
│   │
│   ├── elections/                 # Election management
│   │   ├── elections_screen.dart
│   │   ├── create_election_screen.dart
│   │   ├── edit_election_screen.dart
│   │   └── add_candidate_screen.dart
│   │
│   ├── voting/                    # Vote casting
│   │   └── voting_screen.dart
│   │
│   ├── results/                   # Results display
│   │   └── election_results_screen.dart
│   │
│   ├── voto/                      # Audit & history
│   │   └── event_history_screen.dart
│   │
│   └── asistencia/                # Attendance management
│       ├── asistencia_home_screen.dart
│       ├── crear_evento_screen.dart
│       ├── evento_detail_screen.dart
│       ├── personas_screen.dart
│       ├── registro_manual_screen.dart
│       ├── asistencias_list_screen.dart
│       ├── exportar_screen.dart
│       └── scanner_screen.dart
│
├── services/                      # Business logic services
│   ├── auth_service.dart         # Authentication service
│   ├── election_service.dart     # Elections & candidates
│   ├── event_service.dart        # Audit logging
│   └── asistencia_service.dart   # Attendance management
│
└── providers/                     # State management
    └── auth_provider.dart        # Auth state provider
```

## Design Patterns

### 1. Provider Pattern (State Management)

**Purpose**: Centralized state management across the app

**Implementation**:
- `AuthProvider` manages authentication state
- Exposes `user`, `isLoading`, `isSignedIn` properties
- Notifies listeners on state changes

**Usage Example**:
```dart
Consumer<AuthProvider>(
  builder: (_, auth, __) {
    if (auth.isSignedIn) return HomeScreen();
    return LoginScreen();
  },
)
```

### 2. Service Layer Pattern

**Purpose**: Separate business logic from UI

**Services**:
- `AuthService`: Firebase authentication operations
- `ElectionService`: Election CRUD, candidate management, vote counting
- `EventService`: Audit trail logging
- `AsistenciaService`: Attendance tracking

**Benefits**:
- Testable business logic
- Reusable across multiple screens
- Clear separation of concerns

### 3. Repository Pattern (Simplified)

**Purpose**: Abstract data source (Firestore) from business logic

**Implementation**:
- Services act as repositories
- Firestore queries encapsulated in service methods
- Models are pure Dart classes with `fromMap`/`toMap` methods

### 4. Stream-Based Reactivity

**Purpose**: Real-time data updates

**Implementation**:
- Firestore streams exposed through services
- `StreamBuilder` widgets for reactive UI
- Stream caching to prevent duplicate subscriptions

**Example**:
```dart
Stream<List<Candidate>> getCandidates(String electionId) {
  // Cache streams to prevent duplicates
  if (_cache.containsKey(electionId)) return _cache[electionId];
  
  final stream = FirebaseFirestore.instance
      .collection('elections')
      .doc(electionId)
      .collection('candidates')
      .snapshots()
      .map((snap) => /* transform */);
  
  _cache[electionId] = stream;
  return stream;
}
```

## Core Features

### 1. Authentication Module

**Files**: `auth_service.dart`, `auth_provider.dart`, `login_screen.dart`, `sign_up_screen.dart`

**Functionality**:
- Email/password authentication
- Employee number registration
- Password reset
- Role-based access control (Admin/Voter)

**User Roles**:
- `VOTER`: Can vote, view results
- `ADMIN`: Can create elections, manage candidates, view audit logs

### 2. Elections & Voting Module

**Files**: `election_service.dart`, elections screens, voting screens

**Functionality**:
- Create/edit/delete elections
- Add/manage candidates
- Cast votes (with attendance verification)
- Real-time vote counting
- Results visualization

**Key Features**:
- Stream-based candidate list
- Vote uniqueness enforcement (one vote per user)
- Attendance requirement option
- Real-time results updates

### 3. Attendance Module

**Files**: `asistencia_service.dart`, asistencia screens

**Functionality**:
- Create events
- Register attendees via QR code
- Manual registration
- Export attendance reports (PDF/CSV)

**Access Control**: Admin-only feature

### 4. Audit Module

**Files**: `event_service.dart`, `voto_event.dart`, `event_history_screen.dart`

**Functionality**:
- Log all voting-related events
- Track election creation, modification
- Record vote casting attempts
- Filter by event type

## Data Flow

### Authentication Flow

```
User Input → LoginScreen → AuthProvider → AuthService → Firebase Auth
                                                    ↓
                                            Firestore (users collection)
                                                    ↓
                                        AppUser model created
                                                    ↓
                                          AuthProvider notifies
                                                    ↓
                                            HomeScreen displayed
```

### Vote Casting Flow

```
VotingScreen → Check eligibility (attendance)
                ↓
             Display candidates (Stream)
                ↓
             User selects candidate
                ↓
             VoteService.castVote()
                ↓
             Firestore transaction
                ↓
             Update vote count
                ↓
             Log audit event
                ↓
             Show confirmation
```

### Real-Time Updates Flow

```
Firestore Document Changed
        ↓
Snapshot emitted from Stream
        ↓
StreamBuilder receives update
        ↓
Widget rebuilds with new data
        ↓
UI reflects changes immediately
```

## Security Model

### Authentication Layer
- All users must authenticate via Firebase Auth
- User tokens automatically managed by Firebase

### Authorization Layer
- Role-based access control in UI
- Admin-only features hidden from regular voters
- Firestore security rules enforce access control

### Data Validation
- Model validation in `fromMap`/`toMap`
- Transaction integrity for votes
- Field validation (electionId, userId matching)

## State Management Strategy

### Ephemeral State
- Managed locally in widgets (`StatefulWidget`)
- Form controllers, loading states
- Short-lived UI state

### App-Wide State
- Managed by `AuthProvider`
- User authentication status
- Accessible throughout widget tree

### Server State
- Managed by Firestore streams
- Auto-syncs with backend
- Cached where appropriate

## Performance Optimizations

### 1. Stream Caching
- Prevent duplicate Firestore subscriptions
- Single stream instance per resource
- Automatic cleanup on dispose

### 2. Firestore Optimization
- Proper indexing for queries
- Limited result sets
- Offline persistence enabled

### 3. Widget Optimization
- `const` constructors where possible
- Efficient `ListView.builder`
- Minimal rebuilds with proper state management

## Testing Strategy

### Unit Tests
- Model serialization/deserialization
- Service layer business logic
- State management logic

### Integration Tests
- Authentication flows
- Vote casting process
- Real-time updates

### Manual Testing
- End-to-end user flows
- Cross-platform testing
- Performance under load

## Future Improvements

### Potential Enhancements
1. **Dependency Injection**: Consider using `get_it` or `riverpod`
2. **Advanced Caching**: Implement Hive for offline-first approach
3. **Better Error Handling**: Standardized error types and messages
4. **Analytics**: Integrate Firebase Analytics
5. **Push Notifications**: For election reminders
6. **Multi-language Support**: i18n implementation

### Scalability Considerations
- Pagination for large candidate lists
- Batch operations for bulk updates
- Cloud Functions for complex business logic
- Composite indexes for complex queries

## Related Documentation

- [Firebase Setup](../setup/firebase-setup.md)
- [Windows Configuration](../setup/windows-configuration.md)
- [Deployment Guide](../deployment/deployment-guide.md)
- [Troubleshooting](troubleshooting.md)
