/**
 * World persistence over IndexedDB.
 *
 * Object stores (all keyed within a worldId so multiple worlds coexist):
 *  - worlds:       worldId → metadata (seed, name, timestamps, timeOfDay)
 *  - chunks:       [worldId, cx, cz] → { version, blocks: ArrayBuffer }
 *  - players:      worldId → position, look, health, hunger, inventory
 *  - tileEntities: [worldId, cx, cz, index] → chest/furnace/etc. state
 *
 * Only chunks that differ from procedural output get stored; everything else
 * regenerates from the seed. Chunk block data round-trips as raw ArrayBuffer
 * (structured clone stores it natively — no serialization cost).
 */
import { DB_NAME, DB_VERSION, BLOCKS_PER_CHUNK } from '../config/constants';
import { openDatabase, idbRequest, idbTransactionDone } from './Database';

export interface WorldMeta {
  worldId: string;
  name: string;
  seed: number;
  createdAt: number;
  lastPlayed: number;
  /** 0..1 fraction of the 20-minute day cycle. */
  timeOfDay: number;
}

export interface StoredChunk {
  worldId: string;
  cx: number;
  cz: number;
  /** Format version for forward-compatible migrations (e.g. Uint8 → Uint16). */
  version: number;
  blocks: ArrayBuffer;
}

export interface ItemStackData {
  itemId: number;
  count: number;
  durability?: number;
}

export interface PlayerData {
  worldId: string;
  position: { x: number; y: number; z: number };
  yaw: number;
  pitch: number;
  health: number;
  hunger: number;
  selectedSlot: number;
  inventory: (ItemStackData | null)[];
}

export interface TileEntityData {
  worldId: string;
  cx: number;
  cz: number;
  /** localIndex() of the block within its chunk. */
  index: number;
  kind: 'chest' | 'furnace';
  state: unknown;
}

export const CHUNK_FORMAT_VERSION = 1;

export class WorldStore {
  private constructor(private readonly db: IDBDatabase) {}

  static async open(): Promise<WorldStore> {
    const db = await openDatabase(DB_NAME, DB_VERSION, (d, oldVersion) => {
      if (oldVersion < 1) {
        d.createObjectStore('worlds', { keyPath: 'worldId' });
        d.createObjectStore('chunks', { keyPath: ['worldId', 'cx', 'cz'] });
        d.createObjectStore('players', { keyPath: 'worldId' });
        d.createObjectStore('tileEntities', { keyPath: ['worldId', 'cx', 'cz', 'index'] });
      }
    });
    return new WorldStore(db);
  }

  close(): void {
    this.db.close();
  }

  // -- worlds ---------------------------------------------------------------

  async getWorld(worldId: string): Promise<WorldMeta | undefined> {
    const tx = this.db.transaction('worlds', 'readonly');
    return idbRequest(tx.objectStore('worlds').get(worldId) as IDBRequest<WorldMeta | undefined>);
  }

  async putWorld(meta: WorldMeta): Promise<void> {
    const tx = this.db.transaction('worlds', 'readwrite');
    tx.objectStore('worlds').put(meta);
    await idbTransactionDone(tx);
  }

  async listWorlds(): Promise<WorldMeta[]> {
    const tx = this.db.transaction('worlds', 'readonly');
    return idbRequest(tx.objectStore('worlds').getAll() as IDBRequest<WorldMeta[]>);
  }

  /**
   * Open-or-create in one call — the boot path. Updates lastPlayed on load.
   */
  async openWorld(worldId: string, create: () => Omit<WorldMeta, 'worldId'>): Promise<WorldMeta> {
    const existing = await this.getWorld(worldId);
    const meta: WorldMeta = existing
      ? { ...existing, lastPlayed: Date.now() }
      : { worldId, ...create() };
    await this.putWorld(meta);
    return meta;
  }

  // -- chunks ---------------------------------------------------------------

  async getChunk(worldId: string, cx: number, cz: number): Promise<StoredChunk | undefined> {
    const tx = this.db.transaction('chunks', 'readonly');
    const rec = await idbRequest(
      tx.objectStore('chunks').get([worldId, cx, cz]) as IDBRequest<StoredChunk | undefined>,
    );
    if (rec && rec.blocks.byteLength !== BLOCKS_PER_CHUNK) {
      throw new Error(
        `Corrupt chunk ${cx},${cz}: ${rec.blocks.byteLength} bytes, expected ${BLOCKS_PER_CHUNK}`,
      );
    }
    return rec;
  }

  /** Batch-save dirty chunks in a single transaction (one fsync, not N). */
  async putChunks(chunks: StoredChunk[]): Promise<void> {
    if (chunks.length === 0) return;
    for (const c of chunks) {
      if (c.blocks.byteLength !== BLOCKS_PER_CHUNK) {
        throw new Error(
          `Refusing to save malformed chunk ${c.cx},${c.cz}: ${c.blocks.byteLength} bytes`,
        );
      }
    }
    const tx = this.db.transaction('chunks', 'readwrite');
    const store = tx.objectStore('chunks');
    for (const c of chunks) store.put(c);
    await idbTransactionDone(tx);
  }

  async deleteChunk(worldId: string, cx: number, cz: number): Promise<void> {
    const tx = this.db.transaction('chunks', 'readwrite');
    tx.objectStore('chunks').delete([worldId, cx, cz]);
    await idbTransactionDone(tx);
  }

  // -- player ---------------------------------------------------------------

  async getPlayer(worldId: string): Promise<PlayerData | undefined> {
    const tx = this.db.transaction('players', 'readonly');
    return idbRequest(
      tx.objectStore('players').get(worldId) as IDBRequest<PlayerData | undefined>,
    );
  }

  async putPlayer(data: PlayerData): Promise<void> {
    const tx = this.db.transaction('players', 'readwrite');
    tx.objectStore('players').put(data);
    await idbTransactionDone(tx);
  }

  // -- tile entities ----------------------------------------------------------

  async getTileEntitiesInChunk(
    worldId: string,
    cx: number,
    cz: number,
  ): Promise<TileEntityData[]> {
    const tx = this.db.transaction('tileEntities', 'readonly');
    const range = IDBKeyRange.bound([worldId, cx, cz, 0], [worldId, cx, cz, BLOCKS_PER_CHUNK]);
    return idbRequest(
      tx.objectStore('tileEntities').getAll(range) as IDBRequest<TileEntityData[]>,
    );
  }

  async putTileEntity(data: TileEntityData): Promise<void> {
    const tx = this.db.transaction('tileEntities', 'readwrite');
    tx.objectStore('tileEntities').put(data);
    await idbTransactionDone(tx);
  }

  async deleteTileEntity(worldId: string, cx: number, cz: number, index: number): Promise<void> {
    const tx = this.db.transaction('tileEntities', 'readwrite');
    tx.objectStore('tileEntities').delete([worldId, cx, cz, index]);
    await idbTransactionDone(tx);
  }
}
