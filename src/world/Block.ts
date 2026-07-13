/**
 * Block registry — the single source of truth for every voxel type. Shared by
 * the generation worker, the mesher, physics, and interaction code, so all
 * subsystems agree on IDs, textures, hardness, and drops.
 *
 * A block ID is one byte (0..255). ID 0 is always air. Texture references are
 * atlas tile indices (see items/atlas in later steps); for Step 2 the mesher
 * uses per-face tile indices to sample a 16x16 grid atlas.
 */

export const enum BlockId {
  Air = 0,
  Stone = 1,
  Grass = 2,
  Dirt = 3,
  Cobblestone = 4,
  Bedrock = 5,
  Sand = 6,
  Gravel = 7,
  OakLog = 8,
  OakLeaves = 9,
  BirchLog = 10,
  BirchLeaves = 11,
  CoalOre = 12,
  IronOre = 13,
  GoldOre = 14,
  DiamondOre = 15,
  Water = 16,
  Cactus = 17,
  Planks = 18,
  Glass = 19,
  CraftingTable = 20,
  Furnace = 21,
  Chest = 22,
  Torch = 23,
  Flower = 24,
  TallGrass = 25,
  Snow = 26,
}

/** Tool categories that speed up mining. */
export const enum ToolClass {
  None = 0,
  Pickaxe = 1,
  Axe = 2,
  Shovel = 3,
}

/** How a block's geometry is emitted by the mesher. */
export const enum RenderKind {
  /** Full opaque cube; hidden faces culled against solid neighbors. */
  Cube = 0,
  /** Transparent cube (water, glass, leaves) — culled only against same type. */
  Transparent = 1,
  /** Cross-plane sprite (flowers, grass, sapling). */
  Cross = 2,
  /** Not rendered (air). */
  None = 3,
}

/** Per-face atlas tile indices: [top, bottom, north, south, east, west]. */
export type FaceTiles = readonly [number, number, number, number, number, number];

export interface BlockDef {
  id: BlockId;
  name: string;
  render: RenderKind;
  /** true if it blocks movement (AABB collision). */
  solid: boolean;
  /** true if opaque for face-culling and light-blocking. */
  opaque: boolean;
  /** Mining hardness (seconds with bare hand at multiplier 1). <0 = unbreakable. */
  hardness: number;
  /** Tool that mines it fastest. */
  tool: ToolClass;
  /** true if the correct tool is *required* to get a drop (e.g. stone→pickaxe). */
  requiresTool: boolean;
  /** Light emitted (0..15). Torches, lava, etc. */
  lightEmission: number;
  /** How much sky/block light this block subtracts when propagating (opaque=15). */
  lightOpacity: number;
  /** Atlas tiles per face. */
  tiles: FaceTiles;
  /** Block dropped when mined (defaults to self). BlockId.Air = drops nothing. */
  drop?: BlockId;
}

function uniform(tile: number): FaceTiles {
  return [tile, tile, tile, tile, tile, tile];
}

/** top/bottom differ from sides (grass, logs). */
function column(top: number, bottom: number, side: number): FaceTiles {
  return [top, bottom, side, side, side, side];
}

// Atlas layout (row-major, 16 tiles wide). Kept small and contiguous so the
// generated atlas texture (Step 5 replaces the procedural one) stays compact.
const T = {
  stone: 0,
  dirt: 1,
  grassTop: 2,
  grassSide: 3,
  cobble: 4,
  bedrock: 5,
  sand: 6,
  gravel: 7,
  logTop: 8,
  logSide: 9,
  leaves: 10,
  birchTop: 11,
  birchSide: 12,
  birchLeaves: 13,
  coal: 14,
  iron: 15,
  gold: 16,
  diamond: 17,
  water: 18,
  cactusTop: 19,
  cactusSide: 20,
  planks: 21,
  glass: 22,
  craftTop: 23,
  craftSide: 24,
  furnaceFront: 25,
  furnaceSide: 26,
  furnaceTop: 27,
  chest: 28,
  torch: 29,
  flower: 30,
  tallgrass: 31,
  snow: 32,
} as const;

const DEFS: BlockDef[] = [];

function def(d: BlockDef): void {
  DEFS[d.id] = d;
}

def({
  id: BlockId.Air, name: 'Air', render: RenderKind.None, solid: false, opaque: false,
  hardness: 0, tool: ToolClass.None, requiresTool: false, lightEmission: 0,
  lightOpacity: 0, tiles: uniform(0), drop: BlockId.Air,
});
def({
  id: BlockId.Stone, name: 'Stone', render: RenderKind.Cube, solid: true, opaque: true,
  hardness: 1.5, tool: ToolClass.Pickaxe, requiresTool: true, lightEmission: 0,
  lightOpacity: 15, tiles: uniform(T.stone), drop: BlockId.Cobblestone,
});
def({
  id: BlockId.Grass, name: 'Grass Block', render: RenderKind.Cube, solid: true, opaque: true,
  hardness: 0.6, tool: ToolClass.Shovel, requiresTool: false, lightEmission: 0,
  lightOpacity: 15, tiles: column(T.grassTop, T.dirt, T.grassSide), drop: BlockId.Dirt,
});
def({
  id: BlockId.Dirt, name: 'Dirt', render: RenderKind.Cube, solid: true, opaque: true,
  hardness: 0.5, tool: ToolClass.Shovel, requiresTool: false, lightEmission: 0,
  lightOpacity: 15, tiles: uniform(T.dirt),
});
def({
  id: BlockId.Cobblestone, name: 'Cobblestone', render: RenderKind.Cube, solid: true,
  opaque: true, hardness: 2.0, tool: ToolClass.Pickaxe, requiresTool: true,
  lightEmission: 0, lightOpacity: 15, tiles: uniform(T.cobble),
});
def({
  id: BlockId.Bedrock, name: 'Bedrock', render: RenderKind.Cube, solid: true, opaque: true,
  hardness: -1, tool: ToolClass.None, requiresTool: false, lightEmission: 0,
  lightOpacity: 15, tiles: uniform(T.bedrock),
});
def({
  id: BlockId.Sand, name: 'Sand', render: RenderKind.Cube, solid: true, opaque: true,
  hardness: 0.5, tool: ToolClass.Shovel, requiresTool: false, lightEmission: 0,
  lightOpacity: 15, tiles: uniform(T.sand),
});
def({
  id: BlockId.Gravel, name: 'Gravel', render: RenderKind.Cube, solid: true, opaque: true,
  hardness: 0.6, tool: ToolClass.Shovel, requiresTool: false, lightEmission: 0,
  lightOpacity: 15, tiles: uniform(T.gravel),
});
def({
  id: BlockId.OakLog, name: 'Oak Log', render: RenderKind.Cube, solid: true, opaque: true,
  hardness: 2.0, tool: ToolClass.Axe, requiresTool: false, lightEmission: 0,
  lightOpacity: 15, tiles: column(T.logTop, T.logTop, T.logSide),
});
def({
  id: BlockId.OakLeaves, name: 'Oak Leaves', render: RenderKind.Transparent, solid: true,
  opaque: false, hardness: 0.2, tool: ToolClass.None, requiresTool: false,
  lightEmission: 0, lightOpacity: 1, tiles: uniform(T.leaves), drop: BlockId.Air,
});
def({
  id: BlockId.BirchLog, name: 'Birch Log', render: RenderKind.Cube, solid: true, opaque: true,
  hardness: 2.0, tool: ToolClass.Axe, requiresTool: false, lightEmission: 0,
  lightOpacity: 15, tiles: column(T.birchTop, T.birchTop, T.birchSide),
});
def({
  id: BlockId.BirchLeaves, name: 'Birch Leaves', render: RenderKind.Transparent, solid: true,
  opaque: false, hardness: 0.2, tool: ToolClass.None, requiresTool: false,
  lightEmission: 0, lightOpacity: 1, tiles: uniform(T.birchLeaves), drop: BlockId.Air,
});
def({
  id: BlockId.CoalOre, name: 'Coal Ore', render: RenderKind.Cube, solid: true, opaque: true,
  hardness: 3.0, tool: ToolClass.Pickaxe, requiresTool: true, lightEmission: 0,
  lightOpacity: 15, tiles: uniform(T.coal),
});
def({
  id: BlockId.IronOre, name: 'Iron Ore', render: RenderKind.Cube, solid: true, opaque: true,
  hardness: 3.0, tool: ToolClass.Pickaxe, requiresTool: true, lightEmission: 0,
  lightOpacity: 15, tiles: uniform(T.iron),
});
def({
  id: BlockId.GoldOre, name: 'Gold Ore', render: RenderKind.Cube, solid: true, opaque: true,
  hardness: 3.0, tool: ToolClass.Pickaxe, requiresTool: true, lightEmission: 0,
  lightOpacity: 15, tiles: uniform(T.gold),
});
def({
  id: BlockId.DiamondOre, name: 'Diamond Ore', render: RenderKind.Cube, solid: true,
  opaque: true, hardness: 3.0, tool: ToolClass.Pickaxe, requiresTool: true,
  lightEmission: 0, lightOpacity: 15, tiles: uniform(T.diamond),
});
def({
  id: BlockId.Water, name: 'Water', render: RenderKind.Transparent, solid: false, opaque: false,
  hardness: -1, tool: ToolClass.None, requiresTool: false, lightEmission: 0,
  lightOpacity: 2, tiles: uniform(T.water), drop: BlockId.Air,
});
def({
  id: BlockId.Cactus, name: 'Cactus', render: RenderKind.Cube, solid: true, opaque: false,
  hardness: 0.4, tool: ToolClass.None, requiresTool: false, lightEmission: 0,
  lightOpacity: 15, tiles: column(T.cactusTop, T.cactusTop, T.cactusSide),
});
def({
  id: BlockId.Planks, name: 'Oak Planks', render: RenderKind.Cube, solid: true, opaque: true,
  hardness: 2.0, tool: ToolClass.Axe, requiresTool: false, lightEmission: 0,
  lightOpacity: 15, tiles: uniform(T.planks),
});
def({
  id: BlockId.Glass, name: 'Glass', render: RenderKind.Transparent, solid: true, opaque: false,
  hardness: 0.3, tool: ToolClass.None, requiresTool: false, lightEmission: 0,
  lightOpacity: 0, tiles: uniform(T.glass), drop: BlockId.Air,
});
def({
  id: BlockId.CraftingTable, name: 'Crafting Table', render: RenderKind.Cube, solid: true,
  opaque: true, hardness: 2.5, tool: ToolClass.Axe, requiresTool: false, lightEmission: 0,
  lightOpacity: 15, tiles: column(T.craftTop, T.planks, T.craftSide),
});
def({
  id: BlockId.Furnace, name: 'Furnace', render: RenderKind.Cube, solid: true, opaque: true,
  hardness: 3.5, tool: ToolClass.Pickaxe, requiresTool: true, lightEmission: 0,
  lightOpacity: 15, tiles: [T.furnaceTop, T.furnaceTop, T.furnaceFront, T.furnaceSide, T.furnaceSide, T.furnaceSide],
  drop: BlockId.Furnace,
});
def({
  id: BlockId.Chest, name: 'Chest', render: RenderKind.Cube, solid: true, opaque: true,
  hardness: 2.5, tool: ToolClass.Axe, requiresTool: false, lightEmission: 0,
  lightOpacity: 15, tiles: uniform(T.chest),
});
def({
  id: BlockId.Torch, name: 'Torch', render: RenderKind.Cross, solid: false, opaque: false,
  hardness: 0, tool: ToolClass.None, requiresTool: false, lightEmission: 14,
  lightOpacity: 0, tiles: uniform(T.torch),
});
def({
  id: BlockId.Flower, name: 'Flower', render: RenderKind.Cross, solid: false, opaque: false,
  hardness: 0, tool: ToolClass.None, requiresTool: false, lightEmission: 0,
  lightOpacity: 0, tiles: uniform(T.flower),
});
def({
  id: BlockId.TallGrass, name: 'Grass', render: RenderKind.Cross, solid: false, opaque: false,
  hardness: 0, tool: ToolClass.None, requiresTool: false, lightEmission: 0,
  lightOpacity: 0, tiles: uniform(T.tallgrass), drop: BlockId.Air,
});
def({
  id: BlockId.Snow, name: 'Snow Block', render: RenderKind.Cube, solid: true, opaque: true,
  hardness: 0.6, tool: ToolClass.Shovel, requiresTool: false, lightEmission: 0,
  lightOpacity: 15, tiles: uniform(T.snow),
});

/** Frozen registry, indexed by BlockId. */
export const BLOCKS: readonly BlockDef[] = DEFS;

export const ATLAS_TILE_COUNT = 33;

export function getBlock(id: number): BlockDef {
  const b = DEFS[id];
  if (!b) throw new Error(`Unknown block id ${id}`);
  return b;
}

export function isSolid(id: number): boolean {
  return DEFS[id]?.solid ?? false;
}

export function isOpaque(id: number): boolean {
  return DEFS[id]?.opaque ?? false;
}

export function lightOpacity(id: number): number {
  return DEFS[id]?.lightOpacity ?? 15;
}

export function lightEmission(id: number): number {
  return DEFS[id]?.lightEmission ?? 0;
}
