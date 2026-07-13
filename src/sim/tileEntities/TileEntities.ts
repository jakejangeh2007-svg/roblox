/**
 * Tile-entity manager: owns the runtime state of chests and furnaces keyed by
 * world position, ticks furnace smelting in real time, and persists to
 * IndexedDB. State is loaded lazily when a block is opened and saved on change
 * (debounced) and on chunk unload / flush.
 */
import { worldToChunk, worldToLocal, localIndex, chunkDbKey } from '../../core/math';
import { WorldStore, type TileEntityData } from '../../storage/WorldStore';
import type { ItemStack } from '../../player/Inventory';
import { tickFurnace } from './furnaceLogic';

export interface ChestState {
  kind: 'chest';
  slots: (ItemStack | null)[]; // 27
}

export interface FurnaceState {
  kind: 'furnace';
  input: ItemStack | null;
  fuel: ItemStack | null;
  output: ItemStack | null;
  /** Remaining burn time (s) from the currently-burning fuel. */
  burnTime: number;
  /** Total burn time of the current fuel, for the flame gauge. */
  burnTotal: number;
  /** Accumulated cook progress (s) toward COOK_TIME. */
  cookTime: number;
}

export type TileState = ChestState | FurnaceState;

export function newChest(): ChestState {
  return { kind: 'chest', slots: new Array<ItemStack | null>(27).fill(null) };
}
export function newFurnace(): FurnaceState {
  return {
    kind: 'furnace',
    input: null,
    fuel: null,
    output: null,
    burnTime: 0,
    burnTotal: 0,
    cookTime: 0,
  };
}

function keyOf(wx: number, wy: number, wz: number): string {
  const cx = worldToChunk(wx);
  const cz = worldToChunk(wz);
  const index = localIndex(worldToLocal(wx), wy, worldToLocal(wz));
  return `${cx},${cz},${index}`;
}

export class TileEntityManager {
  private readonly states = new Map<string, TileState>();
  private readonly dirty = new Set<string>();
  private saveTimer: ReturnType<typeof setTimeout> | null = null;

  constructor(
    private readonly store: WorldStore,
    private readonly worldId: string,
  ) {}

  /** Get existing state or create+register a new one for the block. */
  async getOrCreate(
    wx: number,
    wy: number,
    wz: number,
    make: () => TileState,
  ): Promise<TileState> {
    const key = keyOf(wx, wy, wz);
    const existing = this.states.get(key);
    if (existing) return existing;

    // Try to load from storage.
    const cx = worldToChunk(wx);
    const cz = worldToChunk(wz);
    const index = localIndex(worldToLocal(wx), wy, worldToLocal(wz));
    const stored = await this.store.getTileEntitiesInChunk(this.worldId, cx, cz);
    const rec = stored.find((t) => t.index === index);
    const state = rec ? (rec.state as TileState) : make();
    this.states.set(key, state);
    return state;
  }

  markDirty(wx: number, wy: number, wz: number): void {
    this.dirty.add(keyOf(wx, wy, wz));
    this.scheduleSave();
  }

  /** Remove a tile entity (block broken); returns its contents to spill. */
  async remove(wx: number, wy: number, wz: number): Promise<TileState | null> {
    const key = keyOf(wx, wy, wz);
    const state = this.states.get(key) ?? null;
    this.states.delete(key);
    this.dirty.delete(key);
    const cx = worldToChunk(wx);
    const cz = worldToChunk(wz);
    const index = localIndex(worldToLocal(wx), wy, worldToLocal(wz));
    await this.store.deleteTileEntity(this.worldId, cx, cz, index);
    return state;
  }

  /** Tick all loaded furnaces. */
  update(dt: number): void {
    for (const [key, state] of this.states) {
      if (state.kind !== 'furnace') continue;
      if (tickFurnace(state, dt)) {
        this.dirty.add(key);
        this.scheduleSave();
      }
    }
  }

  private scheduleSave(): void {
    if (this.saveTimer) return;
    this.saveTimer = setTimeout(() => {
      this.saveTimer = null;
      void this.flush();
    }, 1500);
  }

  async flush(): Promise<void> {
    if (this.dirty.size === 0) return;
    const keys = [...this.dirty];
    this.dirty.clear();
    for (const key of keys) {
      const state = this.states.get(key);
      if (!state) continue;
      const [cx, cz, index] = key.split(',').map(Number) as [number, number, number];
      const data: TileEntityData = {
        worldId: this.worldId,
        cx,
        cz,
        index,
        kind: state.kind,
        state,
      };
      await this.store.putTileEntity(data);
    }
  }

  /** Debug/tooling: how many tile entities are loaded. */
  get loadedCount(): number {
    return this.states.size;
  }

  /** Stable string id for a position (UI change tracking). */
  static keyOf = keyOf;
  static chunkKeyOf = (wx: number, wz: number): string =>
    chunkDbKey(worldToChunk(wx), worldToChunk(wz));
}
