/**
 * Pure furnace smelting logic, separated from persistence so it can be unit
 * tested without IndexedDB. Advances burn/cook timers, lights fuel on demand,
 * and produces smelted output.
 */
import { smeltResult, fuelBurnSeconds, COOK_TIME } from '../../items/smelting';
import { getItem } from '../../items/Item';
import type { FurnaceState } from './TileEntities';

export function furnaceCanSmelt(f: FurnaceState): boolean {
  if (!f.input) return false;
  const result = smeltResult(f.input.item);
  if (result === null) return false;
  if (!f.output) return true;
  if (f.output.item !== result) return false;
  return f.output.count < getItem(result).maxStack;
}

function smeltOne(f: FurnaceState): void {
  if (!f.input) return;
  const result = smeltResult(f.input.item);
  if (result === null) return;
  f.input.count -= 1;
  if (f.input.count <= 0) f.input = null;
  if (f.output && f.output.item === result) f.output.count += 1;
  else f.output = { item: result, count: 1 };
}

/** Advance a furnace one tick. Returns true if anything changed. */
export function tickFurnace(f: FurnaceState, dt: number): boolean {
  let changed = false;
  const canSmelt = furnaceCanSmelt(f);

  // Light new fuel if idle and there's something to smelt.
  if (f.burnTime <= 0 && canSmelt && f.fuel) {
    const burn = fuelBurnSeconds(f.fuel.item);
    if (burn > 0) {
      f.burnTime = burn;
      f.burnTotal = burn;
      f.fuel.count -= 1;
      if (f.fuel.count <= 0) f.fuel = null;
      changed = true;
    }
  }

  if (f.burnTime > 0) {
    f.burnTime = Math.max(0, f.burnTime - dt);
    changed = true;
    if (canSmelt) {
      f.cookTime += dt;
      if (f.cookTime >= COOK_TIME) {
        f.cookTime = 0;
        smeltOne(f);
      }
    } else {
      f.cookTime = Math.max(0, f.cookTime - dt * 2);
    }
  } else if (f.cookTime > 0) {
    f.cookTime = Math.max(0, f.cookTime - dt * 2);
    changed = true;
  }
  return changed;
}
