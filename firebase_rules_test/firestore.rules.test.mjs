import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  increment,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'sindicat-rules-test';
let testEnv;

const userData = (role) => ({
  email: `${role.toLowerCase()}@test.local`,
  role,
  createdAt: 1,
  updatedAt: 1,
});

async function seed(path, data) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), path), data);
  });
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: readFileSync('firestore.rules', 'utf8'),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await seed('users/admin', userData('ADMIN'));
  await seed('users/operator', userData('OPERADOR_ASISTENCIA'));
  await seed('users/voter', userData('VOTER'));
  await seed('users/other', userData('VOTER'));
});

after(async () => {
  await testEnv.cleanup();
});

describe('users', () => {
  test('allows self-registration only as VOTER', async () => {
    const voterDb = testEnv.authenticatedContext('new-voter').firestore();
    const adminDb = testEnv.authenticatedContext('new-admin').firestore();

    await assertSucceeds(
      setDoc(doc(voterDb, 'users/new-voter'), userData('VOTER')),
    );
    await assertFails(
      setDoc(doc(adminDb, 'users/new-admin'), {
        ...userData('ADMIN'),
        email: 'new-admin@test.local',
      }),
    );
  });

  test('blocks role escalation on own profile', async () => {
    const escalationDb = testEnv.authenticatedContext('voter').firestore();

    await assertFails(
      updateDoc(doc(escalationDb, 'users/voter'), { role: 'ADMIN' }),
    );

    const profileDb = testEnv.authenticatedContext('voter').firestore();
    await assertSucceeds(
      updateDoc(doc(profileDb, 'users/voter'), {
        displayName: 'Nombre actualizado',
        updatedAt: 2,
      }),
    );
  });

  test('blocks reading another user profile', async () => {
    const db = testEnv.authenticatedContext('voter').firestore();

    await assertSucceeds(getDoc(doc(db, 'users/voter')));
    await assertFails(getDoc(doc(db, 'users/other')));
  });
});

describe('attendance permissions', () => {
  test('allows operator writes and blocks voter writes', async () => {
    const event = {
      nombre: 'Asamblea',
      descripcion: '',
      fecha: 1000,
      lugar: 'Sede',
      tipo: 'asamblea',
      activo: true,
      miembrosConvocados: [],
      modalidadesNoConvocadas: [],
      creadoPor: 'operator',
      createdAt: 1000,
      estado: 'programado',
    };
    const operatorDb = testEnv.authenticatedContext('operator').firestore();
    const voterDb = testEnv.authenticatedContext('voter').firestore();

    await assertSucceeds(
      setDoc(doc(operatorDb, 'attendance_events/event-1'), event),
    );
    await assertFails(
      setDoc(doc(voterDb, 'attendance_events/event-2'), {
        ...event,
        creadoPor: 'voter',
      }),
    );
    await assertSucceeds(
      setDoc(
        doc(operatorDb, 'attendance_events/event-1/asistencias/member-1'),
        {
          personaId: 'member-1',
          eventoId: 'event-1',
          asistio: true,
          fechaRegistro: 1000,
        },
      ),
    );
  });
});

describe('votes', () => {
  beforeEach(async () => {
    const now = Date.now();
    await seed('elections/election-1', {
      isActive: true,
      isVisibleToVoters: true,
      isArchived: false,
      startDate: now - 60_000,
      endDate: now + 60_000,
      totalVotes: 0,
      updatedAt: now,
    });
    await seed('elections/election-1/candidates/candidate-1', {
      name: 'Candidato',
      order: 0,
      voteCount: 0,
    });
  });

  test('allows the atomic vote batch exactly once', async () => {
    const db = testEnv.authenticatedContext('voter').firestore();
    const batch = writeBatch(db);
    const voteRef = doc(db, 'elections/election-1/votes/election-1_voter');
    batch.set(voteRef, {
      electionId: 'election-1',
      userId: 'voter',
      candidateId: 'candidate-1',
      votedAt: serverTimestamp(),
    });
    batch.update(doc(db, 'elections/election-1/candidates/candidate-1'), {
      voteCount: increment(1),
    });
    batch.update(doc(db, 'elections/election-1'), {
      totalVotes: increment(1),
      updatedAt: Date.now(),
    });

    await assertSucceeds(batch.commit());
    await assertFails(setDoc(voteRef, {
      electionId: 'election-1',
      userId: 'voter',
      candidateId: 'candidate-1',
      votedAt: new Date(),
    }));
  });

  test('allows own vote read and blocks another voter vote read', async () => {
    await seed('elections/election-1/votes/election-1_voter', {
      electionId: 'election-1',
      userId: 'voter',
      candidateId: 'candidate-1',
      votedAt: new Date(),
    });
    const voterDb = testEnv.authenticatedContext('voter').firestore();
    const otherDb = testEnv.authenticatedContext('other').firestore();

    await assertSucceeds(
      getDoc(doc(voterDb, 'elections/election-1/votes/election-1_voter')),
    );
    await assertFails(
      getDoc(doc(otherDb, 'elections/election-1/votes/election-1_voter')),
    );
  });
});

describe('audit logs', () => {
  test('allows valid append and rejects delete', async () => {
    const db = testEnv.authenticatedContext('voter').firestore();
    const ref = doc(db, 'audit_logs/log-1');

    await assertSucceeds(
      setDoc(ref, {
        action: 'vote',
        entityType: 'vote',
        entityId: 'election-1_voter',
        userId: 'voter',
        timestamp: Date.now(),
      }),
    );
    await assertFails(updateDoc(ref, { description: 'alterado' }));
    await assertFails(deleteDoc(ref));
  });
});
