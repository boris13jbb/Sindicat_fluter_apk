'use strict';

const fs = require('fs');
const path = require('path');

/**
 * Carga fixtures locales para emulador/tests.
 * @param {string} fixturePath
 */
function loadFixtures(fixturePath) {
  const raw = fs.readFileSync(fixturePath, 'utf8');
  const data = JSON.parse(raw);
  return normalizeSnapshots(data);
}

/**
 * Lee colecciones desde Firestore (solo lectura).
 * @param {import('firebase-admin/firestore').Firestore} db
 */
async function loadFromFirestore(db) {
  const [personas, eventos, asistencias, members, users, attendanceEvents] =
    await Promise.all([
      readCollection(db, 'personas'),
      readCollection(db, 'eventos'),
      readCollection(db, 'asistencias'),
      readCollection(db, 'members'),
      readCollection(db, 'users'),
      readCollection(db, 'attendance_events'),
    ]);

  const modernAttendances = [];
  for (const ev of attendanceEvents) {
    const sub = await db.collection('attendance_events').doc(ev.id).collection('asistencias').get();
    for (const doc of sub.docs) {
      modernAttendances.push({
        id: doc.id,
        eventId: ev.id,
        data: doc.data(),
      });
    }
  }

  return normalizeSnapshots({
    personas,
    eventos,
    asistencias,
    members,
    users,
    attendanceEvents,
    modernAttendances,
  });
}

/**
 * @param {import('firebase-admin/firestore').Firestore} db
 * @param {string} name
 */
async function readCollection(db, name) {
  const snap = await db.collection(name).get();
  return snap.docs.map((doc) => ({ id: doc.id, data: doc.data() }));
}

function normalizeSnapshots(input) {
  return {
    personas: input.personas ?? [],
    eventos: input.eventos ?? [],
    asistencias: input.asistencias ?? [],
    members: input.members ?? [],
    users: input.users ?? [],
    attendanceEvents: input.attendanceEvents ?? [],
    modernAttendances: input.modernAttendances ?? [],
  };
}

function defaultFixturePath() {
  return path.join(__dirname, '..', 'fixtures', 'emulator-fixtures.json');
}

module.exports = {
  loadFixtures,
  loadFromFirestore,
  defaultFixturePath,
};
