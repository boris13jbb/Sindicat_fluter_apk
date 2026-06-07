import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, setDoc } from 'firebase/firestore';

const projectId = 'sindicat-rules-test';
let testEnv;

async function seedUser(uid, role) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), `users/${uid}`), {
      email: `${uid}@test.local`,
      role,
    });
  });
}

function imageBytes() {
  return Uint8Array.from([137, 80, 78, 71]);
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: readFileSync('firestore.rules', 'utf8'),
    },
    storage: {
      rules: readFileSync('storage.rules', 'utf8'),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
  await seedUser('superadmin', 'SUPERADMIN');
  await seedUser('admin', 'ADMIN');
  await seedUser('voter', 'VOTER');
});

after(async () => {
  await testEnv.cleanup();
});

describe('candidate photos', () => {
  test('allows admin image upload and blocks voter upload', async () => {
    const path = 'elections/election-1/candidates/candidate-1/photo.png';
    const metadata = { contentType: 'image/png' };
    const adminRef = testEnv.authenticatedContext('admin').storage().ref(path);
    const voterRef = testEnv.authenticatedContext('voter').storage().ref(path);

    await assertSucceeds(adminRef.put(imageBytes(), metadata));
    await assertFails(voterRef.put(imageBytes(), metadata));
  });

  test('blocks non-image candidate uploads', async () => {
    const ref = testEnv
      .authenticatedContext('admin')
      .storage()
      .ref('elections/election-1/candidates/candidate-1/payload.txt');

    await assertFails(ref.put(imageBytes(), { contentType: 'text/plain' }));
  });
});

describe('avatars and branding', () => {
  test('allows only the avatar owner to write its folder', async () => {
    const ownRef = testEnv
      .authenticatedContext('voter')
      .storage()
      .ref('user_avatars/voter/avatar.png');
    const otherRef = testEnv
      .authenticatedContext('admin')
      .storage()
      .ref('user_avatars/voter/avatar.png');

    await assertSucceeds(ownRef.put(imageBytes(), { contentType: 'image/png' }));
    await assertFails(otherRef.put(imageBytes(), { contentType: 'image/png' }));
  });

  test('allows branding upload only to superadmin', async () => {
    const path = 'app_branding/report-logo.png';
    const superadminRef = testEnv
      .authenticatedContext('superadmin')
      .storage()
      .ref(path);
    const adminRef = testEnv.authenticatedContext('admin').storage().ref(path);

    await assertSucceeds(
      superadminRef.put(imageBytes(), { contentType: 'image/png' }),
    );
    await assertFails(adminRef.put(imageBytes(), { contentType: 'image/png' }));
  });
});
