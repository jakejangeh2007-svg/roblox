import { describe, it, expect } from 'vitest';
import {
  getItem,
  maybeItem,
  breakTimeSeconds,
  canHarvest,
  placeableBlock,
  ItemId,
} from './Item';
import { getBlock, BlockId } from '../world/Block';

describe('item registry', () => {
  it('derives block items with same id and placeBlock', () => {
    const stone = getItem(BlockId.Stone);
    expect(stone.placeBlock).toBe(BlockId.Stone);
    expect(stone.maxStack).toBe(64);
  });

  it('registers tools with tier speed and durability', () => {
    const dPick = getItem(ItemId.DiamondPickaxe);
    expect(dPick.tool).toBeDefined();
    expect(dPick.tool!.speed).toBe(8);
    expect(dPick.maxStack).toBe(1);
    expect(dPick.tool!.maxDurability).toBeGreaterThan(1000);
  });

  it('returns undefined for unknown ids via maybeItem', () => {
    expect(maybeItem(9999)).toBeUndefined();
  });
});

describe('breakTimeSeconds', () => {
  it('is faster with a better pickaxe on stone', () => {
    const stone = getBlock(BlockId.Stone);
    const byHand = breakTimeSeconds(stone, undefined);
    const wood = breakTimeSeconds(stone, getItem(ItemId.WoodPickaxe));
    const diamond = breakTimeSeconds(stone, getItem(ItemId.DiamondPickaxe));
    expect(wood).toBeLessThan(byHand);
    expect(diamond).toBeLessThan(wood);
  });

  it('penalizes wrong-tool / no-tool on tool-required blocks', () => {
    const stone = getBlock(BlockId.Stone);
    // Hand cannot harvest stone → uses the 5x base multiplier.
    const byHand = breakTimeSeconds(stone, undefined);
    const withAxe = breakTimeSeconds(stone, getItem(ItemId.WoodAxe));
    // Axe is wrong class → same slow base as hand (no speed bonus).
    expect(byHand).toBeCloseTo(withAxe, 5);
  });

  it('treats bedrock and water as unbreakable', () => {
    expect(breakTimeSeconds(getBlock(BlockId.Bedrock), undefined)).toBe(Infinity);
    expect(breakTimeSeconds(getBlock(BlockId.Water), undefined)).toBe(Infinity);
  });

  it('breaks instant-mine blocks (flowers) in zero time', () => {
    expect(breakTimeSeconds(getBlock(BlockId.Flower), undefined)).toBe(0);
  });
});

describe('canHarvest', () => {
  it('lets any tool harvest non-tool-required blocks', () => {
    expect(canHarvest(getBlock(BlockId.Dirt), undefined)).toBe(true);
  });
  it('requires a pickaxe to harvest stone', () => {
    expect(canHarvest(getBlock(BlockId.Stone), undefined)).toBe(false);
    expect(canHarvest(getBlock(BlockId.Stone), getItem(ItemId.WoodPickaxe))).toBe(true);
  });
  it('requires iron+ pickaxe for diamond ore', () => {
    const diamond = getBlock(BlockId.DiamondOre);
    expect(canHarvest(diamond, getItem(ItemId.StonePickaxe))).toBe(false);
    expect(canHarvest(diamond, getItem(ItemId.IronPickaxe))).toBe(true);
    expect(canHarvest(diamond, getItem(ItemId.DiamondPickaxe))).toBe(true);
  });
});

describe('placeableBlock', () => {
  it('maps block items to their block, tools to null', () => {
    expect(placeableBlock(BlockId.Cobblestone)).toBe(BlockId.Cobblestone);
    expect(placeableBlock(ItemId.DiamondPickaxe)).toBeNull();
  });
});
