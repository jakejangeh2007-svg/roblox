/**
 * Container UI for chests and furnaces. Shares the SlotEngine cursor model with
 * the rest of the game and always shows the player's main inventory + hotbar
 * below the container-specific region so items can be moved in and out.
 *
 * The furnace view shows live burn/cook gauges; {@link update} re-renders it
 * each frame while open so the smelting countdown animates.
 */
import { Inventory, HOTBAR_SIZE, MAIN_SIZE } from '../player/Inventory';
import { isFuel, isSmeltable, COOK_TIME } from '../items/smelting';
import { SlotEngine } from './SlotEngine';
import type { ChestState, FurnaceState } from '../sim/tileEntities/TileEntities';

export type SpillHandler = (item: number, count: number) => void;

export class ContainerScreen {
  private readonly root: HTMLDivElement;
  private readonly cursorEl: HTMLDivElement;
  private readonly regionEl: HTMLDivElement;
  private readonly panel: HTMLDivElement;
  private engine: SlotEngine;
  private open = false;
  private onChange: () => void = () => {};
  private furnaceRefresh: (() => void) | null = null;
  onSpill: SpillHandler = () => {};

  constructor(hud: HTMLElement, private readonly inventory: Inventory) {
    this.root = document.createElement('div');
    this.root.id = 'container-screen';
    this.root.style.display = 'none';

    this.panel = document.createElement('div');
    this.panel.className = 'inv-panel';
    this.root.appendChild(this.panel);

    this.regionEl = document.createElement('div');
    this.regionEl.className = 'container-region';

    this.cursorEl = document.createElement('div');
    this.cursorEl.className = 'inv-cursor';
    this.cursorEl.style.display = 'none';
    this.root.appendChild(this.cursorEl);
    this.root.addEventListener('pointermove', (e) =>
      this.engine.positionCursor(e.clientX, e.clientY),
    );

    this.engine = new SlotEngine(this.cursorEl, () => this.onChange());
    hud.appendChild(this.root);
  }

  get isOpen(): boolean {
    return this.open;
  }

  private buildTitle(text: string): HTMLDivElement {
    const t = document.createElement('div');
    t.className = 'container-title';
    t.textContent = text;
    return t;
  }

  private buildPlayerInventory(): HTMLDivElement {
    const wrap = document.createElement('div');
    const main = document.createElement('div');
    main.className = 'inv-grid';
    for (let i = HOTBAR_SIZE; i < MAIN_SIZE; i++) {
      main.appendChild(this.engine.makeSlot(this.invRef(i)));
    }
    const hot = document.createElement('div');
    hot.className = 'inv-grid inv-hotbar';
    for (let i = 0; i < HOTBAR_SIZE; i++) {
      hot.appendChild(this.engine.makeSlot(this.invRef(i)));
    }
    wrap.append(main, hot);
    return wrap;
  }

  private invRef(i: number) {
    return {
      get: () => this.inventory.slots[i] ?? null,
      set: (s: import('../player/Inventory').ItemStack | null) => (this.inventory.slots[i] = s),
    };
  }

  private buildControls(): HTMLDivElement {
    const controls = document.createElement('div');
    controls.className = 'inv-controls';
    const close = document.createElement('button');
    close.className = 'inv-btn';
    close.textContent = 'Close ✕';
    close.addEventListener('click', (e) => {
      e.stopPropagation();
      this.close();
    });
    controls.appendChild(close);
    return controls;
  }

  private rebuild(): void {
    // Fresh engine each open so slot bindings don't leak between containers.
    this.engine = new SlotEngine(this.cursorEl, () => this.onChange());
    this.panel.innerHTML = '';
    this.furnaceRefresh = null;
  }

  showChest(state: ChestState, onChange: () => void): void {
    this.rebuild();
    this.onChange = onChange;
    this.panel.appendChild(this.buildTitle('Chest'));

    const grid = document.createElement('div');
    grid.className = 'inv-grid';
    for (let i = 0; i < state.slots.length; i++) {
      grid.appendChild(
        this.engine.makeSlot({
          get: () => state.slots[i] ?? null,
          set: (s) => (state.slots[i] = s),
        }),
      );
    }
    this.panel.append(grid, this.buildPlayerInventory(), this.buildControls());
    this.reveal();
  }

  showFurnace(state: FurnaceState, onChange: () => void): void {
    this.rebuild();
    this.onChange = onChange;
    this.panel.appendChild(this.buildTitle('Furnace'));

    const area = document.createElement('div');
    area.className = 'furnace-area';

    const inputSlot = this.engine.makeSlot({
      get: () => state.input,
      set: (s) => (state.input = s),
      accepts: (item) => isSmeltable(item),
    });
    const fuelSlot = this.engine.makeSlot({
      get: () => state.fuel,
      set: (s) => (state.fuel = s),
      accepts: (item) => isFuel(item),
    });
    const outputSlot = this.engine.makeSlot({
      get: () => state.output,
      set: () => {},
      takeOnly: true,
      onTake: (amount) => {
        if (state.output) {
          state.output.count -= amount;
          if (state.output.count <= 0) state.output = null;
        }
      },
    });

    // Layout: [input over fuel] [flame + arrow] [output].
    const left = document.createElement('div');
    left.className = 'furnace-left';
    const flame = document.createElement('div');
    flame.className = 'furnace-flame';
    const flameFill = document.createElement('div');
    flame.appendChild(flameFill);
    left.append(inputSlot, flame, fuelSlot);

    const arrow = document.createElement('div');
    arrow.className = 'furnace-arrow';
    const arrowFill = document.createElement('div');
    arrow.appendChild(arrowFill);

    area.append(left, arrow, outputSlot);
    this.panel.append(area, this.buildPlayerInventory(), this.buildControls());

    this.furnaceRefresh = () => {
      const burnFrac = state.burnTotal > 0 ? state.burnTime / state.burnTotal : 0;
      flameFill.style.height = `${Math.round(burnFrac * 100)}%`;
      arrowFill.style.width = `${Math.round(Math.min(1, state.cookTime / COOK_TIME) * 100)}%`;
    };
    this.reveal();
  }

  private reveal(): void {
    this.open = true;
    this.root.style.display = 'flex';
    this.engine.render();
    this.furnaceRefresh?.();
  }

  /** Called each frame while open to animate furnace gauges. */
  update(): void {
    if (!this.open) return;
    this.engine.render();
    this.furnaceRefresh?.();
  }

  close(): void {
    if (!this.open) return;
    this.engine.returnCursor(this.onSpill);
    this.onChange();
    this.open = false;
    this.root.style.display = 'none';
  }
}
