/**
 * Crafting recipes and the matcher shared by the 2×2 (inventory) and 3×3
 * (crafting-table) grids. Supports shaped recipes (position-sensitive, trimmed
 * to a bounding box like Minecraft) and shapeless recipes (multiset of
 * ingredients). A 3-wide shaped recipe simply never matches a 2×2 grid.
 */
import { BlockId } from '../world/Block';
import { ItemId } from './Item';

export interface RecipeOutput {
  item: number;
  count: number;
}

interface ShapedRecipe {
  kind: 'shaped';
  /** Rows of single-char cells; space = empty. */
  pattern: string[];
  key: Record<string, number>;
  out: RecipeOutput;
}

interface ShapelessRecipe {
  kind: 'shapeless';
  ingredients: number[];
  out: RecipeOutput;
}

export type Recipe = ShapedRecipe | ShapelessRecipe;

const RECIPES: Recipe[] = [];

function shaped(pattern: string[], key: Record<string, number>, out: RecipeOutput): void {
  RECIPES.push({ kind: 'shaped', pattern, key, out });
}
function shapeless(ingredients: number[], out: RecipeOutput): void {
  RECIPES.push({ kind: 'shapeless', ingredients, out });
}

// --- Basic materials ------------------------------------------------------
shapeless([BlockId.OakLog], { item: BlockId.Planks, count: 4 });
shapeless([BlockId.BirchLog], { item: BlockId.Planks, count: 4 });
shaped(['P', 'P'], { P: BlockId.Planks }, { item: ItemId.Stick, count: 4 });

// --- Stations -------------------------------------------------------------
shaped(['PP', 'PP'], { P: BlockId.Planks }, { item: BlockId.CraftingTable, count: 1 });
shaped(['CCC', 'C C', 'CCC'], { C: BlockId.Cobblestone }, { item: BlockId.Furnace, count: 1 });
shaped(['PPP', 'P P', 'PPP'], { P: BlockId.Planks }, { item: BlockId.Chest, count: 1 });
shaped(
  ['c', 'S'],
  { c: ItemId.Coal, S: ItemId.Stick },
  { item: BlockId.Torch, count: 4 },
);
shaped(
  ['h', 'S'],
  { h: ItemId.Charcoal, S: ItemId.Stick },
  { item: BlockId.Torch, count: 4 },
);

// --- Tools (3×3): head material M over a stick handle ----------------------
interface ToolSet {
  material: number;
  pickaxe: number;
  axe: number;
  shovel: number;
  sword: number;
}
const TOOL_SETS: ToolSet[] = [
  {
    material: BlockId.Planks,
    pickaxe: ItemId.WoodPickaxe,
    axe: ItemId.WoodAxe,
    shovel: ItemId.WoodShovel,
    sword: ItemId.WoodSword,
  },
  {
    material: BlockId.Cobblestone,
    pickaxe: ItemId.StonePickaxe,
    axe: ItemId.StoneAxe,
    shovel: ItemId.StoneShovel,
    sword: ItemId.StoneSword,
  },
  {
    material: ItemId.IronIngot,
    pickaxe: ItemId.IronPickaxe,
    axe: ItemId.IronAxe,
    shovel: ItemId.IronShovel,
    sword: ItemId.IronSword,
  },
  {
    material: ItemId.Diamond,
    pickaxe: ItemId.DiamondPickaxe,
    axe: ItemId.DiamondAxe,
    shovel: ItemId.DiamondShovel,
    sword: ItemId.DiamondSword,
  },
];
for (const t of TOOL_SETS) {
  const key = { M: t.material, S: ItemId.Stick };
  shaped(['MMM', ' S ', ' S '], key, { item: t.pickaxe, count: 1 });
  shaped(['MM', 'MS', ' S'], key, { item: t.axe, count: 1 });
  shaped(['M', 'S', 'S'], key, { item: t.shovel, count: 1 });
  shaped(['M', 'M', 'S'], key, { item: t.sword, count: 1 });
}

// --- Food -----------------------------------------------------------------
shaped(['WWW'], { W: ItemId.Wheat }, { item: ItemId.Bread, count: 1 });

// ---------------------------------------------------------------------------

interface Bounds {
  cells: (number | null)[][];
  rows: number;
  cols: number;
}

/** Trim a square grid to the bounding box of its non-null cells. */
function boundingBox(grid: (number | null)[], width: number): Bounds | null {
  let minR = width;
  let maxR = -1;
  let minC = width;
  let maxC = -1;
  for (let r = 0; r < width; r++) {
    for (let c = 0; c < width; c++) {
      if (grid[r * width + c] != null) {
        if (r < minR) minR = r;
        if (r > maxR) maxR = r;
        if (c < minC) minC = c;
        if (c > maxC) maxC = c;
      }
    }
  }
  if (maxR < 0) return null; // empty grid
  const rows = maxR - minR + 1;
  const cols = maxC - minC + 1;
  const cells: (number | null)[][] = [];
  for (let r = 0; r < rows; r++) {
    const row: (number | null)[] = [];
    for (let c = 0; c < cols; c++) {
      row.push(grid[(minR + r) * width + (minC + c)] ?? null);
    }
    cells.push(row);
  }
  return { cells, rows, cols };
}

function patternToBounds(recipe: ShapedRecipe): Bounds {
  const rows = recipe.pattern.length;
  let cols = 0;
  for (const row of recipe.pattern) cols = Math.max(cols, row.length);
  const cells: (number | null)[][] = [];
  for (let r = 0; r < rows; r++) {
    const row: (number | null)[] = [];
    const str = recipe.pattern[r]!;
    for (let c = 0; c < cols; c++) {
      const ch = str[c] ?? ' ';
      row.push(ch === ' ' ? null : (recipe.key[ch] ?? null));
    }
    cells.push(row);
  }
  return { cells, rows, cols };
}

function matchShaped(recipe: ShapedRecipe, input: Bounds): boolean {
  const pat = patternToBounds(recipe);
  if (pat.rows !== input.rows || pat.cols !== input.cols) return false;
  for (let r = 0; r < pat.rows; r++) {
    for (let c = 0; c < pat.cols; c++) {
      if (pat.cells[r]![c] !== input.cells[r]![c]) return false;
    }
  }
  return true;
}

function matchShapeless(recipe: ShapelessRecipe, grid: (number | null)[]): boolean {
  const items = grid.filter((x): x is number => x != null).sort((a, b) => a - b);
  if (items.length !== recipe.ingredients.length) return false;
  const ing = [...recipe.ingredients].sort((a, b) => a - b);
  return items.every((v, i) => v === ing[i]);
}

/**
 * Find the output for a crafting grid. `grid` holds one *item id per slot*
 * (ignoring counts — one of each is consumed), row-major, width 2 or 3.
 */
export function matchRecipe(grid: (number | null)[], width: number): RecipeOutput | null {
  const box = boundingBox(grid, width);
  if (!box) return null;
  for (const recipe of RECIPES) {
    if (recipe.kind === 'shaped') {
      if (matchShaped(recipe, box)) return recipe.out;
    } else if (matchShapeless(recipe, grid)) {
      return recipe.out;
    }
  }
  return null;
}

/** Total recipe count, for tests/tooling. */
export const RECIPE_COUNT = RECIPES.length;
