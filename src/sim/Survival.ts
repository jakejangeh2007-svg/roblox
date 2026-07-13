/**
 * Health & hunger simulation. Hunger drains via an exhaustion budget that fills
 * from exertion (sprinting, jumping, mining) and passive metabolism; when full
 * it costs one hunger point. Near-full hunger regenerates health; empty hunger
 * starves it. Fall damage is applied in the player physics; this system reads
 * the resulting health and handles the slow ambient changes.
 */
import type { Player } from '../player/Player';

const EXHAUSTION_PER_HUNGER = 4;
const REGEN_HUNGER_THRESHOLD = 18; // >=90% hunger regenerates health
const REGEN_INTERVAL = 3.0; // seconds per half-heart regenerated
const STARVE_INTERVAL = 4.0; // seconds per half-heart lost when starving

export interface Exertion {
  sprinting: boolean;
  jumped: boolean;
  blocksMined: number;
}

export class Survival {
  private exhaustion = 0;
  private regenTimer = 0;
  private starveTimer = 0;

  /** Advance one tick, applying hunger drain, regen, and starvation. */
  update(dt: number, player: Player, exertion: Exertion): void {
    // --- Exhaustion accrual → hunger drain ---------------------------------
    this.exhaustion += 0.015 * dt; // passive metabolism
    if (exertion.sprinting) this.exhaustion += 0.12 * dt;
    if (exertion.jumped) this.exhaustion += exertion.sprinting ? 0.2 : 0.05;
    this.exhaustion += exertion.blocksMined * 0.005;

    while (this.exhaustion >= EXHAUSTION_PER_HUNGER) {
      this.exhaustion -= EXHAUSTION_PER_HUNGER;
      if (player.hunger > 0) player.hunger -= 1;
    }

    // --- Regeneration ------------------------------------------------------
    if (player.hunger >= REGEN_HUNGER_THRESHOLD && player.health < player.maxHealth) {
      this.regenTimer += dt;
      if (this.regenTimer >= REGEN_INTERVAL) {
        this.regenTimer = 0;
        player.health = Math.min(player.maxHealth, player.health + 1);
        this.exhaustion += 1.5; // regen burns food
      }
    } else {
      this.regenTimer = 0;
    }

    // --- Starvation --------------------------------------------------------
    if (player.hunger <= 0) {
      this.starveTimer += dt;
      if (this.starveTimer >= STARVE_INTERVAL) {
        this.starveTimer = 0;
        player.health = Math.max(0, player.health - 1);
      }
    } else {
      this.starveTimer = 0;
    }
  }

  /** Consume a food item restoring `foodValue` hunger (half-shanks). */
  eat(player: Player, foodValue: number): void {
    player.hunger = Math.min(player.maxHunger, player.hunger + foodValue);
    // Eating reduces built-up exhaustion a little.
    this.exhaustion = Math.max(0, this.exhaustion - 1);
  }

  get isDead(): boolean {
    return false;
  }
}
