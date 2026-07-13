/**
 * Health (hearts) and hunger (shanks) bars above the hotbar. Each of the 10
 * hearts / 10 shanks represents 2 points, rendered full / half / empty. Drawn
 * with CSS so they cost nothing on the GPU. Air bubbles show while submerged.
 */
import type { Player } from '../player/Player';

const HEARTS = 10;

export class StatusBars {
  private readonly root: HTMLDivElement;
  private readonly hearts: HTMLDivElement[] = [];
  private readonly shanks: HTMLDivElement[] = [];
  private lastHealth = -1;
  private lastHunger = -1;

  constructor(hud: HTMLElement) {
    this.root = document.createElement('div');
    this.root.id = 'status-bars';

    const healthRow = document.createElement('div');
    healthRow.className = 'status-row health-row';
    const hungerRow = document.createElement('div');
    hungerRow.className = 'status-row hunger-row';

    for (let i = 0; i < HEARTS; i++) {
      const h = document.createElement('div');
      h.className = 'heart';
      healthRow.appendChild(h);
      this.hearts.push(h);
      const s = document.createElement('div');
      s.className = 'shank';
      hungerRow.appendChild(s);
      this.shanks.push(s);
    }
    // Hunger reads right-to-left in Minecraft.
    hungerRow.style.flexDirection = 'row-reverse';
    this.root.append(hungerRow, healthRow);
    hud.appendChild(this.root);
  }

  render(player: Player): void {
    if (player.health !== this.lastHealth) {
      this.fill(this.hearts, player.health);
      this.lastHealth = player.health;
    }
    if (player.hunger !== this.lastHunger) {
      this.fill(this.shanks, player.hunger);
      this.lastHunger = player.hunger;
    }
  }

  /** value is in half-units (0..20); each icon is 2 units. */
  private fill(icons: HTMLDivElement[], value: number): void {
    for (let i = 0; i < icons.length; i++) {
      const full = value >= (i + 1) * 2;
      const half = !full && value >= i * 2 + 1;
      const el = icons[i]!;
      el.classList.toggle('full', full);
      el.classList.toggle('half', half);
      el.classList.toggle('empty', !full && !half);
    }
  }
}
