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
  getDocs,
  collection,
  collectionGroup,
  query,
  where,
  limit,
  increment,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'sindicat-rules-test';
let testEnv;

const userData = (role, overrides = {}) => ({
  email: `${role.toLowerCase()}@test.local`,
  role,
  createdAt: 1,
  updatedAt: 1,
  ...overrides,
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
  await seed('users/superadmin', userData('SUPERADMIN'));
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

  test('allows superadmin to read and manage other users', async () => {
    await seed('members/member-1', {
      memberNumber: '100',
      firstName: 'Ana',
      lastName: 'Perez',
      fullName: 'Ana Perez',
      workerCode: 'W-100',
      status: 'active',
      createdAt: 1,
      updatedAt: 1,
    });

    const superDb = testEnv.authenticatedContext('superadmin').firestore();

    await assertSucceeds(getDoc(doc(superDb, 'users/voter')));
    await assertSucceeds(
      updateDoc(doc(superDb, 'users/voter'), {
        role: 'OPERADOR_ASISTENCIA',
        updatedAt: 2,
      }),
    );
    await assertSucceeds(
      updateDoc(doc(superDb, 'users/voter'), {
        memberId: 'member-1',
        employeeNumber: 'W-100',
        updatedAt: 3,
      }),
    );
    await assertSucceeds(
      updateDoc(doc(superDb, 'users/voter'), {
        isActive: false,
        updatedAt: 4,
      }),
    );
  });

  test('blocks non-superadmin from changing another user role', async () => {
    const adminDb = testEnv.authenticatedContext('admin').firestore();

    await assertFails(
      updateDoc(doc(adminDb, 'users/voter'), {
        role: 'ADMIN',
        updatedAt: 2,
      }),
    );
  });

  test('allows superadmin to link VOTER to active member', async () => {
    await seed('members/member-active', {
      memberNumber: '101',
      firstName: 'Luis',
      lastName: 'Activo',
      fullName: 'Luis Activo',
      workerCode: 'W-101',
      status: 'active',
      createdAt: 1,
      updatedAt: 1,
    });

    const superDb = testEnv.authenticatedContext('superadmin').firestore();

    await assertSucceeds(
      updateDoc(doc(superDb, 'users/voter'), {
        memberId: 'member-active',
        employeeNumber: 'W-101',
        role: 'VOTER',
        updatedAt: 2,
      }),
    );
  });

  test('blocks superadmin from linking VOTER to inactive member', async () => {
    await seed('members/member-inactive', {
      memberNumber: '102',
      firstName: 'Ina',
      lastName: 'Ctiva',
      fullName: 'Ina Ctiva',
      workerCode: 'W-102',
      status: 'inactive',
      createdAt: 1,
      updatedAt: 1,
    });

    const superDb = testEnv.authenticatedContext('superadmin').firestore();

    await assertFails(
      updateDoc(doc(superDb, 'users/voter'), {
        memberId: 'member-inactive',
        employeeNumber: 'W-102',
        role: 'VOTER',
        updatedAt: 2,
      }),
    );
  });

  test('allows superadmin to link non-voter to inactive member', async () => {
    await seed('members/member-inactive', {
      memberNumber: '103',
      firstName: 'Admin',
      lastName: 'Socio',
      fullName: 'Admin Socio',
      workerCode: 'W-103',
      status: 'inactive',
      createdAt: 1,
      updatedAt: 1,
    });

    const superDb = testEnv.authenticatedContext('superadmin').firestore();

    await assertSucceeds(
      updateDoc(doc(superDb, 'users/admin'), {
        memberId: 'member-inactive',
        employeeNumber: 'W-103',
        role: 'ADMIN',
        updatedAt: 2,
      }),
    );
  });

  test('allows superadmin to unlink memberId from user', async () => {
    await seed('members/member-active', {
      memberNumber: '104',
      firstName: 'Un',
      lastName: 'Link',
      fullName: 'Un Link',
      workerCode: 'W-104',
      status: 'active',
      createdAt: 1,
      updatedAt: 1,
    });
    await seed('users/voter', {
      ...userData('VOTER'),
      memberId: 'member-active',
      employeeNumber: 'W-104',
    });

    const superDb = testEnv.authenticatedContext('superadmin').firestore();

    await assertSucceeds(
      updateDoc(doc(superDb, 'users/voter'), {
        memberId: null,
        updatedAt: 2,
      }),
    );
  });
});

describe('attendance permissions', () => {
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

  async function seedOperationalReadFixtures() {
    await seed('attendance_events/event-read', event);
    await seed('attendance_events/event-read/asistencias/member-1', {
      personaId: 'member-1',
      eventoId: 'event-read',
      asistio: true,
      fechaRegistro: 1000,
    });
    await seed('eventos/legacy-event', {
      nombre: 'Legacy',
      fecha: 1000,
      activo: true,
      creadoPor: 'operator',
    });
    await seed('eventos/legacy-event/asistencias/legacy-att', {
      personaId: 'legacy-member',
      eventoId: 'legacy-event',
      asistio: true,
      fechaRegistro: 1000,
    });
    await seed('personas/persona-1', {
      nombre: 'Persona',
      identificador: 'P-1',
      activo: true,
    });
    await seed('asistencias/top-level-att', {
      personaId: 'persona-1',
      eventoId: 'legacy-event',
      asistio: true,
      fechaRegistro: 1000,
    });
    await seed('events/audit-event', {
      type: 'attendance',
      actor: 'operator',
      timestamp: 1000,
    });
  }

  test('allows operator to create attendance event; voter denied', async () => {
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
  });

  test('VOTER cannot read operational attendance collections', async () => {
    await seedOperationalReadFixtures();
    const voterDb = testEnv.authenticatedContext('voter').firestore();

    await assertFails(getDoc(doc(voterDb, 'attendance_events/event-read')));
    await assertFails(
      getDoc(doc(voterDb, 'attendance_events/event-read/asistencias/member-1')),
    );
    await assertFails(getDoc(doc(voterDb, 'eventos/legacy-event')));
    await assertFails(
      getDoc(doc(voterDb, 'eventos/legacy-event/asistencias/legacy-att')),
    );
    await assertFails(getDoc(doc(voterDb, 'personas/persona-1')));
    await assertFails(getDoc(doc(voterDb, 'asistencias/top-level-att')));
    await assertFails(getDoc(doc(voterDb, 'events/audit-event')));
    await assertFails(
      getDocs(query(collectionGroup(voterDb, 'asistencias'), limit(10))),
    );
  });

  test('active operational roles can read attendance collections', async () => {
    await seedOperationalReadFixtures();
    for (const uid of ['operator', 'admin', 'superadmin']) {
      const db = testEnv.authenticatedContext(uid).firestore();
      await assertSucceeds(getDoc(doc(db, 'attendance_events/event-read')));
      await assertSucceeds(
        getDoc(doc(db, 'attendance_events/event-read/asistencias/member-1')),
      );
      await assertSucceeds(getDoc(doc(db, 'eventos/legacy-event')));
      await assertSucceeds(
        getDoc(doc(db, 'eventos/legacy-event/asistencias/legacy-att')),
      );
      await assertSucceeds(getDoc(doc(db, 'personas/persona-1')));
      await assertSucceeds(getDoc(doc(db, 'asistencias/top-level-att')));
      await assertSucceeds(getDoc(doc(db, 'events/audit-event')));
      await assertSucceeds(
        getDocs(query(collectionGroup(db, 'asistencias'), limit(10))),
      );
    }
  });

  test('inactive privileged users cannot read attendance collections', async () => {
    await seedOperationalReadFixtures();
    await seed(
      'users/inactive-operator',
      userData('OPERADOR_ASISTENCIA', {isActive: false}),
    );
    await seed('users/inactive-admin', userData('ADMIN', {isActive: false}));

    const inactiveOperatorDb =
      testEnv.authenticatedContext('inactive-operator').firestore();
    const inactiveAdminDb =
      testEnv.authenticatedContext('inactive-admin').firestore();

    await assertFails(
      getDoc(doc(inactiveOperatorDb, 'attendance_events/event-read')),
    );
    await assertFails(getDoc(doc(inactiveOperatorDb, 'personas/persona-1')));
    await assertFails(getDoc(doc(inactiveAdminDb, 'attendance_events/event-read')));
    await assertFails(
      getDocs(
        query(collectionGroup(inactiveOperatorDb, 'asistencias'), limit(10)),
      ),
    );
  });

  test('1 VOTER intenta crear attendance → DENIED', async () => {
    await seed('attendance_events/event-voter', event);
    const voterDb = testEnv.authenticatedContext('voter').firestore();
    await assertFails(
      setDoc(
        doc(voterDb, 'attendance_events/event-voter/asistencias/m1'),
        {
          personaId: 'm1',
          eventoId: 'event-voter',
          asistio: true,
          fechaRegistro: 1000,
        },
      ),
    );
  });

  test('2 OPERADOR intenta crear secure_qr_v2 → DENIED', async () => {
    await seed('attendance_events/event-op-secure', event);
    const operatorDb = testEnv.authenticatedContext('operator').firestore();
    await assertFails(
      setDoc(
        doc(operatorDb, 'attendance_events/event-op-secure/asistencias/m1'),
        {
          personaId: 'm1',
          eventoId: 'event-op-secure',
          asistio: true,
          fechaRegistro: 1000,
          metodoRegistro: 'SECURE_QR_V2',
          registradoPor: 'operator',
          justificacion: 'x',
        },
      ),
    );
  });

  test('3 ADMIN intenta crear secure_qr_v2 → DENIED', async () => {
    await seed('attendance_events/event-admin-secure', event);
    const adminDb = testEnv.authenticatedContext('admin').firestore();
    await assertFails(
      setDoc(
        doc(adminDb, 'attendance_events/event-admin-secure/asistencias/m1'),
        {
          personaId: 'm1',
          eventoId: 'event-admin-secure',
          asistio: true,
          fechaRegistro: 1000,
          metodoRegistro: 'SECURE_QR_V2',
          registradoPor: 'admin',
          justificacion: 'bypass',
        },
      ),
    );
  });

  test('4 device member direct client write → DENIED', async () => {
    const operatorDb = testEnv.authenticatedContext('operator').firestore();
    await assertFails(
      setDoc(doc(operatorDb, 'attendance_member_devices/dev-1'), {
        deviceId: 'dev-1',
        memberId: 'm1',
        publicKey: 'abc',
        status: 'active',
      }),
    );
  });

  test('5 scanner direct client write → DENIED', async () => {
    const adminDb = testEnv.authenticatedContext('admin').firestore();
    await assertFails(
      setDoc(doc(adminDb, 'attendance_scanner_devices/scn-1'), {
        scannerId: 'scn-1',
        publicKey: 'abc',
        status: 'active',
      }),
    );
  });

  test('member device registry read is limited to active linked user or operators', async () => {
    await seed('users/voter', {
      ...userData('VOTER'),
      memberId: 'member-1',
    });
    await seed('users/inactive-linked-voter', {
      ...userData('VOTER'),
      memberId: 'member-1',
      isActive: false,
    });
    await seed('attendance_member_devices/dev-1', {
      deviceId: 'dev-1',
      memberId: 'member-1',
      status: 'active',
    });

    const voterDb = testEnv.authenticatedContext('voter').firestore();
    const otherDb = testEnv.authenticatedContext('other').firestore();
    const inactiveDb =
      testEnv.authenticatedContext('inactive-linked-voter').firestore();
    const operatorDb = testEnv.authenticatedContext('operator').firestore();

    await assertSucceeds(getDoc(doc(voterDb, 'attendance_member_devices/dev-1')));
    await assertFails(getDoc(doc(otherDb, 'attendance_member_devices/dev-1')));
    await assertFails(getDoc(doc(inactiveDb, 'attendance_member_devices/dev-1')));
    await assertSucceeds(
      getDoc(doc(operatorDb, 'attendance_member_devices/dev-1')),
    );
  });

  test('scanner device registry read is limited to active operational roles', async () => {
    await seed('attendance_scanner_devices/scn-read', {
      scannerId: 'scn-read',
      publicKey: 'abc',
      status: 'active',
    });
    await seed(
      'users/inactive-operator',
      userData('OPERADOR_ASISTENCIA', {isActive: false}),
    );

    const voterDb = testEnv.authenticatedContext('voter').firestore();
    const operatorDb = testEnv.authenticatedContext('operator').firestore();
    const inactiveDb =
      testEnv.authenticatedContext('inactive-operator').firestore();

    await assertFails(getDoc(doc(voterDb, 'attendance_scanner_devices/scn-read')));
    await assertSucceeds(
      getDoc(doc(operatorDb, 'attendance_scanner_devices/scn-read')),
    );
    await assertFails(
      getDoc(doc(inactiveDb, 'attendance_scanner_devices/scn-read')),
    );
  });

  test('7 manual override sin motivo → DENIED', async () => {
    await seed('attendance_events/event-mo', event);
    const operatorDb = testEnv.authenticatedContext('operator').firestore();
    await assertFails(
      setDoc(
        doc(operatorDb, 'attendance_events/event-mo/asistencias/m1'),
        {
          personaId: 'm1',
          eventoId: 'event-mo',
          asistio: true,
          fechaRegistro: 1000,
          metodoRegistro: 'MANUAL_OVERRIDE',
          justificacion: '',
          registradoPor: 'operator',
        },
      ),
    );
    await assertFails(
      setDoc(
        doc(operatorDb, 'attendance_events/event-mo/asistencias/m2'),
        {
          personaId: 'm2',
          eventoId: 'event-mo',
          asistio: true,
          fechaRegistro: 1000,
          metodoRegistro: 'MANUAL_OVERRIDE',
          registradoPor: 'operator',
        },
      ),
    );
  });

  test('8 manual override con rol no autorizado (VOTER) → DENIED', async () => {
    await seed('attendance_events/event-mo-voter', event);
    const voterDb = testEnv.authenticatedContext('voter').firestore();
    await assertFails(
      setDoc(
        doc(voterDb, 'attendance_events/event-mo-voter/asistencias/m1'),
        {
          personaId: 'm1',
          eventoId: 'event-mo-voter',
          asistio: true,
          fechaRegistro: 1000,
          metodoRegistro: 'MANUAL_OVERRIDE',
          justificacion: 'motivo valido de override',
          registradoPor: 'voter',
        },
      ),
    );
  });

  test('9 manual override bien formado por OPERADOR → ALLOWED', async () => {
    await seed('attendance_events/event-mo-ok', event);
    const operatorDb = testEnv.authenticatedContext('operator').firestore();
    await assertSucceeds(
      setDoc(
        doc(operatorDb, 'attendance_events/event-mo-ok/asistencias/m1'),
        {
          personaId: 'm1',
          eventoId: 'event-mo-ok',
          asistio: true,
          fechaRegistro: 1000,
          metodoRegistro: 'MANUAL_OVERRIDE',
          justificacion: 'camara fallida - verificacion visual',
          registradoPor: 'operator',
        },
      ),
    );
  });

  test('allows legacy operator attendance without metodoRegistro', async () => {
    await seed('attendance_events/event-legacy', event);
    const operatorDb = testEnv.authenticatedContext('operator').firestore();
    await assertSucceeds(
      setDoc(
        doc(operatorDb, 'attendance_events/event-legacy/asistencias/member-1'),
        {
          personaId: 'member-1',
          eventoId: 'event-legacy',
          asistio: true,
          fechaRegistro: 1000,
        },
      ),
    );
  });
});

describe('election read RBAC', () => {
  const now = Date.now();
  const baseElection = {
    title: 'Elección visible',
    description: '',
    isActive: true,
    isVisibleToVoters: true,
    isArchived: false,
    startDate: now - 60_000,
    endDate: now + 60_000,
    totalVotes: 0,
    createdAt: now,
    updatedAt: now,
  };

  async function seedElectionReadFixtures() {
    await seed('elections/visible-active', baseElection);
    await seed('elections/visible-active/candidates/candidate-1', {
      name: 'Visible',
      order: 0,
      voteCount: 0,
    });

    await seed('elections/hidden', {
      ...baseElection,
      title: 'Oculta',
      isVisibleToVoters: false,
    });
    await seed('elections/hidden/candidates/candidate-1', {
      name: 'Hidden',
      order: 0,
      voteCount: 0,
    });

    await seed('elections/draft', {
      ...baseElection,
      title: 'Borrador',
      isActive: false,
    });
    await seed('elections/draft/candidates/candidate-1', {
      name: 'Draft',
      order: 0,
      voteCount: 0,
    });

    await seed('elections/archived', {
      ...baseElection,
      title: 'Archivada',
      isArchived: true,
    });
    await seed('elections/archived/candidates/candidate-1', {
      name: 'Archived',
      order: 0,
      voteCount: 0,
    });
  }

  test('active VOTER reads only visible active non-archived election', async () => {
    await seedElectionReadFixtures();
    const voterDb = testEnv.authenticatedContext('voter').firestore();

    await assertSucceeds(getDoc(doc(voterDb, 'elections/visible-active')));
    await assertFails(getDoc(doc(voterDb, 'elections/hidden')));
    await assertFails(getDoc(doc(voterDb, 'elections/draft')));
    await assertFails(getDoc(doc(voterDb, 'elections/archived')));
  });

  test('active VOTER candidates inherit parent election visibility', async () => {
    await seedElectionReadFixtures();
    const voterDb = testEnv.authenticatedContext('voter').firestore();

    await assertSucceeds(
      getDoc(doc(voterDb, 'elections/visible-active/candidates/candidate-1')),
    );
    await assertFails(
      getDoc(doc(voterDb, 'elections/hidden/candidates/candidate-1')),
    );
    await assertFails(
      getDoc(doc(voterDb, 'elections/draft/candidates/candidate-1')),
    );
    await assertFails(
      getDoc(doc(voterDb, 'elections/archived/candidates/candidate-1')),
    );
  });

  test('ADMIN can read all election states and candidates', async () => {
    await seedElectionReadFixtures();
    const adminDb = testEnv.authenticatedContext('admin').firestore();

    for (const electionId of ['visible-active', 'hidden', 'draft', 'archived']) {
      await assertSucceeds(getDoc(doc(adminDb, `elections/${electionId}`)));
      await assertSucceeds(
        getDoc(doc(adminDb, `elections/${electionId}/candidates/candidate-1`)),
      );
    }
  });

  test('inactive VOTER cannot read elections or candidates', async () => {
    await seedElectionReadFixtures();
    await seed(
      'users/inactive-voter',
      userData('VOTER', {isActive: false, memberId: 'member-1'}),
    );
    const db = testEnv.authenticatedContext('inactive-voter').firestore();

    for (const electionId of ['visible-active', 'hidden', 'draft', 'archived']) {
      await assertFails(getDoc(doc(db, `elections/${electionId}`)));
      await assertFails(
        getDoc(doc(db, `elections/${electionId}/candidates/candidate-1`)),
      );
    }
  });

  test('VOTER query must match visible active non-archived constraints', async () => {
    await seedElectionReadFixtures();
    const voterDb = testEnv.authenticatedContext('voter').firestore();

    await assertSucceeds(
      getDocs(
        query(
          collection(voterDb, 'elections'),
          where('isVisibleToVoters', '==', true),
          where('isActive', '==', true),
          where('isArchived', '==', false),
          limit(10),
        ),
      ),
    );
    await assertFails(getDocs(collection(voterDb, 'elections')));
  });
});

describe('votes', () => {
  const activeMember = {
    memberNumber: '200',
    firstName: 'Voto',
    lastName: 'Activo',
    fullName: 'Voto Activo',
    workerCode: 'W-200',
    status: 'active',
    createdAt: 1,
    updatedAt: 1,
  };

  const inactiveMember = {
    ...activeMember,
    memberNumber: '201',
    workerCode: 'W-201',
    fullName: 'Voto Inactivo',
    status: 'inactive',
  };

  async function seedOpenElection() {
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
  }

  async function commitVoteBatch(db, userId) {
    const batch = writeBatch(db);
    const voteRef = doc(db, `elections/election-1/votes/election-1_${userId}`);
    batch.set(voteRef, {
      electionId: 'election-1',
      userId,
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
    return batch.commit();
  }

  beforeEach(async () => {
    await seedOpenElection();
    await seed('members/member-active', activeMember);
    await seed('users/voter', {
      ...userData('VOTER'),
      memberId: 'member-active',
      employeeNumber: 'W-200',
    });
  });

  test('allows the atomic vote batch exactly once', async () => {
    const db = testEnv.authenticatedContext('voter').firestore();

    await assertSucceeds(commitVoteBatch(db, 'voter'));
    await assertFails(
      setDoc(doc(db, 'elections/election-1/votes/election-1_voter'), {
        electionId: 'election-1',
        userId: 'voter',
        candidateId: 'candidate-1',
        votedAt: new Date(),
      }),
    );
  });

  test('allows VOTER with active member to create vote when requireAttendance is false', async () => {
    const db = testEnv.authenticatedContext('voter').firestore();
    await assertSucceeds(commitVoteBatch(db, 'voter'));
  });

  test('blocks VOTER with inactive member from creating vote', async () => {
    await seed('members/member-inactive', inactiveMember);
    await seed('users/inactive-member-voter', {
      ...userData('VOTER'),
      memberId: 'member-inactive',
      employeeNumber: 'W-201',
    });

    const db = testEnv.authenticatedContext('inactive-member-voter').firestore();
    await assertFails(commitVoteBatch(db, 'inactive-member-voter'));
  });

  test('blocks VOTER with inactive member even when attendance would be required', async () => {
    await seed('members/member-inactive', inactiveMember);
    await seed('users/inactive-member-voter', {
      ...userData('VOTER'),
      memberId: 'member-inactive',
      employeeNumber: 'W-201',
    });

    const db = testEnv.authenticatedContext('inactive-member-voter').firestore();
    await assertFails(commitVoteBatch(db, 'inactive-member-voter'));
  });

  test('blocks VOTER without memberId from creating vote', async () => {
    await seed('users/no-member-voter', userData('VOTER'));

    const db = testEnv.authenticatedContext('no-member-voter').firestore();
    await assertFails(commitVoteBatch(db, 'no-member-voter'));
  });

  test('blocks vote when memberId points to a missing member', async () => {
    await seed('users/missing-member-voter', {
      ...userData('VOTER'),
      memberId: 'member-missing',
      employeeNumber: 'W-999',
    });

    const db = testEnv.authenticatedContext('missing-member-voter').firestore();
    await assertFails(commitVoteBatch(db, 'missing-member-voter'));
  });

  test('blocks vote payload that tries to use another user id', async () => {
    const db = testEnv.authenticatedContext('voter').firestore();
    const voteRef = doc(db, 'elections/election-1/votes/election-1_voter');

    await assertFails(
      setDoc(voteRef, {
        electionId: 'election-1',
        userId: 'other',
        candidateId: 'candidate-1',
        votedAt: serverTimestamp(),
      }),
    );
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

  test('blocks inactive voter from casting a vote', async () => {
    await seed('users/inactive-voter', {
      ...userData('VOTER'),
      email: 'inactive@test.local',
      isActive: false,
      memberId: 'member-active',
      employeeNumber: 'W-200',
    });

    const db = testEnv.authenticatedContext('inactive-voter').firestore();

    await assertFails(commitVoteBatch(db, 'inactive-voter'));
  });

  test('blocks vote update and delete', async () => {
    await seed('elections/election-1/votes/election-1_voter', {
      electionId: 'election-1',
      userId: 'voter',
      candidateId: 'candidate-1',
      votedAt: new Date(),
    });
    const db = testEnv.authenticatedContext('voter').firestore();
    const voteRef = doc(db, 'elections/election-1/votes/election-1_voter');

    await assertFails(
      updateDoc(voteRef, { candidateId: 'candidate-1' }),
    );
    await assertFails(deleteDoc(voteRef));
  });
});

describe('members', () => {
  const memberData = {
    memberNumber: '100',
    firstName: 'Ana',
    lastName: 'Perez',
    fullName: 'Ana Perez',
    workerCode: 'W-100',
    status: 'active',
    createdAt: 1,
    updatedAt: 1,
  };

  beforeEach(async () => {
    await seed('members/member-1', memberData);
    await seed('members/member-2', {
      ...memberData,
      memberNumber: '101',
      workerCode: 'W-101',
      fullName: 'Otro Socio',
    });
    await seed('users/voter', {
      ...userData('VOTER'),
      memberId: 'member-1',
      employeeNumber: 'W-100',
    });
  });

  test('blocks unauthenticated reads', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'members/member-1')));
  });

  test('allows voter to get only linked member', async () => {
    const voterDb = testEnv.authenticatedContext('voter').firestore();
    await assertSucceeds(getDoc(doc(voterDb, 'members/member-1')));
    await assertFails(getDoc(doc(voterDb, 'members/member-2')));
  });

  test('blocks inactive voter from reading own linked member', async () => {
    await seed(
      'users/inactive-voter',
      userData('VOTER', {
        isActive: false,
        memberId: 'member-1',
        employeeNumber: 'W-100',
      }),
    );
    const inactiveDb = testEnv.authenticatedContext('inactive-voter').firestore();
    await assertFails(getDoc(doc(inactiveDb, 'members/member-1')));
  });

  test('blocks voter from listing members collection', async () => {
    const voterDb = testEnv.authenticatedContext('voter').firestore();
    await assertFails(getDocs(collection(voterDb, 'members')));
    await assertFails(
      getDocs(query(collection(voterDb, 'members'), limit(400))),
    );
  });

  test('allows admin to list members', async () => {
    const adminDb = testEnv.authenticatedContext('admin').firestore();
    await assertSucceeds(getDocs(collection(adminDb, 'members')));
  });

  test('allows operator to list members', async () => {
    const operatorDb = testEnv.authenticatedContext('operator').firestore();
    await assertSucceeds(getDocs(collection(operatorDb, 'members')));
  });

  test('blocks voter from reading another user profile', async () => {
    const voterDb = testEnv.authenticatedContext('voter').firestore();
    await assertFails(getDoc(doc(voterDb, 'users/other')));
  });

  test('blocks admin from listing users collection', async () => {
    const adminDb = testEnv.authenticatedContext('admin').firestore();
    await assertFails(getDocs(collection(adminDb, 'users')));
  });

  test('allows superadmin to list users', async () => {
    const superDb = testEnv.authenticatedContext('superadmin').firestore();
    await assertSucceeds(getDocs(collection(superDb, 'users')));
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

  test('blocks inactive client audit log append', async () => {
    await seed('users/inactive-voter', userData('VOTER', {isActive: false}));
    const db = testEnv.authenticatedContext('inactive-voter').firestore();
    await assertFails(
      setDoc(doc(db, 'audit_logs/inactive-log'), {
        action: 'vote',
        entityType: 'vote',
        entityId: 'election-1_inactive-voter',
        userId: 'inactive-voter',
        timestamp: Date.now(),
      }),
    );
  });
});
