'use strict';

const { legacyAsistenciaId } = require('./normalize');

/**
 * Lee colecciones de producción (solo get/list).
 * @param {import('firebase-admin/firestore').Firestore} db
 */
async function loadProductionSnapshots(db) {
  const [personas, eventos, asistenciasRoot, members, users, attendanceEvents] =
    await Promise.all([
      readCollection(db, 'personas'),
      readCollection(db, 'eventos'),
      readCollection(db, 'asistencias'),
      readCollection(db, 'members'),
      readCollection(db, 'users'),
      readCollection(db, 'attendance_events'),
    ]);

  const eventoSubAsistencias = [];
  for (const ev of eventos) {
    const sub = await db
      .collection('eventos')
      .doc(ev.id)
      .collection('asistencias')
      .get();
    for (const doc of sub.docs) {
      eventoSubAsistencias.push({
        id: doc.id,
        eventoId: ev.id,
        source: 'eventos_subcollection',
        data: doc.data(),
      });
    }
  }

  const modernAttendances = [];
  for (const ev of attendanceEvents) {
    const sub = await db
      .collection('attendance_events')
      .doc(ev.id)
      .collection('asistencias')
      .get();
    for (const doc of sub.docs) {
      modernAttendances.push({
        id: doc.id,
        eventId: ev.id,
        data: doc.data(),
      });
    }
  }

  const asistenciasRootTagged = asistenciasRoot.map((row) => ({
    ...row,
    source: 'asistencias_root',
    eventoId: row.data?.eventoId ?? null,
  }));

  const merged = mergeLegacyAsistenciaSources(asistenciasRootTagged, eventoSubAsistencias);

  return {
    personas,
    eventos,
    asistencias: merged.logicalRecords,
    asistenciaPhysical: merged.physical,
    members,
    users,
    attendanceEvents,
    modernAttendances,
    dualWriteStats: merged.dualWriteStats,
  };
}

/**
 * @param {import('firebase-admin/firestore').Firestore} db
 * @param {string} name
 */
async function readCollection(db, name) {
  const snap = await db.collection(name).get();
  return snap.docs.map((doc) => ({ id: doc.id, data: doc.data() }));
}

/**
 * Unifica asistencias raíz y subcolección eventos/{id}/asistencias.
 * @param {Array<{id: string, data: Record<string, unknown>, source: string}>} rootRows
 * @param {Array<{id: string, eventoId: string, source: string, data: Record<string, unknown>}>} subRows
 */
function mergeLegacyAsistenciaSources(rootRows, subRows) {
  /** @type {Map<string, {logicalKey: string, records: Array<Record<string, unknown>>}>} */
  const logicalMap = new Map();

  const ingest = (row, eventoId) => {
    const personaId = row.data?.personaId ?? row.data?.personaID;
    const logicalKey =
      row.data?.eventoId && row.data?.personaId
        ? legacyAsistenciaId(String(row.data.eventoId), String(row.data.personaId))
        : row.id;

    const key = logicalKey || `${eventoId || 'unknown'}:${row.id}`;
    if (!logicalMap.has(key)) {
      logicalMap.set(key, { logicalKey: key, records: [] });
    }
    logicalMap.get(key).records.push({
      id: row.id,
      source: row.source,
      eventoId: eventoId || row.data?.eventoId || null,
      data: row.data,
    });
  };

  for (const row of rootRows) {
    ingest(row, row.data?.eventoId);
  }
  for (const row of subRows) {
    ingest(row, row.eventoId);
  }

  const physicalCount = rootRows.length + subRows.length;
  const logicalRecords = [];
  let dualWriteReplicas = 0;
  let rootOnly = 0;
  let subOnly = 0;
  let bothSources = 0;

  for (const entry of logicalMap.values()) {
    const sources = new Set(entry.records.map((r) => r.source));
    if (sources.has('asistencias_root') && sources.has('eventos_subcollection')) {
      bothSources += 1;
      dualWriteReplicas += entry.records.length - 1;
    } else if (sources.has('asistencias_root')) {
      rootOnly += 1;
    } else {
      subOnly += 1;
    }

    const preferred =
      entry.records.find((r) => r.source === 'asistencias_root') || entry.records[0];
    logicalRecords.push({
      id: preferred.id,
      data: preferred.data,
      _meta: {
        logicalKey: entry.logicalKey,
        physicalCopies: entry.records.length,
        sources: [...sources],
      },
    });
  }

  return {
    logicalRecords,
    physical: {
      rootCount: rootRows.length,
      subcollectionCount: subRows.length,
      physicalTotal: physicalCount,
      logicalUnique: logicalMap.size,
      dualWritePairs: bothSources,
      dualWriteExtraReplicas: dualWriteReplicas,
      rootOnly,
      subOnly,
    },
    dualWriteStats: {
      physicalTotal: physicalCount,
      logicalUnique: logicalMap.size,
      dualWritePairs: bothSources,
      dualWriteExtraReplicas: dualWriteReplicas,
      rootOnly,
      subOnly,
    },
  };
}

module.exports = {
  loadProductionSnapshots,
  mergeLegacyAsistenciaSources,
  readCollection,
};
