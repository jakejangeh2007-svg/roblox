import { describe, it, expect } from 'vitest';
import { Inventory } from './Inventory';
import { BlockId } from '../world/Block';
import { ItemId } from '../items/Item';

describe('Inventory.add', () => {
  it('fills the hotbar first, then stacks', () => {
    const inv = new Inventory();
    expect(inv.add(BlockId.Dirt, 10)).toBe(0);
    expect(inv.slots[0]).toEqual({ item: BlockId.Dirt, count: 10 });
    // Adding more stacks into the same slot up to maxStack (64).
    inv.add(BlockId.Dirt, 54);
    expect(inv.slots[0]!.count).toBe(64);
  });

  it('overflows into new slots past a full stack', () => {
    const inv = new Inventory();
    inv.add(BlockId.Cobblestone, 70);
    expect(inv.slots[0]!.count).toBe(64);
    expect(inv.slots[1]!.count).toBe(6);
  });

  it('returns leftover when the inventory is full', () => {
    const inv = new Inventory();
    for (let i = 0; i < 36; i++) inv.slots[i] = { item: BlockId.Stone, count: 64 };
    const leftover = inv.add(BlockId.Dirt, 5);
    expect(leftover).toBe(5);
  });

  it('does not stack non-stackable tools', () => {
    const inv = new Inventory();
    inv.add(ItemId.WoodPickaxe, 1);
    inv.add(ItemId.WoodPickaxe, 1);
    expect(inv.slots[0]!.count).toBe(1);
    expect(inv.slots[1]!.count).toBe(1);
  });
});

describe('Inventory.remove / consume', () => {
  it('removes across multiple stacks', () => {
    const inv = new Inventory();
    inv.add(BlockId.Dirt, 100); // 64 + 36
    expect(inv.remove(BlockId.Dirt, 70)).toBe(70);
    expect(inv.count(BlockId.Dirt)).toBe(30);
  });

  it('consumes the selected slot and clears it at zero', () => {
    const inv = new Inventory();
    inv.slots[2] = { item: BlockId.Torch, count: 1 };
    inv.setSelectedSlot(2);
    inv.consumeSelected(1);
    expect(inv.slots[2]).toBeNull();
  });
});

describe('Inventory selection', () => {
  it('wraps hotbar selection', () => {
    const inv = new Inventory();
    inv.setSelectedSlot(9);
    expect(inv.selectedSlot).toBe(0);
    inv.setSelectedSlot(-1);
    expect(inv.selectedSlot).toBe(8);
  });
});

describe('Inventory serialize/load', () => {
  it('round-trips including durability and nulls', () => {
    const inv = new Inventory();
    inv.slots[0] = { item: ItemId.IronPickaxe, count: 1, durability: 120 };
    inv.slots[5] = { item: BlockId.Sand, count: 12 };
    const data = inv.serialize();
    const inv2 = new Inventory();
    inv2.load(data);
    expect(inv2.slots[0]).toEqual({ item: ItemId.IronPickaxe, count: 1, durability: 120 });
    expect(inv2.slots[5]).toEqual({ item: BlockId.Sand, count: 12 });
    expect(inv2.slots[1]).toBeNull();
  });
});
