/**
 * A chunk column: 16 x 256 x 16 blocks plus a parallel light array.
 *
 * Blocks: one byte each, indexed (y<<8)|(z<<4)|x (y-major).
 * Light:  one byte each — low nibble = block light, high nibble = sky light.
 *
 * The chunk owns only data; meshing and generation live elsewhere so this
 * class can be constructed cheaply on either thread from a transferred buffer.
 */
import { BLOCKS_PER_CHUNK, CHUNK_SIZE_Y } from '../config/constants';
import { localIndex, inChunkBounds } from '../core/math';
import { BlockId } from './Block';

export const enum ChunkState {
  /** Requested from worker, not yet returned. */
  Pending = 0,
  /** Block data present, mesh not yet built. */
  Generated = 1,
  /** Mesh built and in scene. */
  Meshed = 2,
}

export class Chunk {
  readonly blocks: Uint8Array;
  readonly light: Uint8Array;
  state: ChunkState = ChunkState.Pending;
  /** true once the player edits it — controls whether it gets persisted. */
  modified = false;
  /** Highest non-air y per (x,z) column; -1 if empty. Speeds sky-light + gen. */
  readonly heightMap: Int16Array;

  constructor(
    readonly cx: number,
    readonly cz: number,
    blocks?: Uint8Array,
  ) {
    this.blocks = blocks ?? new Uint8Array(BLOCKS_PER_CHUNK);
    this.light = new Uint8Array(BLOCKS_PER_CHUNK);
    this.heightMap = new Int16Array(256).fill(-1);
    if (blocks) this.recomputeHeightMap();
  }

  getBlock(x: number, y: number, z: number): number {
    if (!inChunkBounds(x, y, z)) return BlockId.Air;
    return this.blocks[localIndex(x, y, z)]!;
  }

  setBlock(x: number, y: number, z: number, id: number): void {
    if (!inChunkBounds(x, y, z)) return;
    this.blocks[localIndex(x, y, z)] = id;
    const col = (z << 4) | x;
    const h = this.heightMap[col]!;
    if (id !== BlockId.Air && y > h) {
      this.heightMap[col] = y;
    } else if (id === BlockId.Air && y === h) {
      // Scan down for the new surface.
      let ny = y - 1;
      while (ny >= 0 && this.blocks[localIndex(x, ny, z)] === BlockId.Air) ny--;
      this.heightMap[col] = ny;
    }
  }

  getBlockLight(x: number, y: number, z: number): number {
    if (!inChunkBounds(x, y, z)) return 0;
    return this.light[localIndex(x, y, z)]! & 0x0f;
  }

  getSkyLight(x: number, y: number, z: number): number {
    if (!inChunkBounds(x, y, z)) return 0;
    return (this.light[localIndex(x, y, z)]! >> 4) & 0x0f;
  }

  setBlockLight(x: number, y: number, z: number, level: number): void {
    if (!inChunkBounds(x, y, z)) return;
    const i = localIndex(x, y, z);
    this.light[i] = (this.light[i]! & 0xf0) | (level & 0x0f);
  }

  setSkyLight(x: number, y: number, z: number, level: number): void {
    if (!inChunkBounds(x, y, z)) return;
    const i = localIndex(x, y, z);
    this.light[i] = (this.light[i]! & 0x0f) | ((level & 0x0f) << 4);
  }

  heightAt(x: number, z: number): number {
    return this.heightMap[(z << 4) | x]!;
  }

  recomputeHeightMap(): void {
    for (let z = 0; z < 16; z++) {
      for (let x = 0; x < 16; x++) {
        let y = CHUNK_SIZE_Y - 1;
        while (y >= 0 && this.blocks[localIndex(x, y, z)] === BlockId.Air) y--;
        this.heightMap[(z << 4) | x] = y;
      }
    }
  }
}
