/**
 * Full-screen inventory overlay: main storage, hotbar, armor + off-hand, and a
 * crafting grid (2×2 from the inventory button, 3×3 from a crafting table) with
 * an output slot.
 *
 * Movement is cursor-based (tap-to-move), which works identically on touch and
 * mouse: tap a slot to pick up its stack onto the cursor, tap another to place
 * or swap. Secondary action (right-click, or the ½ toggle) picks up / places a
 * single item. Closing returns the cursor and crafting inputs to the inventory,
 * spilling any overflow as world drops via {@link onSpill}.
 */
import { getItem } from '../items/Item';
import { tileIconStyle } from '../world/atlas';
import { Inventory, HOTBAR_SIZE, MAIN_SIZE, type ItemStack } from '../player/Inventory';
import { CraftingGrid } from '../player/Crafting';

interface SlotRef {
  get(): ItemStack | null;
  set(s: ItemStack | null): void;
  output?: boolean;
}

const ICON_PX = 40;

export type SpillHandler = (item: number, count: number) => void;

export class InventoryScreen {
  private readonly root: HTMLDivElement;
  private readonly cursorEl: HTMLDivElement;
  private readonly craftAreaEl: HTMLDivElement;
  private crafting: CraftingGrid;
  private cursor: ItemStack | null = null;
  private readonly slotEls: { el: HTMLDivElement; ref: SlotRef }[] = [];
  private open = false;
  private secondaryMode = false;

  onSpill: SpillHandler = () => {};

  constructor(hud: HTMLElement, private readonly inventory: Inventory) {
    this.crafting = new CraftingGrid(2);

    this.root = document.createElement('div');
    this.root.id = 'inventory-screen';
    this.root.style.display = 'none';

    const panel = document.createElement('div');
    panel.className = 'inv-panel';
    this.root.appendChild(panel);

    // Top row: crafting + armor.
    const top = document.createElement('div');
    top.className = 'inv-top';
    this.craftAreaEl = document.createElement('div');
    this.craftAreaEl.className = 'inv-craft';
    const armorEl = document.createElement('div');
    armorEl.className = 'inv-armor';
    top.append(this.craftAreaEl, armorEl);
    panel.appendChild(top);

    // Armor + offhand slots.
    for (let i = 0; i < 4; i++) {
      armorEl.appendChild(
        this.makeSlot({
          get: () => this.inventory.armor[i] ?? null,
          set: (s) => (this.inventory.armor[i] = s),
        }),
      );
    }
    armorEl.appendChild(
      this.makeSlot({
        get: () => this.inventory.offhand,
        set: (s) => (this.inventory.offhand = s),
      }),
    );

    // Main storage (rows for slots 9..35).
    const main = document.createElement('div');
    main.className = 'inv-grid';
    for (let i = HOTBAR_SIZE; i < MAIN_SIZE; i++) {
      main.appendChild(this.makeSlot(this.inventorySlotRef(i)));
    }
    panel.appendChild(main);

    // Hotbar row.
    const hot = document.createElement('div');
    hot.className = 'inv-grid inv-hotbar';
    for (let i = 0; i < HOTBAR_SIZE; i++) {
      hot.appendChild(this.makeSlot(this.inventorySlotRef(i)));
    }
    panel.appendChild(hot);

    // Controls row: ½ toggle + close.
    const controls = document.createElement('div');
    controls.className = 'inv-controls';
    const half = document.createElement('button');
    half.className = 'inv-btn';
    half.textContent = '½ off';
    half.addEventListener('click', (e) => {
      e.stopPropagation();
      this.secondaryMode = !this.secondaryMode;
      half.textContent = this.secondaryMode ? '½ on' : '½ off';
      half.classList.toggle('active', this.secondaryMode);
    });
    const close = document.createElement('button');
    close.className = 'inv-btn';
    close.textContent = 'Close ✕';
    close.addEventListener('click', (e) => {
      e.stopPropagation();
      this.close();
    });
    controls.append(half, close);
    panel.appendChild(controls);

    // Floating cursor.
    this.cursorEl = document.createElement('div');
    this.cursorEl.className = 'inv-cursor';
    this.cursorEl.style.display = 'none';
    this.root.appendChild(this.cursorEl);
    this.root.addEventListener('pointermove', (e) => this.positionCursor(e.clientX, e.clientY));

    hud.appendChild(this.root);
    this.buildCraftingSlots();
  }

  get isOpen(): boolean {
    return this.open;
  }

  /** Open with a 2×2 (personal) or 3×3 (crafting table) grid. */
  show(craftWidth: 2 | 3): void {
    if (this.crafting.width !== craftWidth) {
      // Return any leftover inputs before resizing.
      this.spillCrafting();
      this.crafting = new CraftingGrid(craftWidth);
      this.buildCraftingSlots();
    }
    this.open = true;
    this.root.style.display = 'flex';
    this.render();
  }

  close(): void {
    if (!this.open) return;
    this.spillCrafting();
    if (this.cursor) {
      this.spill(this.cursor);
      this.cursor = null;
    }
    this.open = false;
    this.root.style.display = 'none';
  }

  toggle(craftWidth: 2 | 3): void {
    if (this.open) this.close();
    else this.show(craftWidth);
  }

  // --- Slot refs ------------------------------------------------------------

  private inventorySlotRef(i: number): SlotRef {
    return {
      get: () => this.inventory.slots[i] ?? null,
      set: (s) => (this.inventory.slots[i] = s),
    };
  }

  private buildCraftingSlots(): void {
    this.craftAreaEl.innerHTML = '';
    // Remove any previously-registered crafting/output slots from the list.
    for (let i = this.slotEls.length - 1; i >= 0; i--) {
      if ((this.slotEls[i]!.el.dataset.craft ?? '') !== '') this.slotEls.splice(i, 1);
    }

    const w = this.crafting.width;
    const gridEl = document.createElement('div');
    gridEl.className = 'craft-grid';
    gridEl.style.gridTemplateColumns = `repeat(${w}, 1fr)`;
    for (let i = 0; i < w * w; i++) {
      const slot = this.makeSlot({
        get: () => this.crafting.slots[i] ?? null,
        set: (s) => (this.crafting.slots[i] = s),
      });
      slot.dataset.craft = 'in';
      gridEl.appendChild(slot);
    }
    const arrow = document.createElement('div');
    arrow.className = 'craft-arrow';
    arrow.textContent = '→';
    const output = this.makeSlot({
      get: () => {
        const o = this.crafting.getOutput();
        return o ? { item: o.item, count: o.count } : null;
      },
      set: () => {},
      output: true,
    });
    output.dataset.craft = 'out';
    this.craftAreaEl.append(gridEl, arrow, output);
  }

  private makeSlot(ref: SlotRef): HTMLDivElement {
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
      const secondary = this.secondaryMode || e.button === 2;
      this.handleClick(ref, secondary);
    });
    el.addEventListener('contextmenu', (e) => e.preventDefault());
    this.slotEls.push({ el, ref });
    return el;
  }

  // --- Click logic ----------------------------------------------------------

  private handleClick(ref: SlotRef, secondary: boolean): void {
    if (ref.output) {
      this.takeOutput();
    } else if (this.cursor) {
      this.placeFromCursor(ref, secondary);
    } else {
      this.pickUp(ref, secondary);
    }
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

  private placeFromCursor(ref: SlotRef, secondary: boolean): void {
    const cur = this.cursor!;
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
      // Swap.
      ref.set(cur);
      this.cursor = stack;
    }
  }

  private takeOutput(): void {
    const out = this.crafting.getOutput();
    if (!out) return;
    const max = getItem(out.item).maxStack;
    if (!this.cursor) {
      this.cursor = { item: out.item, count: out.count };
      this.crafting.consumeInputs();
    } else if (this.cursor.item === out.item && this.cursor.count + out.count <= max) {
      this.cursor.count += out.count;
      this.crafting.consumeInputs();
    }
  }

  // --- Spill / render -------------------------------------------------------

  private spillCrafting(): void {
    for (const s of this.crafting.clear()) if (s) this.spill(s);
  }

  private spill(stack: ItemStack): void {
    const leftover = this.inventory.add(stack.item, stack.count);
    if (leftover > 0) this.onSpill(stack.item, leftover);
  }

  private positionCursor(x: number, y: number): void {
    this.cursorEl.style.left = `${x}px`;
    this.cursorEl.style.top = `${y}px`;
  }

  private renderStack(icon: HTMLDivElement, count: HTMLSpanElement, stack: ItemStack | null): void {
    if (stack) {
      const s = tileIconStyle(getItem(stack.item).icon, ICON_PX);
      icon.style.backgroundImage = s.backgroundImage;
      icon.style.backgroundSize = s.backgroundSize;
      icon.style.backgroundPosition = s.backgroundPosition;
      count.textContent = stack.count > 1 ? String(stack.count) : '';
    } else {
      icon.style.backgroundImage = 'none';
      count.textContent = '';
    }
  }

  /** Refresh all slots + cursor. Cheap; called on each change and when shown. */
  render(): void {
    for (const { el, ref } of this.slotEls) {
      const icon = el.firstElementChild as HTMLDivElement;
      const count = el.children[1] as HTMLSpanElement;
      this.renderStack(icon, count, ref.get());
    }
    if (this.cursor) {
      this.cursorEl.style.display = 'block';
      const icon = this.cursorEl;
      const s = tileIconStyle(getItem(this.cursor.item).icon, ICON_PX);
      icon.style.backgroundImage = s.backgroundImage;
      icon.style.backgroundSize = s.backgroundSize;
      icon.style.backgroundPosition = s.backgroundPosition;
      this.cursorEl.textContent = this.cursor.count > 1 ? String(this.cursor.count) : '';
    } else {
      this.cursorEl.style.display = 'none';
    }
  }
}
