/**
 * Item registry. Items fall into three groups:
 *  - Block items: id == BlockId, placeable, derived automatically from BLOCKS.
 *  - Tools (ids >= 100): pickaxe/axe/shovel/sword in wood→diamond tiers, with a
 *    speed multiplier and durability.
 *  - Materials & food (ids >= 140): sticks, ingots, diamonds, apples, bread…
 *
 * The break-time formula mirrors Minecraft: hardness × (canHarvest ? 1.5 : 5)
 * ÷ toolSpeed, so a diamond pickaxe shreds stone while a hand barely dents it.
 */
import { BLOCKS, BlockId, ToolClass, getBlock as getBlockDef, type BlockDef } from '../world/Block';

export const enum ToolTier {
  Hand = 0,
  Wood = 1,
  Stone = 2,
  Iron = 3,
  Diamond = 4,
}

export const enum ItemId {
  // 1..99 reserved for block items (id === BlockId).
  WoodPickaxe = 100,
  StonePickaxe = 101,
  IronPickaxe = 102,
  DiamondPickaxe = 103,
  WoodAxe = 104,
  StoneAxe = 105,
  IronAxe = 106,
  DiamondAxe = 107,
  WoodShovel = 108,
  StoneShovel = 109,
  IronShovel = 110,
  DiamondShovel = 111,
  WoodSword = 112,
  StoneSword = 113,
  IronSword = 114,
  DiamondSword = 115,

  Stick = 140,
  Coal = 141,
  IronIngot = 142,
  GoldIngot = 143,
  Diamond = 144,
  RawIron = 145,
  RawGold = 146,
  Apple = 147,
  Bread = 148,
  CookedPorkchop = 149,
  Wheat = 150,
  Charcoal = 151,
}

export interface ToolInfo {
  class: ToolClass;
  tier: ToolTier;
  /** Mining speed multiplier vs. hand. */
  speed: number;
  maxDurability: number;
}

export interface ItemDef {
  id: number;
  name: string;
  maxStack: number;
  /** Block placed when used against a surface (block items only). */
  placeBlock?: BlockId;
  tool?: ToolInfo;
  /** Half-shanks of hunger restored when eaten. */
  food?: number;
  /** Atlas tile for the 2D icon (block items reuse their block's top tile). */
  icon: number;
}

const ITEMS = new Map<number, ItemDef>();

function register(def: ItemDef): void {
  ITEMS.set(def.id, def);
}

// --- Block items: derived from the block registry -------------------------
for (const b of BLOCKS) {
  if (!b || b.id === BlockId.Air) continue;
  register({
    id: b.id,
    name: b.name,
    maxStack: 64,
    placeBlock: b.id,
    icon: b.tiles[0], // top face reads best as an icon
  });
}

// --- Tools ----------------------------------------------------------------
const TIER_SPEED: Record<ToolTier, number> = {
  [ToolTier.Hand]: 1,
  [ToolTier.Wood]: 2,
  [ToolTier.Stone]: 4,
  [ToolTier.Iron]: 6,
  [ToolTier.Diamond]: 8,
};
const TIER_DURABILITY: Record<ToolTier, number> = {
  [ToolTier.Hand]: 0,
  [ToolTier.Wood]: 59,
  [ToolTier.Stone]: 131,
  [ToolTier.Iron]: 250,
  [ToolTier.Diamond]: 1561,
};
const TIER_NAME: Record<ToolTier, string> = {
  [ToolTier.Hand]: 'Hand',
  [ToolTier.Wood]: 'Wooden',
  [ToolTier.Stone]: 'Stone',
  [ToolTier.Iron]: 'Iron',
  [ToolTier.Diamond]: 'Diamond',
};

// Icon tiles for tools (reuse a few atlas cells as simple placeholders).
function tool(id: ItemId, cls: ToolClass, tier: ToolTier, kind: string, icon: number): void {
  register({
    id,
    name: `${TIER_NAME[tier]} ${kind}`,
    maxStack: 1,
    tool: { class: cls, tier, speed: TIER_SPEED[tier], maxDurability: TIER_DURABILITY[tier] },
    icon,
  });
}
tool(ItemId.WoodPickaxe, ToolClass.Pickaxe, ToolTier.Wood, 'Pickaxe', 4);
tool(ItemId.StonePickaxe, ToolClass.Pickaxe, ToolTier.Stone, 'Pickaxe', 4);
tool(ItemId.IronPickaxe, ToolClass.Pickaxe, ToolTier.Iron, 'Pickaxe', 4);
tool(ItemId.DiamondPickaxe, ToolClass.Pickaxe, ToolTier.Diamond, 'Pickaxe', 4);
tool(ItemId.WoodAxe, ToolClass.Axe, ToolTier.Wood, 'Axe', 9);
tool(ItemId.StoneAxe, ToolClass.Axe, ToolTier.Stone, 'Axe', 9);
tool(ItemId.IronAxe, ToolClass.Axe, ToolTier.Iron, 'Axe', 9);
tool(ItemId.DiamondAxe, ToolClass.Axe, ToolTier.Diamond, 'Axe', 9);
tool(ItemId.WoodShovel, ToolClass.Shovel, ToolTier.Wood, 'Shovel', 1);
tool(ItemId.StoneShovel, ToolClass.Shovel, ToolTier.Stone, 'Shovel', 1);
tool(ItemId.IronShovel, ToolClass.Shovel, ToolTier.Iron, 'Shovel', 1);
tool(ItemId.DiamondShovel, ToolClass.Shovel, ToolTier.Diamond, 'Shovel', 1);
tool(ItemId.WoodSword, ToolClass.None, ToolTier.Wood, 'Sword', 9);
tool(ItemId.StoneSword, ToolClass.None, ToolTier.Stone, 'Sword', 9);
tool(ItemId.IronSword, ToolClass.None, ToolTier.Iron, 'Sword', 9);
tool(ItemId.DiamondSword, ToolClass.None, ToolTier.Diamond, 'Sword', 9);

// --- Materials & food -----------------------------------------------------
register({ id: ItemId.Stick, name: 'Stick', maxStack: 64, icon: 9 });
register({ id: ItemId.Coal, name: 'Coal', maxStack: 64, icon: 14 });
register({ id: ItemId.Charcoal, name: 'Charcoal', maxStack: 64, icon: 14 });
register({ id: ItemId.IronIngot, name: 'Iron Ingot', maxStack: 64, icon: 15 });
register({ id: ItemId.GoldIngot, name: 'Gold Ingot', maxStack: 64, icon: 16 });
register({ id: ItemId.Diamond, name: 'Diamond', maxStack: 64, icon: 17 });
register({ id: ItemId.RawIron, name: 'Raw Iron', maxStack: 64, icon: 15 });
register({ id: ItemId.RawGold, name: 'Raw Gold', maxStack: 64, icon: 16 });
register({ id: ItemId.Apple, name: 'Apple', maxStack: 64, food: 8, icon: 30 });
register({ id: ItemId.Bread, name: 'Bread', maxStack: 64, food: 10, icon: 21 });
register({ id: ItemId.CookedPorkchop, name: 'Cooked Porkchop', maxStack: 64, food: 16, icon: 30 });
register({ id: ItemId.Wheat, name: 'Wheat', maxStack: 64, icon: 31 });

export function getItem(id: number): ItemDef {
  const d = ITEMS.get(id);
  if (!d) throw new Error(`Unknown item id ${id}`);
  return d;
}

export function maybeItem(id: number): ItemDef | undefined {
  return ITEMS.get(id);
}

/** Minimum tool tier required to *harvest* a block (get its drop). */
export function harvestTier(block: BlockDef): ToolTier {
  if (!block.requiresTool) return ToolTier.Hand;
  switch (block.id) {
    case BlockId.GoldOre:
    case BlockId.DiamondOre:
      return ToolTier.Iron;
    default:
      return ToolTier.Wood;
  }
}

/** Whether the held item can harvest (yield a drop from) the block. */
export function canHarvest(block: BlockDef, held: ItemDef | undefined): boolean {
  if (!block.requiresTool) return true;
  const tool = held?.tool;
  if (!tool || tool.class !== block.tool) return false;
  return tool.tier >= harvestTier(block);
}

/** Seconds to break a block with the given held item (hand if undefined). */
export function breakTimeSeconds(block: BlockDef, held: ItemDef | undefined): number {
  if (block.hardness < 0) return Infinity; // unbreakable (bedrock, water)
  if (block.hardness === 0) return 0;
  const tool = held?.tool;
  const speed = tool && tool.class === block.tool ? tool.speed : 1;
  const base = canHarvest(block, held) ? 1.5 : 5;
  return (block.hardness * base) / speed;
}

/** Resolve the block a block-item places, or null for non-placeables. */
export function placeableBlock(itemId: number): BlockId | null {
  return maybeItem(itemId)?.placeBlock ?? null;
}

/** Block-def lookup convenience re-export (keeps callers off two imports). */
export { getBlockDef };
