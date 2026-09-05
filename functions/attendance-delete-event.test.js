"use strict";

const {describe, it, beforeEach} = require("node:test");
const assert = require("node:assert/strict");

const mod = require("./attendance-qr");
const {handleDeleteEvent, HttpError} = mod._test;

function fakeReq({method = "POST", body = {}} = {}) {
  return {
    method,
    body,
    get() {
      return undefined;
    },
  };
}

function fakeRes() {
  return {
    statusCode: null,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(body) {
      this.body = body;
      return this;
    },
  };
}

function createFakeFirestore({
  users = {},
  events = {},
  attendances = {},
} = {}) {
  return {
    collection(name) {
      if (name === "users") {
        return {
          doc(id) {
            return {
              async get() {
                return {
                  exists: id in users,
                  id,
                  data: () => users[id] || null,
                };
              },
            };
          },
        };
      }
      if (name === "_systemRateLimits") {
        return {
          doc() {
            return {
              async get() {
                return {exists: false, data: () => null};
              },
            };
          },
        };
      }
      if (name === "attendance_events") {
        return {
          doc(eventId) {
            const eventRef = {
              id: eventId,
              async get() {
                return {
                  exists: eventId in events,
                  id: eventId,
                  data: () => events[eventId] || null,
                };
              },
              async set(data) {
                events[eventId] = {...data};
              },
              collection(sub) {
                assert.equal(sub, "asistencias");
                return {
                  limit() {
                    return {
                      async get() {
                        const docs = Object.entries(attendances)
                          .filter(([key]) => key.startsWith(`${eventId}/`))
                          .map(([key, data]) => ({
                            id: key.split("/")[1],
                            data: () => data,
                          }));
                        return {
                          empty: docs.length === 0,
                          size: docs.length,
                          docs,
                        };
                      },
                    };
                  },
                };
              },
            };
            return eventRef;
          },
        };
      }
      throw new Error(`unexpected collection ${name}`);
    },
    async runTransaction(fn) {
      const tx = {
        async get(ref) {
          return ref.get();
        },
        delete(ref) {
          const id = ref.id;
          if (!(id in events)) {
            throw new HttpError(404, "event-missing");
          }
          delete events[id];
        },
      };
      return fn(tx);
    },
  };
}

async function callDelete({
  role = "SUPERADMIN",
  uid = "super-1",
  body = {eventId: "evt-1"},
  events = {"evt-1": {nombre: "A", asistenciaCount: 0}},
  attendances = {},
  authenticate,
} = {}) {
  const firestore = createFakeFirestore({
    users: {[uid]: {role, isActive: true}},
    events: {...events},
    attendances: {...attendances},
  });
  const res = fakeRes();
  await handleDeleteEvent(fakeReq({body}), res, {
    firestore,
    authenticate: authenticate || (async () => uid),
    enforceRateLimit: async () => undefined,
  });
  return {res, firestore, events};
}

describe("attendanceDeleteEvent", () => {
  it("non-SUPERADMIN receives 403 without revealing event state", async () => {
    const {res} = await callDelete({
      role: "ADMIN",
      events: {"secret-event": {nombre: "Hidden", asistenciaCount: 0}},
      body: {eventId: "secret-event"},
    });
    assert.equal(res.statusCode, 403);
    assert.equal(res.body.code, "forbidden");
    assert.equal(res.body.ok, false);
  });

  it("operator receives 403", async () => {
    const {res} = await callDelete({role: "OPERADOR_ASISTENCIA"});
    assert.equal(res.statusCode, 403);
    assert.equal(res.body.code, "forbidden");
  });

  it("missing event returns 404 for SUPERADMIN", async () => {
    const {res} = await callDelete({
      events: {},
      body: {eventId: "missing"},
    });
    assert.equal(res.statusCode, 404);
    assert.equal(res.body.code, "event-missing");
  });

  it("event with attendance returns 409", async () => {
    const {res} = await callDelete({
      events: {"evt-1": {nombre: "A", asistenciaCount: 0}},
      attendances: {"evt-1/a1": {personaId: "m1"}},
    });
    assert.equal(res.statusCode, 409);
    assert.equal(res.body.code, "event-has-attendance");
  });

  it("event with asistenciaCount > 0 returns 409", async () => {
    const {res} = await callDelete({
      events: {"evt-1": {nombre: "A", asistenciaCount: 2}},
      attendances: {},
    });
    assert.equal(res.statusCode, 409);
    assert.equal(res.body.code, "event-has-attendance");
  });

  it("empty event deletes successfully", async () => {
    const store = {"evt-1": {nombre: "A", asistenciaCount: 0}};
    const {res} = await callDelete({events: store});
    assert.equal(res.statusCode, 200);
    assert.equal(res.body.ok, true);
    assert.equal(res.body.deleted, true);
  });

  it("double delete returns controlled 404", async () => {
    const shared = {"evt-1": {nombre: "A", asistenciaCount: 0}};
    const first = await callDelete({events: shared});
    assert.equal(first.res.statusCode, 200);
    const second = await callDelete({events: {}});
    assert.equal(second.res.statusCode, 404);
    assert.equal(second.res.body.code, "event-missing");
  });

  it("invalid eventId rejected with 400", async () => {
    for (const eventId of ["", "a/b", "a\\b", "a.b", "x".repeat(129)]) {
      const {res} = await callDelete({body: {eventId}, events: {}});
      assert.ok(
        res.statusCode === 400,
        `expected 400 for ${JSON.stringify(eventId)} got ${res.statusCode}`,
      );
      assert.ok(
        res.body.code === "invalid-eventId" || res.body.code === "missing-fields",
      );
    }
  });

  it("unauthenticated path surfaces through authenticate failure", async () => {
    const res = fakeRes();
    await handleDeleteEvent(fakeReq(), res, {
      firestore: createFakeFirestore(),
      authenticate: async () => {
        throw new HttpError(401, "missing-app-check");
      },
      enforceRateLimit: async () => undefined,
    });
    assert.equal(res.statusCode, 401);
    assert.equal(res.body.code, "missing-app-check");
  });

  it("legacy missing count + attendance docs → 409 via subcollection", async () => {
    const {res} = await callDelete({
      events: {"leg-1": {nombre: "Legacy"}},
      attendances: {"leg-1/a1": {personaId: "m1"}},
      body: {eventId: "leg-1"},
    });
    assert.equal(res.statusCode, 409);
    assert.equal(res.body.code, "event-has-attendance");
  });

  it("legacy missing count + empty subcollection → delete allowed", async () => {
    const {res} = await callDelete({
      events: {"leg-empty": {nombre: "Legacy empty"}},
      body: {eventId: "leg-empty"},
    });
    assert.equal(res.statusCode, 200);
    assert.equal(res.body.ok, true);
    assert.equal(res.body.deleted, true);
  });
});
