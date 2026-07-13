import 'fake-indexeddb/auto';
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { WorldStore, CHUNK_FORMAT_VERSION, type StoredChunk } from './WorldStore';
import { deleteDatabase } from './Database';
import { BLOCKS_PER_CHUNK, DB_NAME } from '../config/constants';

let store: WorldStore;

beforeEach(async () => {
  store = await WorldStore.open();
});

afterEach(async () => {
  store.close();
  await deleteDatabase(DB_NAME);
});

function makeChunk(cx: number, cz: number, fill = 0): StoredChunk {
  const blocks = new Uint8Array(BLOCKS_PER_CHUNK).fill(fill);
  return { worldId: 'w1', cx, cz, version: CHUNK_FORMAT_VERSION, blocks: blocks.buffer };
}

describe('worlds', () => {
  it('creates a world on first open and resumes it afterwards', async () => {
    const created = await store.openWorld('w1', () => ({
      name: 'Test',
      seed: 12345,
      createdAt: 1000,
      lastPlayed: 1000,
      timeOfDay: 0.25,
    }));
    expect(created.seed).toBe(12345);

    const resumed = await store.openWorld('w1', () => {
      throw new Error('create() must not run for an existing world');
    });
    expect(resumed.seed).toBe(12345);
    expect(resumed.name).toBe('Test');
    expect(resumed.lastPlayed).toBeGreaterThanOrEqual(created.lastPlayed);
  });

  it('lists worlds', async () => {
    await store.putWorld({
      worldId: 'a', name: 'A', seed: 1, createdAt: 1, lastPlayed: 1, timeOfDay: 0,
    });
    await store.putWorld({
      worldId: 'b', name: 'B', seed: 2, createdAt: 2, lastPlayed: 2, timeOfDay: 0,
    });
    const worlds = await store.listWorlds();
    expect(worlds.map((w) => w.worldId).sort()).toEqual(['a', 'b']);
  });
});

describe('chunks', () => {
  it('round-trips block data exactly', async () => {
    const chunk = makeChunk(3, -7);
    new Uint8Array(chunk.blocks)[42] = 99;
    await store.putChunks([chunk]);

    const loaded = await store.getChunk('w1', 3, -7);
    expect(loaded).toBeDefined();
    expect(loaded!.version).toBe(CHUNK_FORMAT_VERSION);
    const bytes = new Uint8Array(loaded!.blocks);
    expect(bytes.length).toBe(BLOCKS_PER_CHUNK);
    expect(bytes[42]).toBe(99);
    expect(bytes[43]).toBe(0);
  });

  it('returns undefined for pristine (never-saved) chunks', async () => {
    expect(await store.getChunk('w1', 100, 100)).toBeUndefined();
  });

  it('batch-saves multiple chunks in one transaction', async () => {
    await store.putChunks([makeChunk(0, 0, 1), makeChunk(0, 1, 2), makeChunk(-1, 0, 3)]);
    expect(new Uint8Array((await store.getChunk('w1', 0, 0))!.blocks)[0]).toBe(1);
    expect(new Uint8Array((await store.getChunk('w1', 0, 1))!.blocks)[0]).toBe(2);
    expect(new Uint8Array((await store.getChunk('w1', -1, 0))!.blocks)[0]).toBe(3);
  });

  it('keeps chunks from different worlds separate', async () => {
    await store.putChunks([makeChunk(0, 0, 7)]);
    expect(await store.getChunk('other-world', 0, 0)).toBeUndefined();
  });

  it('rejects malformed chunk buffers on save', async () => {
    const bad: StoredChunk = {
      worldId: 'w1', cx: 0, cz: 0, version: 1, blocks: new ArrayBuffer(10),
    };
    await expect(store.putChunks([bad])).rejects.toThrow(/malformed/);
  });

  it('deletes chunks', async () => {
    await store.putChunks([makeChunk(5, 5)]);
    await store.deleteChunk('w1', 5, 5);
    expect(await store.getChunk('w1', 5, 5)).toBeUndefined();
  });
});

describe('players', () => {
  it('round-trips player state including inventory nulls', async () => {
    await store.putPlayer({
      worldId: 'w1',
      position: { x: 1.5, y: 70, z: -3.25 },
      yaw: 1.2,
      pitch: -0.3,
      health: 17,
      hunger: 14,
      selectedSlot: 2,
      inventory: [{ itemId: 5, count: 12 }, null, { itemId: 9, count: 1, durability: 55 }],
    });
    const p = await store.getPlayer('w1');
    expect(p).toBeDefined();
    expect(p!.position).toEqual({ x: 1.5, y: 70, z: -3.25 });
    expect(p!.inventory[1]).toBeNull();
    expect(p!.inventory[2]).toEqual({ itemId: 9, count: 1, durability: 55 });
  });
});

describe('tile entities', () => {
  it('stores and queries per-chunk tile entities', async () => {
    await store.putTileEntity({
      worldId: 'w1', cx: 0, cz: 0, index: 100, kind: 'chest', state: { slots: [] },
    });
    await store.putTileEntity({
      worldId: 'w1', cx: 0, cz: 0, index: 200, kind: 'furnace', state: { fuel: 3 },
    });
    await store.putTileEntity({
      worldId: 'w1', cx: 1, cz: 0, index: 100, kind: 'chest', state: {},
    });

    const inChunk = await store.getTileEntitiesInChunk('w1', 0, 0);
    expect(inChunk).toHaveLength(2);
    expect(inChunk.map((t) => t.kind).sort()).toEqual(['chest', 'furnace']);

    await store.deleteTileEntity('w1', 0, 0, 100);
    expect(await store.getTileEntitiesInChunk('w1', 0, 0)).toHaveLength(1);
  });
});
