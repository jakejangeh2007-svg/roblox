/**
 * Player inventory: 36 storage slots (0..8 are the hotbar) plus 4 armor slots
 * and 1 off-hand slot. Step 5 builds the full drag/drop UI and crafting on top;
 * this class owns the data model and stacking rules.
 */
import { getItem, type ItemDef } from '../items/Item';

export interface ItemStack {
  item: number;
  count: number;
  /** Remaining durability for tools; undefined for stackables. */
  durability?: number;
}

export const HOTBAR_SIZE = 9;
export const MAIN_SIZE = 36; // includes the 9 hotbar slots at 0..8
export const ARMOR_SIZE = 4;

export function cloneStack(s: ItemStack): ItemStack {
  return s.durability === undefined
    ? { item: s.item, count: s.count }
    : { item: s.item, count: s.count, durability: s.durability };
}

export class Inventory {
  /** Main slots 0..35 (0..8 = hotbar). */
  readonly slots: (ItemStack | null)[] = new Array<ItemStack | null>(MAIN_SIZE).fill(null);
  /** Armor: [helmet, chestplate, leggings, boots]. */
  readonly armor: (ItemStack | null)[] = new Array<ItemStack | null>(ARMOR_SIZE).fill(null);
  offhand: ItemStack | null = null;

  selectedSlot = 0;

  getSelected(): ItemStack | null {
    return this.slots[this.selectedSlot] ?? null;
  }

  getSelectedDef(): ItemDef | undefined {
    const s = this.getSelected();
    return s ? getItem(s.item) : undefined;
  }

  setSelectedSlot(i: number): void {
    this.selectedSlot = ((i % HOTBAR_SIZE) + HOTBAR_SIZE) % HOTBAR_SIZE;
  }

  /**
   * Add items, stacking into existing stacks first (hotbar preferred so picked-
   * up drops appear on the bar), then empty slots. Returns leftover count that
   * did not fit.
   */
  add(item: number, count: number): number {
    const max = getItem(item).maxStack;
    // 1) top up existing stacks.
    if (max > 1) {
      for (let i = 0; i < MAIN_SIZE && count > 0; i++) {
        const s = this.slots[i];
        if (s && s.item === item && s.count < max) {
          const room = max - s.count;
          const move = Math.min(room, count);
          s.count += move;
          count -= move;
        }
      }
    }
    // 2) fill empty slots (hotbar first, then main).
    const order = [...range(0, HOTBAR_SIZE), ...range(HOTBAR_SIZE, MAIN_SIZE)];
    for (const i of order) {
      if (count <= 0) break;
      if (this.slots[i] == null) {
        const move = Math.min(max, count);
        this.slots[i] = { item, count: move };
        count -= move;
      }
    }
    return count;
  }

  /** Remove up to `count` of `item` across all slots; returns amount removed. */
  remove(item: number, count: number): number {
    let removed = 0;
    for (let i = 0; i < MAIN_SIZE && removed < count; i++) {
      const s = this.slots[i];
      if (s && s.item === item) {
        const take = Math.min(s.count, count - removed);
        s.count -= take;
        removed += take;
        if (s.count <= 0) this.slots[i] = null;
      }
    }
    return removed;
  }

  /** Consume one of the currently-selected stack (used when placing a block). */
  consumeSelected(n = 1): void {
    const s = this.slots[this.selectedSlot];
    if (!s) return;
    s.count -= n;
    if (s.count <= 0) this.slots[this.selectedSlot] = null;
  }

  count(item: number): number {
    let n = 0;
    for (const s of this.slots) if (s && s.item === item) n += s.count;
    return n;
  }

  serialize(): (ItemStack | null)[] {
    return this.slots.map((s) => (s ? cloneStack(s) : null));
  }

  load(data: (ItemStack | null)[] | undefined): void {
    if (!data) return;
    for (let i = 0; i < MAIN_SIZE; i++) {
      this.slots[i] = data[i] ? cloneStack(data[i]!) : null;
    }
  }
}

function range(a: number, b: number): number[] {
  const out: number[] = [];
  for (let i = a; i < b; i++) out.push(i);
  return out;
}
