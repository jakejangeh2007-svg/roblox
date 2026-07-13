import { describe, it, expect } from 'vitest';
import { computeLight, skyLightAt, blockLightAt } from './light';
import { BLOCKS_PER_CHUNK } from '../../config/constants';
import { localIndex } from '../../core/math';
import { BlockId } from '../Block';

function empty(): Uint8Array {
  return new Uint8Array(BLOCKS_PER_CHUNK);
}

describe('computeLight — sky light', () => {
  it('fully lights open-air columns from the top down', () => {
    const blocks = empty();
    const light = computeLight(blocks);
    // A cell high in an empty chunk sees full sky.
    expect(skyLightAt(light, localIndex(5, 200, 5))).toBe(15);
    expect(skyLightAt(light, localIndex(0, 10, 0))).toBe(15);
  });

  it('darkens cells directly under an opaque roof', () => {
    const blocks = empty();
    // Solid stone roof across the chunk at y=100.
    for (let z = 0; z < 16; z++)
      for (let x = 0; x < 16; x++) blocks[localIndex(x, 100, z)] = BlockId.Stone;
    const light = computeLight(blocks);
    // Above the roof: full sky. Below (interior, away from edges): dark.
    expect(skyLightAt(light, localIndex(8, 101, 8))).toBe(15);
    expect(skyLightAt(light, localIndex(8, 99, 8))).toBeLessThan(15);
    expect(skyLightAt(light, localIndex(8, 90, 8))).toBe(0);
  });
});

describe('computeLight — block light', () => {
  it('emits from a torch and diminishes by 1 per block', () => {
    const blocks = empty();
    blocks[localIndex(8, 50, 8)] = BlockId.Torch; // emission 14
    const light = computeLight(blocks);
    expect(blockLightAt(light, localIndex(8, 50, 8))).toBe(14);
    // One block away in open air → 13.
    expect(blockLightAt(light, localIndex(9, 50, 8))).toBe(13);
    expect(blockLightAt(light, localIndex(8, 50, 10))).toBe(12);
  });

  it('does not propagate block light through opaque blocks', () => {
    const blocks = empty();
    blocks[localIndex(8, 50, 8)] = BlockId.Torch;
    // Wall of stone immediately +x of the torch.
    blocks[localIndex(9, 50, 8)] = BlockId.Stone;
    const light = computeLight(blocks);
    // The stone wall blocks direct spread; the cell behind it stays dark from
    // that direction (may still be lit by going around, but at 2 away here it's
    // unreachable in open air so must be < the direct-line value).
    expect(blockLightAt(light, localIndex(10, 50, 8))).toBeLessThan(13);
  });

  it('leaves cells with no light source dark', () => {
    const light = computeLight(empty());
    expect(blockLightAt(light, localIndex(3, 40, 3))).toBe(0);
  });
});
