"use strict";

const {describe, it} = require("node:test");
const assert = require("node:assert/strict");
const {
  parseSearchPayload,
  parseMemberLookupPayload,
} = require("./admin-search");

describe("parseSearchPayload", () => {
  it("accepts valid search query", () => {
    const result = parseSearchPayload({query: " ana@test.com ", limit: 10});
    assert.equal(result.error, undefined);
    assert.deepEqual(result.payload, {query: "ana@test.com", limit: 10});
  });

  it("rejects empty query", () => {
    const result = parseSearchPayload({query: "   "});
    assert.match(result.error, /búsqueda/i);
  });

  it("rejects overly long query", () => {
    const result = parseSearchPayload({query: "x".repeat(121)});
    assert.match(result.error, /largo/i);
  });
});

describe("parseMemberLookupPayload", () => {
  it("accepts employee number", () => {
    const result = parseMemberLookupPayload({employeeNumber: " W-100 "});
    assert.equal(result.error, undefined);
    assert.deepEqual(result.payload, {employeeNumber: "W-100"});
  });

  it("rejects missing employee number", () => {
    const result = parseMemberLookupPayload({});
    assert.match(result.error, /obligatorio/i);
  });
});
