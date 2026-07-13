import { describe, it, expect } from 'vitest';
import { CraftingGrid } from './Crafting';
import { BlockId } from '../world/Block';
import { ItemId } from '../items/Item';

describe('CraftingGrid', () => {
  it('derives output from contents (2x2 planks → crafting table)', () => {
    const g = new CraftingGrid(2);
    g.slots[0] = { item: BlockId.Planks, count: 3 };
    g.slots[1] = { item: BlockId.Planks, count: 3 };
    g.slots[2] = { item: BlockId.Planks, count: 3 };
    g.slots[3] = { item: BlockId.Planks, count: 3 };
    expect(g.getOutput()).toEqual({ item: BlockId.CraftingTable, count: 1 });
  });

  it('consumes one from each input slot per craft', () => {
    const g = new CraftingGrid(2);
    g.slots[0] = { item: BlockId.Planks, count: 2 };
    g.slots[1] = { item: BlockId.Planks, count: 2 };
    g.slots[2] = { item: BlockId.Planks, count: 2 };
    g.slots[3] = { item: BlockId.Planks, count: 2 };
    g.consumeInputs();
    expect(g.slots.every((s) => s!.count === 1)).toBe(true);
    g.consumeInputs();
    expect(g.slots.every((s) => s === null)).toBe(true);
    expect(g.getOutput()).toBeNull();
  });

  it('crafts a pickaxe in a 3x3 grid', () => {
    const g = new CraftingGrid(3);
    const P = BlockId.Planks;
    const S = ItemId.Stick;
    [P, P, P, null, S, null, null, S, null].forEach((id, i) => {
      g.slots[i] = id == null ? null : { item: id, count: 1 };
    });
    expect(g.getOutput()).toEqual({ item: ItemId.WoodPickaxe, count: 1 });
  });

  it('clear() empties and returns prior contents', () => {
    const g = new CraftingGrid(2);
    g.slots[0] = { item: BlockId.Dirt, count: 5 };
    const contents = g.clear();
    expect(contents[0]).toEqual({ item: BlockId.Dirt, count: 5 });
    expect(g.isEmpty()).toBe(true);
  });
});
