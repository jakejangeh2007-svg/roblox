/**
 * Smelting recipes and fuel values for the furnace. Each smelt takes a fixed
 * cook time; fuels provide a burn duration that powers consecutive smelts.
 */
import { BlockId } from '../world/Block';
import { ItemId } from './Item';

/** Cook time per item (seconds), matching Minecraft's 10s. */
export const COOK_TIME = 10;

const SMELT = new Map<number, number>([
  [BlockId.Sand, BlockId.Glass],
  [BlockId.Cobblestone, BlockId.Stone],
  [ItemId.RawIron, ItemId.IronIngot],
  [ItemId.RawGold, ItemId.GoldIngot],
  [BlockId.OakLog, ItemId.Charcoal],
  [BlockId.BirchLog, ItemId.Charcoal],
]);

/** Burn duration in seconds each fuel provides. */
const FUEL = new Map<number, number>([
  [ItemId.Coal, 80],
  [ItemId.Charcoal, 80],
  [BlockId.Planks, 15],
  [BlockId.OakLog, 15],
  [BlockId.BirchLog, 15],
  [ItemId.Stick, 5],
  [BlockId.CraftingTable, 15],
]);

export function smeltResult(itemId: number): number | null {
  return SMELT.get(itemId) ?? null;
}

export function fuelBurnSeconds(itemId: number): number {
  return FUEL.get(itemId) ?? 0;
}

export function isFuel(itemId: number): boolean {
  return FUEL.has(itemId);
}

export function isSmeltable(itemId: number): boolean {
  return SMELT.has(itemId);
}
