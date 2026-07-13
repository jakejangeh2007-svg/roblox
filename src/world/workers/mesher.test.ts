import { describe, it, expect } from 'vitest';
import { meshChunk, type NeighborGrid } from './mesher';
import { BLOCKS_PER_CHUNK } from '../../config/constants';
import { localIndex } from '../../core/math';
import { BlockId } from '../Block';

function emptyGrid(): NeighborGrid {
  const center = new Uint8Array(BLOCKS_PER_CHUNK);
  const blocks: (Uint8Array | null)[] = new Array<Uint8Array | null>(9).fill(null);
  blocks[4] = center; // center slot
  return { blocks };
}

function setCenter(grid: NeighborGrid, x: number, y: number, z: number, id: number): void {
  grid.blocks[4]![localIndex(x, y, z)] = id;
}

describe('meshChunk', () => {
  it('emits nothing for an all-air chunk', () => {
    const { opaque, transparent } = meshChunk(emptyGrid());
    expect(opaque).toBeNull();
    expect(transparent).toBeNull();
  });

  it('emits 6 faces (24 verts, 36 indices) for a lone opaque block', () => {
    const grid = emptyGrid();
    setCenter(grid, 5, 5, 5, BlockId.Stone);
    const { opaque } = meshChunk(grid);
    expect(opaque).not.toBeNull();
    expect(opaque!.positions.length).toBe(24 * 3);
    expect(opaque!.indices.length).toBe(36);
    // Every position component is finite and within the block's cell.
    for (const p of opaque!.positions) expect(Number.isFinite(p)).toBe(true);
  });

  it('culls the shared face between two adjacent opaque blocks', () => {
    const grid = emptyGrid();
    setCenter(grid, 5, 5, 5, BlockId.Stone);
    setCenter(grid, 6, 5, 5, BlockId.Stone);
    const { opaque } = meshChunk(grid);
    // 2 cubes * 6 - 2 hidden faces = 10 faces = 40 verts, 60 indices.
    expect(opaque!.indices.length).toBe(10 * 6);
  });

  it('routes transparent blocks to the transparent buffer only', () => {
    const grid = emptyGrid();
    setCenter(grid, 5, 5, 5, BlockId.Water);
    const { opaque, transparent } = meshChunk(grid);
    expect(opaque).toBeNull();
    expect(transparent).not.toBeNull();
    expect(transparent!.indices.length).toBe(36);
  });

  it('culls a full interior so only the 6 chunk faces remain', () => {
    // Fill a small 3x3x3 solid block; the center block should contribute no faces.
    const grid = emptyGrid();
    for (let y = 4; y <= 6; y++)
      for (let z = 4; z <= 6; z++)
        for (let x = 4; x <= 6; x++) setCenter(grid, x, y, z, BlockId.Stone);
    const { opaque } = meshChunk(grid);
    // A 3x3x3 cube exposes 9 faces per side * 6 = 54 faces (center fully hidden).
    expect(opaque!.indices.length).toBe(54 * 6);
  });

  it('culls faces against neighbor-chunk blocks at the border', () => {
    const grid = emptyGrid();
    // Block at west edge x=0; put a solid block in the west neighbor's x=15.
    setCenter(grid, 0, 5, 5, BlockId.Stone);
    const west = new Uint8Array(BLOCKS_PER_CHUNK);
    west[localIndex(15, 5, 5)] = BlockId.Stone;
    grid.blocks[(1) * 3 + 0] = west; // dz=0, dx=-1
    const { opaque } = meshChunk(grid);
    // West face is now hidden → 5 faces.
    expect(opaque!.indices.length).toBe(5 * 6);
  });

  it('routes cross sprites (flowers/grass) to the transparent stream', () => {
    const grid = emptyGrid();
    setCenter(grid, 5, 5, 5, BlockId.Flower);
    const { opaque, transparent } = meshChunk(grid);
    // Cross sprites have transparent pixels → must be alpha-tested (transparent
    // stream), not opaque (which would render their backgrounds black).
    expect(opaque).toBeNull();
    expect(transparent).not.toBeNull();
    // Two crossed quads → 8 verts, 12 indices.
    expect(transparent!.indices.length).toBe(12);
  });

  it('produces per-vertex shade in [0,1]', () => {
    const grid = emptyGrid();
    setCenter(grid, 8, 8, 8, BlockId.Stone);
    const { opaque } = meshChunk(grid);
    for (const s of opaque!.shade) {
      expect(s).toBeGreaterThanOrEqual(0);
      expect(s).toBeLessThanOrEqual(1);
    }
  });
});
