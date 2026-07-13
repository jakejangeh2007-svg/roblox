import { describe, it, expect } from 'vitest';
import { tickFurnace, furnaceCanSmelt } from './furnaceLogic';
import { newFurnace } from './TileEntities';
import { COOK_TIME } from '../../items/smelting';
import { BlockId } from '../../world/Block';
import { ItemId } from '../../items/Item';

describe('furnace smelting', () => {
  it('does not smelt without fuel', () => {
    const f = newFurnace();
    f.input = { item: ItemId.RawIron, count: 1 };
    tickFurnace(f, 5);
    expect(f.output).toBeNull();
    expect(f.cookTime).toBe(0);
  });

  it('consumes fuel and smelts an item after the cook time', () => {
    const f = newFurnace();
    f.input = { item: ItemId.RawIron, count: 2 };
    f.fuel = { item: ItemId.Coal, count: 1 };
    // First tick lights the fuel.
    tickFurnace(f, 0.1);
    expect(f.burnTime).toBeGreaterThan(0);
    expect(f.fuel).toBeNull(); // one coal consumed
    // Advance to complete one smelt.
    tickFurnace(f, COOK_TIME);
    expect(f.output).toEqual({ item: ItemId.IronIngot, count: 1 });
    expect(f.input.count).toBe(1);
  });

  it('stacks multiple smelts into the output', () => {
    const f = newFurnace();
    f.input = { item: BlockId.Sand, count: 3 };
    f.fuel = { item: ItemId.Coal, count: 1 };
    tickFurnace(f, 0.1);
    tickFurnace(f, COOK_TIME);
    tickFurnace(f, COOK_TIME);
    expect(f.output).toEqual({ item: BlockId.Glass, count: 2 });
    expect(f.input.count).toBe(1);
  });

  it('stops smelting when output type differs', () => {
    const f = newFurnace();
    f.input = { item: BlockId.Sand, count: 1 };
    f.output = { item: ItemId.IronIngot, count: 1 }; // wrong product blocks it
    expect(furnaceCanSmelt(f)).toBe(false);
  });

  it('does not burn fuel when there is nothing to smelt', () => {
    const f = newFurnace();
    f.fuel = { item: ItemId.Coal, count: 1 };
    tickFurnace(f, 1);
    expect(f.burnTime).toBe(0);
    expect(f.fuel).toEqual({ item: ItemId.Coal, count: 1 });
  });
});
