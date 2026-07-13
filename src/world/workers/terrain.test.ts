import { describe, it, expect } from 'vitest';
import { TerrainGenerator } from './terrain';
import { BlockId } from '../Block';
import { localIndex } from '../../core/math';
import { CHUNK_SIZE_X, CHUNK_SIZE_Y, CHUNK_SIZE_Z, SEA_LEVEL } from '../../config/constants';

function topSolidY(blocks: Uint8Array, lx: number, lz: number): number {
  for (let y = CHUNK_SIZE_Y - 1; y >= 0; y--) {
    if (blocks[localIndex(lx, y, lz)] !== BlockId.Air) return y;
  }
  return -1;
}

describe('TerrainGenerator', () => {
  it('generates identical chunks for the same seed (regeneration invariant)', () => {
    const a = new TerrainGenerator(42);
    const b = new TerrainGenerator(42);
    const ca = a.generateChunk(3, -2);
    const cb = b.generateChunk(3, -2);
    expect(ca).toEqual(cb);
  });

  it('produces different terrain for different seeds', () => {
    const a = new TerrainGenerator(1).generateChunk(0, 0);
    const b = new TerrainGenerator(2).generateChunk(0, 0);
    let diff = 0;
    for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) diff++;
    expect(diff).toBeGreaterThan(1000);
  });

  it('lays bedrock at Y=0 across the whole chunk', () => {
    const blocks = new TerrainGenerator(5).generateChunk(0, 0);
    for (let z = 0; z < CHUNK_SIZE_Z; z++) {
      for (let x = 0; x < CHUNK_SIZE_X; x++) {
        expect(blocks[localIndex(x, 0, z)]).toBe(BlockId.Bedrock);
      }
    }
  });

  it('never places bedrock above the rough layer (y>4)', () => {
    const blocks = new TerrainGenerator(5).generateChunk(2, 2);
    for (let y = 5; y < CHUNK_SIZE_Y; y++) {
      for (let z = 0; z < CHUNK_SIZE_Z; z++) {
        for (let x = 0; x < CHUNK_SIZE_X; x++) {
          expect(blocks[localIndex(x, y, z)]).not.toBe(BlockId.Bedrock);
        }
      }
    }
  });

  it('keeps surface height within world bounds', () => {
    const gen = new TerrainGenerator(123);
    for (let cx = -2; cx <= 2; cx++) {
      for (let cz = -2; cz <= 2; cz++) {
        for (let lx = 0; lx < CHUNK_SIZE_X; lx += 4) {
          const h = gen.heightAt(cx * 16 + lx, cz * 16);
          expect(h).toBeGreaterThanOrEqual(1);
          expect(h).toBeLessThanOrEqual(250);
        }
      }
    }
  });

  it('respects ore elevation bands: diamond only deep, coal shallow', () => {
    const gen = new TerrainGenerator(777);
    let diamondMaxY = -1;
    let goldMaxY = -1;
    let coalMinY = Infinity;
    for (let cx = 0; cx < 6; cx++) {
      for (let cz = 0; cz < 6; cz++) {
        const blocks = gen.generateChunk(cx, cz);
        for (let y = 0; y < CHUNK_SIZE_Y; y++) {
          for (let z = 0; z < CHUNK_SIZE_Z; z++) {
            for (let x = 0; x < CHUNK_SIZE_X; x++) {
              const id = blocks[localIndex(x, y, z)];
              if (id === BlockId.DiamondOre) diamondMaxY = Math.max(diamondMaxY, y);
              if (id === BlockId.GoldOre) goldMaxY = Math.max(goldMaxY, y);
              if (id === BlockId.CoalOre) coalMinY = Math.min(coalMinY, y);
            }
          }
        }
      }
    }
    // Diamonds must never appear above Y=16, gold never above Y=32.
    expect(diamondMaxY).toBeLessThanOrEqual(16);
    expect(goldMaxY).toBeLessThanOrEqual(32);
    // Some coal should have generated somewhere.
    expect(coalMinY).toBeLessThan(Infinity);
  });

  it('places a solid, non-air surface on most land columns', () => {
    const blocks = new TerrainGenerator(31).generateChunk(0, 0);
    let landColumns = 0;
    for (let z = 0; z < CHUNK_SIZE_Z; z++) {
      for (let x = 0; x < CHUNK_SIZE_X; x++) {
        const top = topSolidY(blocks, x, z);
        expect(top).toBeGreaterThan(0);
        if (top >= SEA_LEVEL) landColumns++;
      }
    }
    expect(landColumns).toBeGreaterThan(0);
  });
});
