/**
 * Minimal promise-based IndexedDB wrapper. No dependencies — the IDB API is
 * callback-based and this converts it once so the rest of the codebase can
 * use async/await. Handles versioned migrations via the upgrade callback.
 */

export type UpgradeFn = (db: IDBDatabase, oldVersion: number, tx: IDBTransaction) => void;

export function openDatabase(
  name: string,
  version: number,
  upgrade: UpgradeFn,
): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(name, version);
    req.onupgradeneeded = (ev) => {
      upgrade(req.result, ev.oldVersion, req.transaction!);
    };
    req.onsuccess = () => {
      const db = req.result;
      // If another tab upgrades the schema, close so it isn't blocked forever.
      db.onversionchange = () => db.close();
      resolve(db);
    };
    req.onerror = () => reject(req.error ?? new Error(`Failed to open IndexedDB "${name}"`));
    req.onblocked = () => reject(new Error(`IndexedDB "${name}" open blocked by another tab`));
  });
}

/** Await a single IDB request. */
export function idbRequest<T>(req: IDBRequest<T>): Promise<T> {
  return new Promise((resolve, reject) => {
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error ?? new Error('IndexedDB request failed'));
  });
}

/** Await transaction completion (needed after batched writes). */
export function idbTransactionDone(tx: IDBTransaction): Promise<void> {
  return new Promise((resolve, reject) => {
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error ?? new Error('IndexedDB transaction failed'));
    tx.onabort = () => reject(tx.error ?? new Error('IndexedDB transaction aborted'));
  });
}

export function deleteDatabase(name: string): Promise<void> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.deleteDatabase(name);
    req.onsuccess = () => resolve();
    req.onerror = () => reject(req.error ?? new Error(`Failed to delete IndexedDB "${name}"`));
  });
}
