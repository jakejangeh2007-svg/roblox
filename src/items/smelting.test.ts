import { describe, it, expect } from 'vitest';
import { smeltResult, fuelBurnSeconds, isFuel, isSmeltable, COOK_TIME } from './smelting';
import { BlockId } from '../world/Block';
import { ItemId } from './Item';

describe('smelting recipes', () => {
  it('smelts ores and blocks to their products', () => {
    expect(smeltResult(ItemId.RawIron)).toBe(ItemId.IronIngot);
    expect(smeltResult(ItemId.RawGold)).toBe(ItemId.GoldIngot);
    expect(smeltResult(BlockId.Sand)).toBe(BlockId.Glass);
    expect(smeltResult(BlockId.Cobblestone)).toBe(BlockId.Stone);
    expect(smeltResult(BlockId.OakLog)).toBe(ItemId.Charcoal);
  });

  it('returns null for non-smeltable items', () => {
    expect(smeltResult(BlockId.Dirt)).toBeNull();
    expect(smeltResult(ItemId.Diamond)).toBeNull();
  });

  it('recognizes fuels and their burn durations', () => {
    expect(isFuel(ItemId.Coal)).toBe(true);
    expect(fuelBurnSeconds(ItemId.Coal)).toBeGreaterThan(COOK_TIME);
    expect(fuelBurnSeconds(ItemId.Stick)).toBeGreaterThan(0);
    expect(isFuel(BlockId.Dirt)).toBe(false);
    expect(fuelBurnSeconds(BlockId.Dirt)).toBe(0);
  });

  it('classifies smeltable inputs', () => {
    expect(isSmeltable(BlockId.Sand)).toBe(true);
    expect(isSmeltable(BlockId.Dirt)).toBe(false);
  });
});
