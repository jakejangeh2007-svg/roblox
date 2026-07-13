/**
 * Holds the contents of a crafting grid (2×2 or 3×3) and derives the current
 * output. Crafting consumes one item from each occupied input slot, matching
 * Minecraft. The grid is a plain array of ItemStacks so the UI can bind slots
 * directly.
 */
import { matchRecipe, type RecipeOutput } from '../items/recipes';
import type { ItemStack } from './Inventory';

export class CraftingGrid {
  readonly slots: (ItemStack | null)[];

  constructor(readonly width: number) {
    this.slots = new Array<ItemStack | null>(width * width).fill(null);
  }

  /** The recipe output for the current contents, or null. */
  getOutput(): RecipeOutput | null {
    const ids = this.slots.map((s) => (s ? s.item : null));
    return matchRecipe(ids, this.width);
  }

  /** Consume one of each input (called once per crafted output). */
  consumeInputs(): void {
    for (let i = 0; i < this.slots.length; i++) {
      const s = this.slots[i];
      if (s) {
        s.count -= 1;
        if (s.count <= 0) this.slots[i] = null;
      }
    }
  }

  /** Whether any slot holds an item. */
  isEmpty(): boolean {
    return this.slots.every((s) => s == null);
  }

  clear(): (ItemStack | null)[] {
    const contents = this.slots.slice();
    this.slots.fill(null);
    return contents;
  }
}
