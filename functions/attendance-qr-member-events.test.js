"use strict";

const {describe, it} = require("node:test");
const assert = require("node:assert/strict");

const mod = require("./attendance-qr");
const {
  handleListMemberQrEvents,
  HttpError,
} = mod._test;

function fakeReq({method = "POST", body = {}, headers = {}} = {}) {
  const normalized = {};
  for (const [key, value] of Object.entries(headers)) {
    normalized[String(key).toLowerCase()] = value;
  }
  return {
    method,
    body,
    get(name) {
      return normalized[String(name).toLowerCase()];
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

function fakeDoc(id, data, exists = true) {
  return {
    id,
    exists,
    data() {
      return data;
    },
  };
}

function fakeFirestore({users = {}, members = {}, events = []} = {}) {
  return {
    collection(name) {
      if (name === "users") {
        return {
          doc(id) {
            return {
              async get() {
                return id in users
                  ? fakeDoc(id, users[id], true)
                  : fakeDoc(id, null, false);
              },
            };
          },
        };
      }

      if (name === "members") {
        return {
          doc(id) {
            return {
              async get() {
                return id in members
                  ? fakeDoc(id, members[id], true)
                  : fakeDoc(id, null, false);
              },
            };
          },
        };
      }

      if (name === "attendance_events") {
        return {
          where(field, op, value) {
            assert.equal(op, "==");
            return {
              async get() {
                return {
                  docs: events
                    .filter((event) => event.data[field] === value)
                    .map((event) => fakeDoc(event.id, event.data, true)),
                };
              },
            };
          },
        };
      }

      throw new Error(`unexpected collection ${name}`);
    },
  };
}

async function callEndpoint({
  uid = "uid-active",
  req = fakeReq(),
  users = {"uid-active": {memberId: "member-1", isActive: true}},
  members = {"member-1": {status: "active"}},
  events = [],
  authenticate,
} = {}) {
  const res = fakeRes();
  await handleListMemberQrEvents(req, res, {
    firestore: fakeFirestore({users, members, events}),
    authenticate: authenticate || (async () => uid),
    enforceRateLimit: async () => undefined,
  });
  return res;
}

const baseEvent = {
  nombre: "Asamblea",
  fecha: 1700000000000,
  fechaFin: 1700003600000,
  lugar: "Sede",
  tipo: "asamblea",
  activo: true,
  estado: "programado",
  secureQrMode: "dynamic_member_qr",
};

describe("attendanceListMemberQrEvents endpoint", () => {
  it("active user + active member PASS with sanitized response", async () => {
    const res = await callEndpoint({
      events: [{
        id: "event-open",
        data: {
          ...baseEvent,
          miembrosConvocados: [],
          roster: [{memberId: "other"}],
          asistencia: {other: true},
          createdBy: "admin",
          creadoPor: "admin",
          geofenceEnabled: true,
          latitude: 1.23,
          longitude: 4.56,
        },
      }],
    });

    assert.equal(res.statusCode, 200);
    assert.equal(res.body.ok, true);
    assert.equal(res.body.events.length, 1);
    assert.deepEqual(Object.keys(res.body.events[0]).sort(), [
      "activo",
      "estado",
      "fecha",
      "fechaFin",
      "id",
      "lugar",
      "nombre",
      "secureQrMode",
      "tipo",
    ]);
    assert.equal("miembrosConvocados" in res.body.events[0], false);
    assert.equal("roster" in res.body.events[0], false);
    assert.equal("asistencia" in res.body.events[0], false);
    assert.equal("createdBy" in res.body.events[0], false);
    assert.equal("creadoPor" in res.body.events[0], false);
  });

  it("inactive user DENIED", async () => {
    const res = await callEndpoint({
      users: {"uid-active": {memberId: "member-1", isActive: false}},
    });
    assert.equal(res.statusCode, 403);
    assert.equal(res.body.code, "user-inactive");
  });

  it("user without linked memberId DENIED", async () => {
    const res = await callEndpoint({
      users: {"uid-active": {isActive: true}},
    });
    assert.equal(res.statusCode, 403);
    assert.equal(res.body.code, "missing-memberId");
  });

  it("missing member DENIED", async () => {
    const res = await callEndpoint({members: {}});
    assert.equal(res.statusCode, 404);
    assert.equal(res.body.code, "member-missing");
  });

  it("inactive member DENIED", async () => {
    const res = await callEndpoint({
      members: {"member-1": {status: "inactive"}},
    });
    assert.equal(res.statusCode, 403);
    assert.equal(res.body.code, "member-inactive");
  });

  it("event without convocados is included", async () => {
    const res = await callEndpoint({
      events: [{id: "all-members", data: {...baseEvent, miembrosConvocados: []}}],
    });
    assert.equal(res.statusCode, 200);
    assert.deepEqual(res.body.events.map((event) => event.id), ["all-members"]);
  });

  it("event with convocados includes linked member", async () => {
    const res = await callEndpoint({
      events: [{
        id: "targeted",
        data: {...baseEvent, miembrosConvocados: ["member-1", "member-2"]},
      }],
    });
    assert.equal(res.statusCode, 200);
    assert.deepEqual(res.body.events.map((event) => event.id), ["targeted"]);
  });

  it("event with convocados excludes non-linked member", async () => {
    const res = await callEndpoint({
      events: [{
        id: "not-for-member",
        data: {...baseEvent, miembrosConvocados: ["member-2"]},
      }],
    });
    assert.equal(res.statusCode, 200);
    assert.deepEqual(res.body.events, []);
  });

  it("finalizado event is excluded", async () => {
    const res = await callEndpoint({
      events: [{id: "done", data: {...baseEvent, estado: "finalizado"}}],
    });
    assert.equal(res.statusCode, 200);
    assert.deepEqual(res.body.events, []);
  });

  it("cancelado event is excluded", async () => {
    const res = await callEndpoint({
      events: [{id: "cancelled", data: {...baseEvent, estado: "cancelado"}}],
    });
    assert.equal(res.statusCode, 200);
    assert.deepEqual(res.body.events, []);
  });

  it("inactive event is excluded", async () => {
    const res = await callEndpoint({
      events: [{id: "inactive", data: {...baseEvent, activo: false}}],
    });
    assert.equal(res.statusCode, 200);
    assert.deepEqual(res.body.events, []);
  });

  it("missing Auth DENIED through shared endpoint gate", async () => {
    const res = await callEndpoint({
      authenticate: async () => {
        throw new HttpError(401, "missing-auth");
      },
    });
    assert.equal(res.statusCode, 401);
    assert.equal(res.body.code, "missing-auth");
  });

  it("invalid Auth DENIED through shared endpoint gate", async () => {
    const res = await callEndpoint({
      authenticate: async () => {
        throw new HttpError(401, "invalid-auth");
      },
    });
    assert.equal(res.statusCode, 401);
    assert.equal(res.body.code, "invalid-auth");
  });

  it("missing App Check production-like DENIED through shared endpoint gate", async () => {
    const res = await callEndpoint({
      authenticate: async () => {
        throw new HttpError(401, "missing-app-check");
      },
    });
    assert.equal(res.statusCode, 401);
    assert.equal(res.body.code, "missing-app-check");
  });

  it("valid mock gate PASS", async () => {
    const res = await callEndpoint({
      authenticate: async () => "uid-active",
      events: [{id: "event-open", data: {...baseEvent}}],
    });
    assert.equal(res.statusCode, 200);
    assert.equal(res.body.events.length, 1);
  });
});
