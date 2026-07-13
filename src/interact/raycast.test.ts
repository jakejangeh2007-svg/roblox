import { describe, it, expect } from 'vitest';
import { raycastVoxel, type BlockGetter } from './raycast';

const AIR = 0;
const STONE = 1;

/** World with a single solid block at the given cell. */
function singleBlock(bx: number, by: number, bz: number): BlockGetter {
  return (x, y, z) => (x === bx && y === by && z === bz ? STONE : AIR);
}

const targetable = (id: number): boolean => id !== AIR;

describe('raycastVoxel', () => {
  it('hits a block straight ahead and reports the entry face', () => {
    const world = singleBlock(5, 0, 0);
    // Ray from x=0 going +x at y,z centered in the block row.
    const hit = raycastVoxel(0.5, 0.5, 0.5, 1, 0, 0, 10, world, targetable);
    expect(hit).not.toBeNull();
    expect(hit!.x).toBe(5);
    expect(hit!.y).toBe(0);
    expect(hit!.z).toBe(0);
    // Entered through the -x face → normal points back toward origin.
    expect([hit!.nx, hit!.ny, hit!.nz]).toEqual([-1, 0, 0]);
  });

  it('returns null when nothing is within reach', () => {
    const world = singleBlock(50, 0, 0);
    expect(raycastVoxel(0.5, 0.5, 0.5, 1, 0, 0, 5, world, targetable)).toBeNull();
  });

  it('reports the top face when looking down onto a block', () => {
    const world = singleBlock(0, 0, 0);
    const hit = raycastVoxel(0.5, 5, 0.5, 0, -1, 0, 10, world, targetable);
    expect(hit).not.toBeNull();
    expect([hit!.nx, hit!.ny, hit!.nz]).toEqual([0, 1, 0]);
  });

  it('traverses diagonally and finds the first solid cell', () => {
    // A wall along x=3 for all z; ray goes diagonally +x/+z.
    const world: BlockGetter = (x) => (x === 3 ? STONE : AIR);
    const hit = raycastVoxel(0.5, 0.5, 0.5, 0.8, 0, 0.6, 12, world, targetable);
    expect(hit).not.toBeNull();
    expect(hit!.x).toBe(3);
  });

  it('detects a block the ray origin is already inside', () => {
    const world = singleBlock(0, 0, 0);
    const hit = raycastVoxel(0.5, 0.5, 0.5, 1, 0, 0, 5, world, targetable);
    expect(hit).not.toBeNull();
    expect(hit!.distance).toBe(0);
  });

  it('places against the correct adjacent cell (hit + normal)', () => {
    const world = singleBlock(5, 0, 0);
    const hit = raycastVoxel(0.5, 0.5, 0.5, 1, 0, 0, 10, world, targetable)!;
    const placeX = hit.x + hit.nx;
    expect(placeX).toBe(4); // one cell before the block, on the ray side
  });
});
