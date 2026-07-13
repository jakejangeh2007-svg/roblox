import { describe, it, expect } from 'vitest';
import {
  worldToChunk,
  worldToLocal,
  localIndex,
  indexToLocal,
  inChunkBounds,
  chunkKey,
  unpackChunkKey,
  clamp,
  lerp,
} from './math';
import { BLOCKS_PER_CHUNK, CHUNK_SIZE_X, CHUNK_SIZE_Y, CHUNK_SIZE_Z } from '../config/constants';

describe('worldToChunk / worldToLocal', () => {
  it('maps positive coordinates', () => {
    expect(worldToChunk(0)).toBe(0);
    expect(worldToChunk(15)).toBe(0);
    expect(worldToChunk(16)).toBe(1);
    expect(worldToLocal(0)).toBe(0);
    expect(worldToLocal(15)).toBe(15);
    expect(worldToLocal(16)).toBe(0);
  });

  it('maps negative coordinates with floor semantics', () => {
    expect(worldToChunk(-1)).toBe(-1);
    expect(worldToChunk(-16)).toBe(-1);
    expect(worldToChunk(-17)).toBe(-2);
    expect(worldToLocal(-1)).toBe(15);
    expect(worldToLocal(-16)).toBe(0);
    expect(worldToLocal(-17)).toBe(15);
  });

  it('reconstructs world coordinate from chunk + local', () => {
    for (const w of [-33, -17, -16, -1, 0, 1, 15, 16, 31, 100]) {
      expect(worldToChunk(w) * CHUNK_SIZE_X + worldToLocal(w)).toBe(w);
    }
  });
});

describe('localIndex / indexToLocal', () => {
  it('round-trips every corner and stays in range', () => {
    const corners = [0, 1];
    for (const xi of corners)
      for (const yi of corners)
        for (const zi of corners) {
          const x = xi * (CHUNK_SIZE_X - 1);
          const y = yi * (CHUNK_SIZE_Y - 1);
          const z = zi * (CHUNK_SIZE_Z - 1);
          const i = localIndex(x, y, z);
          expect(i).toBeGreaterThanOrEqual(0);
          expect(i).toBeLessThan(BLOCKS_PER_CHUNK);
          expect(indexToLocal(i)).toEqual({ x, y, z });
        }
  });

  it('is a bijection over the full chunk volume', () => {
    const seen = new Set<number>();
    for (let y = 0; y < CHUNK_SIZE_Y; y += 51)
      for (let z = 0; z < CHUNK_SIZE_Z; z++)
        for (let x = 0; x < CHUNK_SIZE_X; x++) {
          const i = localIndex(x, y, z);
          expect(seen.has(i)).toBe(false);
          seen.add(i);
        }
  });

  it('is y-major (vertical neighbor differs by 256)', () => {
    expect(localIndex(3, 10, 7) + 256).toBe(localIndex(3, 11, 7));
  });
});

describe('inChunkBounds', () => {
  it('accepts interior, rejects exterior', () => {
    expect(inChunkBounds(0, 0, 0)).toBe(true);
    expect(inChunkBounds(15, 255, 15)).toBe(true);
    expect(inChunkBounds(-1, 0, 0)).toBe(false);
    expect(inChunkBounds(16, 0, 0)).toBe(false);
    expect(inChunkBounds(0, 256, 0)).toBe(false);
    expect(inChunkBounds(0, -1, 0)).toBe(false);
    expect(inChunkBounds(0, 0, 16)).toBe(false);
  });
});

describe('chunkKey', () => {
  it('round-trips including negatives and is collision-free nearby', () => {
    const seen = new Set<number>();
    for (let cx = -40; cx <= 40; cx += 5)
      for (let cz = -40; cz <= 40; cz += 5) {
        const k = chunkKey(cx, cz);
        expect(seen.has(k)).toBe(false);
        seen.add(k);
        expect(unpackChunkKey(k)).toEqual({ cx, cz });
      }
  });

  it('round-trips extreme far-lands coordinates', () => {
    for (const [cx, cz] of [
      [0x0ffffff, 0x0ffffff],
      [-0x1000000, -0x1000000],
      [-0x1000000, 0x0ffffff],
    ] as const) {
      expect(unpackChunkKey(chunkKey(cx, cz))).toEqual({ cx, cz });
    }
  });
});

describe('clamp / lerp', () => {
  it('clamps', () => {
    expect(clamp(5, 0, 10)).toBe(5);
    expect(clamp(-5, 0, 10)).toBe(0);
    expect(clamp(15, 0, 10)).toBe(10);
  });
  it('lerps', () => {
    expect(lerp(0, 10, 0.5)).toBe(5);
    expect(lerp(2, 4, 0)).toBe(2);
    expect(lerp(2, 4, 1)).toBe(4);
  });
});
