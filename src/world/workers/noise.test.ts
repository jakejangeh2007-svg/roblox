import { describe, it, expect } from 'vitest';
import { SimplexNoise } from './noise';

describe('SimplexNoise', () => {
  it('is deterministic for a given seed', () => {
    const a = new SimplexNoise(1234);
    const b = new SimplexNoise(1234);
    for (let i = 0; i < 50; i++) {
      const x = i * 0.37;
      const y = i * 0.91;
      expect(a.noise2D(x, y)).toBe(b.noise2D(x, y));
      expect(a.noise3D(x, y, i * 0.5)).toBe(b.noise3D(x, y, i * 0.5));
    }
  });

  it('produces different fields for different seeds', () => {
    const a = new SimplexNoise(1);
    const b = new SimplexNoise(2);
    let diff = 0;
    for (let i = 0; i < 50; i++) {
      if (Math.abs(a.noise2D(i * 0.3, i * 0.7) - b.noise2D(i * 0.3, i * 0.7)) > 1e-6) diff++;
    }
    expect(diff).toBeGreaterThan(40);
  });

  it('stays within roughly [-1, 1]', () => {
    const n = new SimplexNoise(99);
    let min = Infinity;
    let max = -Infinity;
    for (let x = 0; x < 40; x++) {
      for (let y = 0; y < 40; y++) {
        const v = n.noise2D(x * 0.13, y * 0.13);
        min = Math.min(min, v);
        max = Math.max(max, v);
      }
    }
    expect(min).toBeGreaterThanOrEqual(-1.001);
    expect(max).toBeLessThanOrEqual(1.001);
  });

  it('fbm averages octaves into [-1, 1]', () => {
    const n = new SimplexNoise(7);
    for (let i = 0; i < 30; i++) {
      const v = n.fbm2D(i * 0.2, i * 0.3, 4);
      expect(v).toBeGreaterThanOrEqual(-1.001);
      expect(v).toBeLessThanOrEqual(1.001);
    }
  });
});
