/**
 * Coordinate math shared by every subsystem. All pure functions — unit tested.
 *
 * Conventions:
 *  - World coords: block-space integers (x, y, z), y up.
 *  - Chunk coords: (cx, cz) column indices; world x = cx*16 + localX.
 *  - Local index within a chunk column: (y << 8) | (z << 4) | x
 *    (y-major so vertical scans — terrain gen, lighting — stride 1 page).
 */
import { CHUNK_SIZE_X, CHUNK_SIZE_Y, CHUNK_SIZE_Z } from '../config/constants';

/** Floor-division world coordinate → chunk coordinate (handles negatives). */
export function worldToChunk(w: number): number {
  return Math.floor(w / CHUNK_SIZE_X);
}

/** World coordinate → local 0..15 coordinate within its chunk (handles negatives). */
export function worldToLocal(w: number): number {
  return ((w % CHUNK_SIZE_X) + CHUNK_SIZE_X) % CHUNK_SIZE_X;
}

/** Local (x, y, z) → flat index into a chunk's block array. */
export function localIndex(x: number, y: number, z: number): number {
  return (y << 8) | (z << 4) | x;
}

/** Inverse of {@link localIndex}. */
export function indexToLocal(i: number): { x: number; y: number; z: number } {
  return { x: i & 0xf, z: (i >> 4) & 0xf, y: i >> 8 };
}

export function inChunkBounds(x: number, y: number, z: number): boolean {
  return (
    x >= 0 && x < CHUNK_SIZE_X && y >= 0 && y < CHUNK_SIZE_Y && z >= 0 && z < CHUNK_SIZE_Z
  );
}

/**
 * Pack chunk coords into one number usable as a Map key in hot paths
 * (string keys allocate; this doesn't). Supports |cx|,|cz| < 2^25 —
 * ~536 million blocks from origin, far beyond float-precision playability.
 */
export function chunkKey(cx: number, cz: number): number {
  return (cx + 0x1000000) * 0x2000000 + (cz + 0x1000000);
}

export function unpackChunkKey(key: number): { cx: number; cz: number } {
  const cz = (key % 0x2000000) - 0x1000000;
  const cx = (key - (cz + 0x1000000)) / 0x2000000 - 0x1000000;
  return { cx, cz };
}

/** Persistent (IndexedDB) chunk key — readable, stable across versions. */
export function chunkDbKey(cx: number, cz: number): string {
  return `${cx},${cz}`;
}

export function clamp(v: number, min: number, max: number): number {
  return v < min ? min : v > max ? max : v;
}

export function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}
