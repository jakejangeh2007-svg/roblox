import { describe, it, expect } from 'vitest';
import { BreakController } from './mining';

describe('BreakController', () => {
  it('accumulates progress and completes after the break time', () => {
    const b = new BreakController();
    let s = b.update('1,1,1', 1.0, 0.5, true);
    expect(s.completed).toBe(false);
    expect(s.progress).toBeCloseTo(0.5, 5);
    s = b.update('1,1,1', 1.0, 0.5, true);
    expect(s.completed).toBe(true);
    expect(s.progress).toBe(1);
  });

  it('reports increasing crack stages 0..9', () => {
    const b = new BreakController();
    const s1 = b.update('1,1,1', 1.0, 0.05, true);
    const s2 = b.update('1,1,1', 1.0, 0.5, true);
    expect(s1.stage).toBeLessThan(s2.stage);
    expect(s2.stage).toBeLessThanOrEqual(9);
  });

  it('resets progress when the target changes', () => {
    const b = new BreakController();
    b.update('1,1,1', 1.0, 0.8, true);
    const s = b.update('2,2,2', 1.0, 0.1, true);
    expect(s.progress).toBeCloseTo(0.1, 5);
  });

  it('resets when mining stops', () => {
    const b = new BreakController();
    b.update('1,1,1', 1.0, 0.8, true);
    const s = b.update('1,1,1', 1.0, 0.1, false);
    expect(s.stage).toBe(-1);
    expect(b.activeKey).toBeNull();
  });

  it('completes instantly for zero break time (flowers)', () => {
    const b = new BreakController();
    const s = b.update('1,1,1', 0, 0.016, true);
    expect(s.completed).toBe(true);
  });

  it('never progresses on an unbreakable (infinite) target', () => {
    const b = new BreakController();
    const s = b.update('1,1,1', Infinity, 1, true);
    expect(s.completed).toBe(false);
    expect(s.stage).toBe(-1);
  });
});
