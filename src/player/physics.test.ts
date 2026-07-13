import { describe, it, expect } from 'vitest';
import { moveAABB, isPositionColliding, fallDamage, type SolidFn } from './physics';
import { SAFE_FALL_BLOCKS } from '../config/constants';

const HALF = 0.3;
const HEIGHT = 1.8;

/** Solid floor at y=0..? given a set of solid columns/cells. */
function floorAt(floorY: number): SolidFn {
  return (_x, y) => y <= floorY;
}

describe('moveAABB — gravity/floor', () => {
  it('lands on a floor and reports onGround', () => {
    // Floor occupies y=0 (block spanning 0..1). Player feet start at y=3.
    const isSolid: SolidFn = (_x, y) => y === 0;
    const r = moveAABB(0.5, 3, 0.5, HALF, HEIGHT, 0, -5, 0, isSolid);
    // Feet should rest on top of the y=0 block → y ≈ 1.
    expect(r.onGround).toBe(true);
    expect(r.y).toBeGreaterThanOrEqual(1);
    expect(r.y).toBeLessThan(1.02);
  });

  it('does not tunnel through a thin floor with a large single delta', () => {
    const isSolid: SolidFn = (_x, y) => y === 0;
    // Feet just above the block top; a >1-block downward delta would tunnel
    // through the 0..1 block without sub-stepping. It must still land at y≈1.
    const r = moveAABB(0.5, 1.2, 0.5, HALF, HEIGHT, 0, -1.5, 0, isSolid);
    expect(r.onGround).toBe(true);
    expect(r.y).toBeGreaterThanOrEqual(1);
    expect(r.y).toBeLessThan(1.02);
  });

  it('falls freely when there is no floor', () => {
    const isSolid: SolidFn = () => false;
    const r = moveAABB(0.5, 5, 0.5, HALF, HEIGHT, 0, -2, 0, isSolid);
    expect(r.onGround).toBe(false);
    expect(r.y).toBeCloseTo(3, 5);
  });
});

describe('moveAABB — walls', () => {
  it('stops horizontal movement at a wall and reports hitWall', () => {
    // Wall at x=2 (block spanning 2..3), player at x=1 moving +x.
    const isSolid: SolidFn = (x) => x === 2;
    const r = moveAABB(1.5, 5, 0.5, HALF, HEIGHT, 2, 0, 0, isSolid);
    expect(r.hitWall).toBe(true);
    // Right edge should stop just before x=2.
    expect(r.x + HALF).toBeLessThanOrEqual(2 + 1e-3);
  });

  it('slides along a wall (blocked axis stops, free axis moves)', () => {
    const isSolid: SolidFn = (x) => x === 2;
    const r = moveAABB(1.5, 5, 0.5, HALF, HEIGHT, 2, 0, 1, isSolid);
    expect(r.x + HALF).toBeLessThanOrEqual(2 + 1e-3);
    expect(r.z).toBeCloseTo(1.5, 3); // z movement unaffected
  });

  it('stops upward movement at a ceiling', () => {
    // Ceiling block at y=4 (spans 4..5). Player feet at y=1, height 1.8 → head 2.8.
    const isSolid: SolidFn = (_x, y) => y === 4;
    const r = moveAABB(0.5, 1, 0.5, HALF, HEIGHT, 0, 3, 0, isSolid);
    expect(r.hitCeiling).toBe(true);
    expect(r.y + HEIGHT).toBeLessThanOrEqual(4 + 1e-3);
  });
});

describe('isPositionColliding', () => {
  it('detects overlap with a solid block', () => {
    const isSolid: SolidFn = (x, y, z) => x === 0 && y === 5 && z === 0;
    expect(isPositionColliding(0.5, 5, 0.5, HALF, HEIGHT, isSolid)).toBe(true);
  });
  it('reports clear when no overlap', () => {
    expect(isPositionColliding(0.5, 5, 0.5, HALF, HEIGHT, floorAt(0))).toBe(false);
  });
});

describe('fallDamage', () => {
  it('is zero within the safe distance', () => {
    expect(fallDamage(0, SAFE_FALL_BLOCKS)).toBe(0);
    expect(fallDamage(3, SAFE_FALL_BLOCKS)).toBe(0);
  });
  it('scales at 1 half-heart per block beyond safe distance', () => {
    expect(fallDamage(4, SAFE_FALL_BLOCKS)).toBe(1);
    expect(fallDamage(10, SAFE_FALL_BLOCKS)).toBe(7);
    expect(fallDamage(23, SAFE_FALL_BLOCKS)).toBe(20); // lethal from ~23 blocks
  });
});
