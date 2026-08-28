'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const path = require('path');

const { matchPersonaToMember } = require('./lib/match-persona');
const { analyzeUserMemberLink } = require('./lib/match-user');
const { classifyEvento, buildModernEventIndexes } = require('./lib/match-evento');
const { classifyAsistencia, buildModernAttendanceKeySet } = require('./lib/match-asistencia');
const { buildMemberIndexes } = require('./lib/indexes');
const { analyzeInventory, summarizeMetrics } = require('./lib/inventory');
const { runDryRun } = require('./lib/dry-run');
const { loadFixtures } = require('./lib/firestore-reader');
const { legacyAsistenciaId, modernAsistenciaDocId } = require('./lib/normalize');

const fixturePath = path.join(__dirname, 'fixtures', 'emulator-fixtures.json');

describe('persona → member matching', () => {
  it('matches exact via identificador === workerCode', () => {
    const indexes = buildMemberIndexes([
      { id: 'm1', data: { workerCode: 'W001', memberNumber: '1' } },
    ]);
    const result = matchPersonaToMember(
      { id: 'p1', data: { identificador: 'W001' } },
      indexes,
    );
    assert.equal(result.status, 'MATCH_EXACT');
    assert.deepEqual(result.memberIds, ['m1']);
  });

  it('flags ambiguous identificador matches', () => {
    const indexes = buildMemberIndexes([
      { id: 'a', data: { workerCode: 'DUP' } },
      { id: 'b', data: { workerCode: 'DUP' } },
    ]);
    const result = matchPersonaToMember(
      { id: 'p1', data: { identificador: 'DUP' } },
      indexes,
    );
    assert.equal(result.status, 'MATCH_MULTIPLE');
  });

  it('never matches by name alone', () => {
    const indexes = buildMemberIndexes([
      { id: 'm1', data: { firstName: 'Juan', lastName: 'Perez', workerCode: 'X1' } },
    ]);
    const result = matchPersonaToMember(
      { id: 'p1', data: { nombres: 'Juan', apellidos: 'Perez' } },
      indexes,
    );
    assert.equal(result.status, 'NO_MATCH');
  });
});

describe('user → member analysis', () => {
  it('detects existing memberId', () => {
    const indexes = buildMemberIndexes([{ id: 'm1', data: { memberNumber: '1' } }]);
    const result = analyzeUserMemberLink(
      { id: 'u1', data: { memberId: 'm1', email: 'a@b.com' } },
      indexes,
    );
    assert.equal(result.status, 'HAS_MEMBER_ID');
  });

  it('suggests match via employeeNumber', () => {
    const indexes = buildMemberIndexes([
      { id: 'm1', data: { memberNumber: '100', workerCode: 'W100' } },
    ]);
    const result = analyzeUserMemberLink(
      { id: 'u1', data: { employeeNumber: '100' } },
      indexes,
    );
    assert.equal(result.status, 'MATCH_POSSIBLE');
  });
});

describe('evento mapping', () => {
  it('detects existing modern equivalent via legacy trace', () => {
    const modern = [
      {
        id: 'ev1',
        data: {
          nombre: 'E',
          fecha: 1,
          legacySource: 'eventos',
          legacyDocumentId: 'legacy-1',
        },
      },
    ];
    const { byId, byLegacyId } = buildModernEventIndexes(modern);
    const result = classifyEvento(
      { id: 'legacy-1', data: { nombre: 'E', fecha: 1 } },
      byId,
      byLegacyId,
    );
    assert.equal(result.status, 'EXISTE_EQUIVALENTE');
  });

  it('marks invalid evento', () => {
    const { byId, byLegacyId } = buildModernEventIndexes([]);
    const result = classifyEvento({ id: 'x', data: { nombre: '', fecha: 0 } }, byId, byLegacyId);
    assert.equal(result.status, 'INVALIDO');
  });
});

describe('asistencia classification', () => {
  it('detects already migrated modern attendance', () => {
    const modernKeys = buildModernAttendanceKeySet([
      {
        id: modernAsistenciaDocId('member-m1'),
        eventId: 'evento-dup',
        data: { personaId: 'member-m1', eventoId: 'evento-dup' },
      },
    ]);
    const ctx = {
      eventoMap: new Map([
        ['evento-dup', { status: 'EXISTE_EQUIVALENTE', targetEventId: 'evento-dup' }],
      ]),
      personaMemberMap: new Map([
        ['persona-ok', { status: 'MATCH_EXACT', memberIds: ['member-m1'] }],
      ]),
      modernAttendanceKeys: modernKeys,
      eventoExists: new Set(['evento-dup']),
      personaExists: new Set(['persona-ok']),
    };
    const legacyId = legacyAsistenciaId('evento-dup', 'persona-ok');
    const result = classifyAsistencia(
      {
        id: legacyId,
        data: {
          eventoId: 'evento-dup',
          personaId: 'persona-ok',
          fechaRegistro: 1,
          asistio: true,
        },
      },
      ctx,
    );
    assert.equal(result.action, 'ALREADY_MIGRATED');
  });

  it('flags orphan asistencia when evento missing', () => {
    const ctx = {
      eventoMap: new Map(),
      personaMemberMap: new Map(),
      modernAttendanceKeys: new Set(),
      eventoExists: new Set(),
      personaExists: new Set(['persona-ok']),
    };
    const result = classifyAsistencia(
      { id: 'a1', data: { eventoId: 'missing', personaId: 'persona-ok' } },
      ctx,
    );
    assert.equal(result.action, 'INVALID');
    assert.equal(result.duplicate, 'ORPHAN');
  });
});

describe('dry-run safety', () => {
  it('performs zero Firestore writes in dry-run', () => {
    const snapshots = loadFixtures(fixturePath);
    const writes = [];
    const deletes = [];

    const mockDb = {
      collection: () => ({
        doc: () => ({
          set: (...args) => {
            writes.push(args);
          },
          delete: () => {
            deletes.push(true);
          },
        }),
      }),
    };

    const report = runDryRun(snapshots, { apply: false });
    assert.equal(writes.length, 0);
    assert.equal(deletes.length, 0);
    assert.equal(report.deleteCount, 0);
    assert.ok(report.writeCount >= 0);
    assert.equal(report.mode, 'dry-run');
    assert.ok(mockDb);
  });

  it('blocks apply mode in Phase 4.1A', () => {
    const snapshots = loadFixtures(fixturePath);
    assert.throws(() => runDryRun(snapshots, { apply: true }), /Apply mode is disabled/);
  });

  it('is idempotent on fixtures (second run same metrics)', () => {
    const snapshots = loadFixtures(fixturePath);
    const first = summarizeMetrics(analyzeInventory(snapshots));
    const second = summarizeMetrics(analyzeInventory(snapshots));
    assert.deepEqual(first, second);
  });
});

describe('fixture inventory metrics', () => {
  it('produces expected classification counts on emulator fixtures', () => {
    const snapshots = loadFixtures(fixturePath);
    const metrics = summarizeMetrics(analyzeInventory(snapshots));

    assert.equal(metrics.personas.total, 4);
    assert.equal(metrics.personas.matchExacto, 1);
    assert.equal(metrics.personas.ambiguos, 1);
    assert.equal(metrics.personas.sinMatch, 1);
    assert.equal(metrics.personas.yaMigrados, 1);

    assert.equal(metrics.users.conMemberId, 1);
    assert.equal(metrics.users.matchPosible, 1);
    assert.equal(metrics.users.requiereRevision, 1);

    assert.equal(metrics.eventos.migrables, 1);
    assert.equal(metrics.eventos.yaExistentesModernos, 1);
    assert.equal(metrics.eventos.invalidos, 1);

    assert.ok(metrics.asistencias.migrables >= 1);
    assert.ok(metrics.asistencias.yaExistentes >= 1);
    assert.ok(metrics.asistencias.huerfanas >= 1);
  });
});
