# Firestore Security Rules

Complete security rules for the Flutter Voting System Firestore database.

## Current Rules Location

The active security rules are in: `firestore.rules` (project root)

## Rule Structure

### Authentication Requirements

All users must be authenticated to access any data:

```javascript
function isAuthenticated() {
  return request.auth != null;
}
```

### Users Collection

```javascript
match /users/{userId} {
  allow read: if isAuthenticated() && request.auth.uid == userId;
  allow create: if isAuthenticated() && request.auth.uid == userId;
  allow update, delete: if false; // Prevent modification
}
```

**Key Points:**
- Users can only read their own data
- Users can create their profile on signup
- No updates or deletes allowed (security)

### Elections Collection

```javascript
match /elections/{electionId} {
  allow read: if isAuthenticated();
  allow create, update, delete: if isAuthenticated();
  
  // Candidates subcollection
  match /candidates/{candidateId} {
    allow read: if isAuthenticated() && candidateId != "";
    allow create, update, delete: if isAuthenticated();
  }
  
  // Votes subcollection
  match /votes/{voteId} {
    allow read: if isAuthenticated();
    allow create: if isAuthenticated() 
      && request.resource.data.electionId == electionId
      && request.resource.data.userId == request.auth.uid;
    allow update, delete: if false; // Prevent vote tampering
  }
}
```

**Key Points:**
- All authenticated users can read elections
- Vote casting requires matching electionId and userId
- Votes cannot be modified or deleted once cast

### Events Collection (Audit)

```javascript
match /events/{eventId} {
  allow read: if isAuthenticated();
  allow create: if isAuthenticated();
  allow update, delete: if false;
}
```

### Attendance Collections

```javascript
// Eventos (Events)
match /eventos/{eventoId} {
  allow read, write: if isAuthenticated();
}

// Personas (People)
match /personas/{personaId} {
  allow read, write: if isAuthenticated();
}

// Asistencias (Attendance Records)
match /asistencias/{asistenciaId} {
  allow read, write: if isAuthenticated();
}
```

## Deploying Rules

### Deploy Command

```bash
firebase deploy --only firestore:rules
```

### Verification

After deployment:
1. Open Firebase Console
2. Navigate to Firestore Database → Rules
3. Verify rules match `firestore.rules` file
4. Check for any syntax errors

## Testing Rules

### Test Scenarios

1. **Unauthenticated Access**
   - Should fail for all collections
   - Expected: `PERMISSION_DENIED`

2. **Authenticated User Reading Own Data**
   - Should succeed for `/users/{ownId}`
   - Should succeed for public collections

3. **Vote Casting**
   - Must have valid electionId
   - Must have userId matching auth user
   - Cannot modify existing votes

4. **Admin Operations**
   - Create/edit elections
   - Manage candidates
   - View all results

## Common Issues

### Issue: Permission Denied on Vote Cast

**Error**: `Missing or insufficient permissions`

**Solution**: Ensure vote document contains:
- `electionId`: matches parent election
- `userId`: matches `request.auth.uid`

### Issue: Cannot Read Candidates

**Error**: Empty candidate list despite data existing

**Solution**: 
- Verify user is authenticated
- Check electionId is valid
- Ensure candidate documents have required fields

### Issue: Rules Not Updating

**Problem**: Changes to rules not taking effect

**Solution**:
```bash
# Force re-deploy
firebase deploy --only firestore:rules --force
```

## Best Practices

1. **Always test in development first**
   - Use Firebase emulator for local testing
   - Test with different user roles

2. **Keep rules simple**
   - Complex rules are harder to debug
   - Document complex conditions

3. **Regular audits**
   - Review rules periodically
   - Update as features change

4. **Version control**
   - Keep `firestore.rules` in git
   - Document rule changes

## Related Documentation

- [Firebase Setup](setup/firebase-setup.md)
- [Deployment Guide](../deployment/deployment-guide.md)
- [Troubleshooting](../troubleshooting/windows-issues.md)
