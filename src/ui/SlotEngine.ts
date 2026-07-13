/**
 * Reusable cursor-based slot interaction (tap-to-move) shared by container
 * screens (chest, furnace). Binds each DOM slot to a SlotRef and manages a
 * floating cursor stack. Supports take-only output slots and per-slot accept
 * filters (e.g. a furnace fuel slot).
 */
import { getItem, type ItemDef } from '../items/Item';
import { tileIconStyle } from '../world/atlas';
import type { ItemStack } from '../player/Inventory';

export interface SlotRef {
  get(): ItemStack | null;
  set(s: ItemStack | null): void;
  /** Output slots: the player may take from but not place into them. */
  takeOnly?: boolean;
  /** Called after taking `amount` from a take-only slot. */
  onTake?: (amount: number) => void;
  /** Restrict which items may be placed here. */
  accepts?: (item: number) => boolean;
}

const ICON_PX = 40;

export class SlotEngine {
  cursor: ItemStack | null = null;
  secondary = false;
  private readonly entries: { el: HTMLDivElement; ref: SlotRef }[] = [];

  constructor(
    private readonly cursorEl: HTMLDivElement,
    private readonly onChange: () => void,
  ) {}

  makeSlot(ref: SlotRef): HTMLDivElement {
    const el = document.createElement('div');
    el.className = 'inv-slot';
    const icon = document.createElement('div');
    icon.className = 'slot-icon';
    const count = document.createElement('span');
    count.className = 'slot-count';
    el.append(icon, count);
    el.addEventListener('pointerdown', (e) => {
      e.preventDefault();
      e.stopPropagation();
      this.positionCursor(e.clientX, e.clientY);
      this.click(ref, this.secondary || e.button === 2);
    });
    el.addEventListener('contextmenu', (e) => e.preventDefault());
    this.entries.push({ el, ref });
    return el;
  }

  private click(ref: SlotRef, secondary: boolean): void {
    if (ref.takeOnly) {
      this.takeFrom(ref);
    } else if (this.cursor) {
      this.place(ref, secondary);
    } else {
      this.pickUp(ref, secondary);
    }
    this.onChange();
    this.render();
  }

  private pickUp(ref: SlotRef, secondary: boolean): void {
    const stack = ref.get();
    if (!stack) return;
    if (secondary && stack.count > 1) {
      const take = Math.ceil(stack.count / 2);
      this.cursor = { item: stack.item, count: take };
      stack.count -= take;
      ref.set(stack.count > 0 ? stack : null);
    } else {
      this.cursor = stack;
      ref.set(null);
    }
  }

  private place(ref: SlotRef, secondary: boolean): void {
    const cur = this.cursor!;
    if (ref.accepts && !ref.accepts(cur.item)) return;
    const stack = ref.get();
    const max = getItem(cur.item).maxStack;
    if (!stack) {
      if (secondary) {
        ref.set({ item: cur.item, count: 1 });
        cur.count -= 1;
        if (cur.count <= 0) this.cursor = null;
      } else {
        ref.set(cur);
        this.cursor = null;
      }
    } else if (stack.item === cur.item) {
      const room = max - stack.count;
      if (room <= 0) return;
      const move = secondary ? Math.min(1, room) : Math.min(cur.count, room);
      stack.count += move;
      cur.count -= move;
      ref.set(stack);
      if (cur.count <= 0) this.cursor = null;
    } else {
      ref.set(cur);
      this.cursor = stack;
    }
  }

  private takeFrom(ref: SlotRef): void {
    const out = ref.get();
    if (!out) return;
    const max = getItem(out.item).maxStack;
    if (!this.cursor) {
      this.cursor = { item: out.item, count: out.count };
      ref.onTake?.(out.count);
    } else if (this.cursor.item === out.item && this.cursor.count + out.count <= max) {
      this.cursor.count += out.count;
      ref.onTake?.(out.count);
    }
  }

  positionCursor(x: number, y: number): void {
    this.cursorEl.style.left = `${x}px`;
    this.cursorEl.style.top = `${y}px`;
  }

  private paint(el: HTMLElement, def: ItemDef | null, textEl: HTMLElement, count: number): void {
    if (def) {
      const s = tileIconStyle(def.icon, ICON_PX);
      el.style.backgroundImage = s.backgroundImage;
      el.style.backgroundSize = s.backgroundSize;
      el.style.backgroundPosition = s.backgroundPosition;
      textEl.textContent = count > 1 ? String(count) : '';
    } else {
      el.style.backgroundImage = 'none';
      textEl.textContent = '';
    }
  }

  render(): void {
    for (const { el, ref } of this.entries) {
      const icon = el.firstElementChild as HTMLDivElement;
      const count = el.children[1] as HTMLSpanElement;
      const stack = ref.get();
      this.paint(icon, stack ? getItem(stack.item) : null, count, stack?.count ?? 0);
    }
    if (this.cursor) {
      this.cursorEl.style.display = 'flex';
      this.paint(this.cursorEl, getItem(this.cursor.item), this.cursorEl, this.cursor.count);
    } else {
      this.cursorEl.style.display = 'none';
    }
  }

  /** Move the held cursor stack back into the world/inventory on close. */
  returnCursor(spill: (item: number, count: number) => void): void {
    if (this.cursor) {
      spill(this.cursor.item, this.cursor.count);
      this.cursor = null;
    }
  }
}
