/**
 * Per-chunk voxel light propagation (runs in the worker before meshing).
 *
 * Produces a light volume: one byte per cell, high nibble = sky light, low
 * nibble = block light, each 0..15. Sky light floods straight down at full
 * strength through transparent cells and spreads horizontally losing 1 level
 * per block; block light floods out from emitters (torches) losing 1 per block.
 * Opaque blocks stop propagation.
 *
 * This is a "basic" per-chunk solve: sky is seeded from the column tops and
 * block light from emitters inside the chunk. Cross-chunk bleed is limited,
 * which keeps each solve independent and cheap.
 */
import { BLOCKS_PER_CHUNK, CHUNK_SIZE_X, CHUNK_SIZE_Y, CHUNK_SIZE_Z } from '../../config/constants';
import { lightEmission, lightOpacity, isOpaque } from '../Block';

const idx = (x: number, y: number, z: number): number => (y << 8) | (z << 4) | x;

/** Returns a Uint8Array(65536): (sky<<4)|block per cell. */
export function computeLight(blocks: Uint8Array): Uint8Array {
  const sky = new Uint8Array(BLOCKS_PER_CHUNK);
  const block = new Uint8Array(BLOCKS_PER_CHUNK);

  // --- Sky light: full daylight straight down until the first opaque block --
  const seeds: number[] = [];
  for (let z = 0; z < CHUNK_SIZE_Z; z++) {
    for (let x = 0; x < CHUNK_SIZE_X; x++) {
      let lit = true;
      for (let y = CHUNK_SIZE_Y - 1; y >= 0; y--) {
        const i = idx(x, y, z);
        if (isOpaque(blocks[i]!)) {
          lit = false;
        }
        if (lit) {
          sky[i] = 15;
          seeds.push(i);
        }
      }
    }
  }
  floodFill(sky, blocks, seeds);

  // --- Block light: flood from emitters ------------------------------------
  const emitters: number[] = [];
  for (let i = 0; i < BLOCKS_PER_CHUNK; i++) {
    const e = lightEmission(blocks[i]!);
    if (e > 0) {
      block[i] = e;
      emitters.push(i);
    }
  }
  floodFill(block, blocks, emitters);

  const light = new Uint8Array(BLOCKS_PER_CHUNK);
  for (let i = 0; i < BLOCKS_PER_CHUNK; i++) {
    light[i] = (sky[i]! << 4) | (block[i]! & 0x0f);
  }
  return light;
}

/**
 * BFS flood-fill: each neighbor gets level-1 (transparent cells cost 1, opaque
 * cells block entirely) if brighter than its current value. `queue` starts with
 * the seed cells (already assigned their levels in `field`).
 */
function floodFill(field: Uint8Array, blocks: Uint8Array, queue: number[]): void {
  let head = 0;
  while (head < queue.length) {
    const i = queue[head++]!;
    const level = field[i]!;
    if (level <= 1) continue;
    const x = i & 0xf;
    const z = (i >> 4) & 0xf;
    const y = i >> 8;
    trySpread(field, blocks, x + 1, y, z, level, queue);
    trySpread(field, blocks, x - 1, y, z, level, queue);
    trySpread(field, blocks, x, y + 1, z, level, queue);
    trySpread(field, blocks, x, y - 1, z, level, queue);
    trySpread(field, blocks, x, y, z + 1, level, queue);
    trySpread(field, blocks, x, y, z - 1, level, queue);
  }
}

function trySpread(
  field: Uint8Array,
  blocks: Uint8Array,
  x: number,
  y: number,
  z: number,
  fromLevel: number,
  queue: number[],
): void {
  if (x < 0 || x >= CHUNK_SIZE_X || y < 0 || y >= CHUNK_SIZE_Y || z < 0 || z >= CHUNK_SIZE_Z) {
    return;
  }
  const i = idx(x, y, z);
  if (isOpaque(blocks[i]!)) return;
  // Transparent (water/leaves) still cost the base 1 per block for this basic
  // model; using lightOpacity here keeps water/leaves slightly dimmer.
  const cost = lightOpacity(blocks[i]!) > 1 ? 2 : 1;
  const next = fromLevel - cost;
  if (next > field[i]!) {
    field[i] = next;
    queue.push(i);
  }
}

export function skyLightAt(light: Uint8Array, i: number): number {
  return (light[i]! >> 4) & 0x0f;
}
export function blockLightAt(light: Uint8Array, i: number): number {
  return light[i]! & 0x0f;
}
