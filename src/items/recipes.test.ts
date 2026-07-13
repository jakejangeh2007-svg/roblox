import { describe, it, expect } from 'vitest';
import { matchRecipe } from './recipes';
import { BlockId } from '../world/Block';
import { ItemId } from './Item';

/** Build a width×width grid from a compact spec (null = empty). */
function grid(width: number, cells: (number | null)[]): (number | null)[] {
  const g = new Array<number | null>(width * width).fill(null);
  for (let i = 0; i < cells.length; i++) g[i] = cells[i] ?? null;
  return g;
}

describe('shapeless recipes', () => {
  it('turns one log into four planks in any slot', () => {
    expect(matchRecipe(grid(2, [BlockId.OakLog]), 2)).toEqual({ item: BlockId.Planks, count: 4 });
    // Same log placed in a different slot still matches (shapeless).
    expect(matchRecipe(grid(2, [null, null, null, BlockId.OakLog]), 2)).toEqual({
      item: BlockId.Planks,
      count: 4,
    });
  });

  it('does not craft planks from two logs', () => {
    expect(matchRecipe(grid(2, [BlockId.OakLog, BlockId.OakLog]), 2)).toBeNull();
  });
});

describe('shaped recipes in 2x2', () => {
  it('crafts sticks from two vertical planks (position-independent by trim)', () => {
    // Planks stacked vertically anywhere in the 2x2 grid.
    expect(matchRecipe(grid(2, [BlockId.Planks, null, BlockId.Planks, null]), 2)).toEqual({
      item: ItemId.Stick,
      count: 4,
    });
    expect(matchRecipe(grid(2, [null, BlockId.Planks, null, BlockId.Planks]), 2)).toEqual({
      item: ItemId.Stick,
      count: 4,
    });
  });

  it('crafts a crafting table from four planks', () => {
    expect(matchRecipe(grid(2, [BlockId.Planks, BlockId.Planks, BlockId.Planks, BlockId.Planks]), 2)).toEqual({
      item: BlockId.CraftingTable,
      count: 1,
    });
  });
});

describe('shaped recipes needing 3x3', () => {
  it('does not craft a furnace in a 2x2 grid', () => {
    // 8 cobblestone won't even fit; ensure no false match.
    expect(matchRecipe(grid(2, [BlockId.Cobblestone, BlockId.Cobblestone, BlockId.Cobblestone, BlockId.Cobblestone]), 2)).toBeNull();
  });

  it('crafts a furnace from a cobblestone ring in 3x3', () => {
    const C = BlockId.Cobblestone;
    expect(matchRecipe(grid(3, [C, C, C, C, null, C, C, C, C]), 3)).toEqual({
      item: BlockId.Furnace,
      count: 1,
    });
  });

  it('crafts a wooden pickaxe (planks row + stick handle)', () => {
    const P = BlockId.Planks;
    const S = ItemId.Stick;
    expect(matchRecipe(grid(3, [P, P, P, null, S, null, null, S, null]), 3)).toEqual({
      item: ItemId.WoodPickaxe,
      count: 1,
    });
  });

  it('crafts a diamond sword (two diamonds over a stick)', () => {
    const D = ItemId.Diamond;
    const S = ItemId.Stick;
    expect(matchRecipe(grid(3, [D, null, null, D, null, null, S, null, null]), 3)).toEqual({
      item: ItemId.DiamondSword,
      count: 1,
    });
  });

  it('crafts torches from coal over a stick', () => {
    expect(matchRecipe(grid(3, [ItemId.Coal, null, null, ItemId.Stick, null, null, null, null, null]), 3)).toEqual({
      item: BlockId.Torch,
      count: 4,
    });
  });

  it('returns null for an unknown arrangement', () => {
    expect(matchRecipe(grid(3, [BlockId.Dirt, BlockId.Sand, null, null, null, null, null, null, null]), 3)).toBeNull();
  });
});
