'use strict';

/** @type {{ writesAttempted: number, deletesAttempted: number }} */
const audit = {
  writesAttempted: 0,
  deletesAttempted: 0,
};

const WRITE_METHODS = new Set(['set', 'update', 'create', 'delete', 'add']);

function recordWrite(method) {
  if (method === 'delete') {
    audit.deletesAttempted += 1;
  } else {
    audit.writesAttempted += 1;
  }
}

/**
 * @param {unknown} target
 */
function wrapReference(target) {
  if (!target || typeof target !== 'object') return target;

  return new Proxy(target, {
    get(obj, prop, receiver) {
      if (WRITE_METHODS.has(String(prop))) {
        return () => {
          recordWrite(String(prop));
          throw new Error(`${String(prop)} is blocked in production read-only mode`);
        };
      }
      if (prop === 'collection') {
        const fn = Reflect.get(obj, prop, receiver);
        return (...args) => wrapReference(fn.apply(obj, args));
      }
      if (prop === 'doc') {
        const fn = Reflect.get(obj, prop, receiver);
        return (...args) => wrapReference(fn.apply(obj, args));
      }
      const value = Reflect.get(obj, prop, receiver);
      if (typeof value === 'function') {
        return value.bind(obj);
      }
      return value;
    },
  });
}

/**
 * @param {import('firebase-admin/firestore').Firestore} db
 */
function createReadonlyFirestore(db) {
  const wrapped = wrapReference(db);

  return new Proxy(wrapped, {
    get(target, prop, receiver) {
      if (prop === 'batch') {
        return () => createBlockedBatch();
      }
      if (prop === 'bulkWriter') {
        return () => {
          recordWrite('bulkWriter');
          throw new Error('bulkWriter is blocked in production read-only mode');
        };
      }
      if (prop === 'runTransaction') {
        return () => {
          recordWrite('runTransaction');
          throw new Error('runTransaction is blocked in production read-only mode');
        };
      }
      return Reflect.get(target, prop, receiver);
    },
  });
}

function createBlockedBatch() {
  return new Proxy(
    {},
    {
      get(_target, prop) {
        if (prop === 'commit') {
          return async () => {
            recordWrite('batch.commit');
            throw new Error('batch.commit is blocked in production read-only mode');
          };
        }
        if (WRITE_METHODS.has(String(prop))) {
          return () => {
            recordWrite(`batch.${String(prop)}`);
            throw new Error(`batch.${String(prop)} is blocked in production read-only mode`);
          };
        }
        return () => createBlockedBatch();
      },
    },
  );
}

function resetAudit() {
  audit.writesAttempted = 0;
  audit.deletesAttempted = 0;
}

function getAudit() {
  return { ...audit };
}

module.exports = {
  createReadonlyFirestore,
  wrapReference,
  resetAudit,
  getAudit,
};
