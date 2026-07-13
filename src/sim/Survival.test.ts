import { describe, it, expect } from 'vitest';
import { Survival } from './Survival';
import { Player } from '../player/Player';

function makePlayer(): Player {
  return new Player({ x: 0, y: 64, z: 0 });
}

describe('Survival', () => {
  it('drains hunger over time with exertion', () => {
    const p = makePlayer();
    const s = new Survival();
    // Simulate sprinting for a good while.
    for (let i = 0; i < 60 * 60; i++) {
      s.update(1 / 60, p, { sprinting: true, jumped: false, blocksMined: 0 });
    }
    expect(p.hunger).toBeLessThan(20);
  });

  it('regenerates health when hunger is high', () => {
    const p = makePlayer();
    p.health = 10;
    p.hunger = 20;
    const s = new Survival();
    for (let i = 0; i < 60 * 5; i++) {
      s.update(1 / 60, p, { sprinting: false, jumped: false, blocksMined: 0 });
    }
    expect(p.health).toBeGreaterThan(10);
  });

  it('does not regenerate when hunger is low', () => {
    const p = makePlayer();
    p.health = 10;
    p.hunger = 6;
    const s = new Survival();
    for (let i = 0; i < 60 * 5; i++) {
      s.update(1 / 60, p, { sprinting: false, jumped: false, blocksMined: 0 });
    }
    expect(p.health).toBe(10);
  });

  it('starves health when hunger is empty', () => {
    const p = makePlayer();
    p.health = 20;
    p.hunger = 0;
    const s = new Survival();
    for (let i = 0; i < 60 * 10; i++) {
      s.update(1 / 60, p, { sprinting: false, jumped: false, blocksMined: 0 });
    }
    expect(p.health).toBeLessThan(20);
    expect(p.health).toBeGreaterThanOrEqual(0);
  });

  it('restores hunger when eating, capped at max', () => {
    const p = makePlayer();
    p.hunger = 10;
    const s = new Survival();
    s.eat(p, 8);
    expect(p.hunger).toBe(18);
    s.eat(p, 8);
    expect(p.hunger).toBe(20); // capped
  });
});
