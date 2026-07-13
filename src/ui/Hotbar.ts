/**
 * Bottom-centered 9-slot hotbar. Shows the item icon and stack count per slot,
 * highlights the selected slot, and lets the player switch slots by tapping a
 * slot (touch), pressing 1–9, or scrolling the wheel (desktop). Reads live from
 * the Inventory each frame via {@link render}.
 */
import { getItem } from '../items/Item';
import { tileIconStyle } from '../world/atlas';
import type { Inventory } from '../player/Inventory';
import { HOTBAR_SIZE } from '../player/Inventory';

const ICON_PX = 44;

export class Hotbar {
  private readonly root: HTMLDivElement;
  private readonly slots: HTMLDivElement[] = [];
  private readonly icons: HTMLDivElement[] = [];
  private readonly counts: HTMLSpanElement[] = [];
  private readonly durabilities: HTMLDivElement[] = [];
  private lastSelected = -1;

  constructor(hud: HTMLElement, private readonly inventory: Inventory) {
    this.root = document.createElement('div');
    this.root.id = 'hotbar';
    for (let i = 0; i < HOTBAR_SIZE; i++) {
      const slot = document.createElement('div');
      slot.className = 'hotbar-slot';
      const icon = document.createElement('div');
      icon.className = 'slot-icon';
      const count = document.createElement('span');
      count.className = 'slot-count';
      const dura = document.createElement('div');
      dura.className = 'slot-durability';
      slot.append(icon, count, dura);
      slot.addEventListener('touchstart', (e) => {
        e.preventDefault();
        e.stopPropagation();
        this.inventory.setSelectedSlot(i);
      });
      slot.addEventListener('mousedown', (e) => {
        e.stopPropagation();
        this.inventory.setSelectedSlot(i);
      });
      this.root.appendChild(slot);
      this.slots.push(slot);
      this.icons.push(icon);
      this.counts.push(count);
      this.durabilities.push(dura);
    }
    hud.appendChild(this.root);

    window.addEventListener('keydown', (e) => {
      const n = Number(e.key);
      if (n >= 1 && n <= 9) this.inventory.setSelectedSlot(n - 1);
    });
    window.addEventListener(
      'wheel',
      (e) => {
        if (e.deltaY === 0) return;
        this.inventory.setSelectedSlot(
          this.inventory.selectedSlot + (e.deltaY > 0 ? 1 : -1),
        );
      },
      { passive: true },
    );
  }

  /** Refresh visuals from the inventory. Cheap; called each frame. */
  render(): void {
    for (let i = 0; i < HOTBAR_SIZE; i++) {
      const stack = this.inventory.slots[i] ?? null;
      const icon = this.icons[i]!;
      const count = this.counts[i]!;
      const dura = this.durabilities[i]!;
      if (stack) {
        const def = getItem(stack.item);
        const s = tileIconStyle(def.icon, ICON_PX);
        icon.style.backgroundImage = s.backgroundImage;
        icon.style.backgroundSize = s.backgroundSize;
        icon.style.backgroundPosition = s.backgroundPosition;
        icon.style.opacity = '1';
        count.textContent = stack.count > 1 ? String(stack.count) : '';
        if (def.tool && stack.durability !== undefined) {
          const frac = Math.max(0, stack.durability / def.tool.maxDurability);
          dura.style.display = 'block';
          dura.style.transform = `scaleX(${frac})`;
          dura.style.background = frac > 0.4 ? '#4caf50' : frac > 0.15 ? '#ffb300' : '#e53935';
        } else {
          dura.style.display = 'none';
        }
      } else {
        icon.style.backgroundImage = 'none';
        count.textContent = '';
        dura.style.display = 'none';
      }
    }
    if (this.inventory.selectedSlot !== this.lastSelected) {
      this.slots.forEach((s, i) =>
        s.classList.toggle('selected', i === this.inventory.selectedSlot),
      );
      this.lastSelected = this.inventory.selectedSlot;
    }
  }
}
