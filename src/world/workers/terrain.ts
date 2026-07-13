/**
 * Procedural terrain generation. Pure and deterministic: given a seed and a
 * chunk coordinate it always produces the same blocks, so pristine chunks are
 * never persisted — they regenerate on demand. This is what makes the world
 * effectively infinite in storage terms.
 *
 * Pipeline per (x,z) column:
 *   1. Biome selection from temperature/moisture noise.
 *   2. Surface height from continentalness + erosion fBm, biome-weighted.
 *   3. Fill: bedrock floor, stone body, biome-specific surface (grass/sand/snow).
 *   4. Carve 3D-noise caves.
 *   5. Sprinkle ore veins by depth band.
 *   6. Decorate: trees, cacti, flowers, tall grass.
 */
import { BLOCKS_PER_CHUNK, CHUNK_SIZE_X, CHUNK_SIZE_Z, SEA_LEVEL } from '../../config/constants';
import { localIndex } from '../../core/math';
import { BlockId } from '../Block';
import { SimplexNoise } from './noise';

export const enum Biome {
  Plains = 0,
  Desert = 1,
  Forest = 2,
  Hills = 3,
  SnowyMountains = 4,
}

/** Deterministic per-column hash → [0,1), used for feature placement. */
function hash2(x: number, z: number, salt: number): number {
  let h = (x * 374761393 + z * 668265263 + salt * 2246822519) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
}

export class TerrainGenerator {
  private readonly height: SimplexNoise;
  private readonly erosion: SimplexNoise;
  private readonly temperature: SimplexNoise;
  private readonly moisture: SimplexNoise;
  private readonly caves: SimplexNoise;
  private readonly caves2: SimplexNoise;
  private readonly ore: SimplexNoise;

  constructor(readonly seed: number) {
    // Decorrelate the fields by offsetting the seed per noise instance.
    this.height = new SimplexNoise(seed);
    this.erosion = new SimplexNoise(seed ^ 0x9e3779b9);
    this.temperature = new SimplexNoise(seed ^ 0x1b56c4e9);
    this.moisture = new SimplexNoise(seed ^ 0x7f4a7c15);
    this.caves = new SimplexNoise(seed ^ 0x2545f491);
    this.caves2 = new SimplexNoise(seed ^ 0x94d049bb);
    this.ore = new SimplexNoise(seed ^ 0xd1b54a32);
  }

  biomeAt(wx: number, wz: number): Biome {
    const temp = this.temperature.fbm2D(wx * 0.0016, wz * 0.0016, 3);
    const moist = this.moisture.fbm2D(wx * 0.0021, wz * 0.0021, 3);
    const cont = this.height.fbm2D(wx * 0.0009, wz * 0.0009, 2);
    if (cont > 0.55) return Biome.SnowyMountains;
    if (temp > 0.35 && moist < -0.1) return Biome.Desert;
    if (cont > 0.25) return Biome.Hills;
    if (moist > 0.2) return Biome.Forest;
    return Biome.Plains;
  }

  /** Surface height (top solid Y) at a world column. */
  heightAt(wx: number, wz: number): number {
    const cont = this.height.fbm2D(wx * 0.0009, wz * 0.0009, 3); // large landmasses
    const ero = this.erosion.fbm2D(wx * 0.006, wz * 0.006, 4); // local ruggedness
    const detail = this.height.fbm2D(wx * 0.03, wz * 0.03, 2);

    // Base rolling terrain around sea level.
    let h = SEA_LEVEL + cont * 26 + ero * 10 + detail * 3;

    // Mountains: push continentalness peaks up sharply.
    if (cont > 0.4) {
      const m = (cont - 0.4) / 0.6;
      h += m * m * 55;
    }
    return Math.max(1, Math.min(250, Math.round(h)));
  }

  private surfaceBlocks(biome: Biome, surface: number): {
    top: BlockId;
    filler: BlockId;
    fillerDepth: number;
  } {
    switch (biome) {
      case Biome.Desert:
        return { top: BlockId.Sand, filler: BlockId.Sand, fillerDepth: 4 };
      case Biome.SnowyMountains:
        return surface > SEA_LEVEL + 40
          ? { top: BlockId.Snow, filler: BlockId.Stone, fillerDepth: 2 }
          : { top: BlockId.Grass, filler: BlockId.Dirt, fillerDepth: 3 };
      default:
        return { top: BlockId.Grass, filler: BlockId.Dirt, fillerDepth: 3 };
    }
  }

  /** Generate a full chunk column into a fresh Uint8Array. */
  generateChunk(cx: number, cz: number): Uint8Array {
    const blocks = new Uint8Array(BLOCKS_PER_CHUNK);
    const baseX = cx * CHUNK_SIZE_X;
    const baseZ = cz * CHUNK_SIZE_Z;

    // Track surface height + biome per column for the decoration pass.
    const surfaceH = new Int16Array(256);
    const biomes = new Uint8Array(256);

    for (let lz = 0; lz < CHUNK_SIZE_Z; lz++) {
      for (let lx = 0; lx < CHUNK_SIZE_X; lx++) {
        const wx = baseX + lx;
        const wz = baseZ + lz;
        const biome = this.biomeAt(wx, wz);
        const surface = this.heightAt(wx, wz);
        surfaceH[(lz << 4) | lx] = surface;
        biomes[(lz << 4) | lx] = biome;

        const { top, filler, fillerDepth } = this.surfaceBlocks(biome, surface);

        for (let y = 0; y <= surface; y++) {
          let id: BlockId;
          if (y === 0) {
            id = BlockId.Bedrock;
          } else if (y <= 2 && hash2(wx, wz, y * 131) < 0.5) {
            id = BlockId.Bedrock; // rough bedrock layer 0-2
          } else if (y === surface) {
            id = surface < SEA_LEVEL - 1 && biome !== Biome.Desert ? BlockId.Dirt : top;
          } else if (y > surface - fillerDepth) {
            id = filler;
          } else {
            id = BlockId.Stone;
          }

          // Carve caves (not into bedrock band).
          if (id !== BlockId.Bedrock && y > 4 && this.isCave(wx, y, wz)) {
            continue; // leave air
          }

          if (id === BlockId.Stone) {
            id = this.oreAt(wx, y, wz);
          }

          blocks[localIndex(lx, y, wz - baseZ)] = id;
        }

        // Water fill up to sea level in carved/low columns.
        for (let y = surface + 1; y <= SEA_LEVEL; y++) {
          if (blocks[localIndex(lx, y, lz)] === BlockId.Air) {
            blocks[localIndex(lx, y, lz)] = BlockId.Water;
          }
        }
      }
    }

    this.decorate(blocks, cx, cz, surfaceH, biomes);
    return blocks;
  }

  private isCave(wx: number, wy: number, wz: number): boolean {
    // Two ridged noise fields intersected → tunnel-like caves (Perlin worms
    // approximation). Narrow the caves near the surface so they don't shred it.
    const scale = 0.045;
    const a = this.caves.noise3D(wx * scale, wy * scale * 1.6, wz * scale);
    const b = this.caves2.noise3D(wx * scale, wy * scale * 1.6, wz * scale);
    const threshold = 0.16 + Math.max(0, (60 - wy) * 0.0008);
    return a * a + b * b < threshold * 0.5;
  }

  /** Ore selection with historically accurate elevation bands. */
  private oreAt(wx: number, wy: number, wz: number): BlockId {
    // Vein noise: only cluster where the field is high, giving contiguous veins.
    const vein = this.ore.noise3D(wx * 0.09, wy * 0.09, wz * 0.09);
    if (vein < 0.72) return BlockId.Stone;
    const r = hash2(wx * 7 + wy, wz * 13 + wy, 99);

    if (wy <= 16 && r < 0.06) return BlockId.DiamondOre; // Y 5-16
    if (wy <= 32 && r < 0.12) return BlockId.GoldOre; // Y 5-32
    if (wy <= 64 && r < 0.42) return BlockId.IronOre; // Y 5-64
    if (wy <= 128 && r < 0.85) return BlockId.CoalOre; // Y up to 128
    return BlockId.Stone;
  }

  private decorate(
    blocks: Uint8Array,
    cx: number,
    cz: number,
    surfaceH: Int16Array,
    biomes: Uint8Array,
  ): void {
    const baseX = cx * CHUNK_SIZE_X;
    const baseZ = cz * CHUNK_SIZE_Z;

    for (let lz = 0; lz < CHUNK_SIZE_Z; lz++) {
      for (let lx = 0; lx < CHUNK_SIZE_X; lx++) {
        const col = (lz << 4) | lx;
        const surface = surfaceH[col]!;
        const biome = biomes[col] as Biome;
        const wx = baseX + lx;
        const wz = baseZ + lz;

        // Only decorate columns whose surface is land above water.
        if (surface < SEA_LEVEL) continue;
        const surfBlock = blocks[localIndex(lx, surface, lz)];
        if (surfBlock !== BlockId.Grass && surfBlock !== BlockId.Sand && surfBlock !== BlockId.Snow) {
          continue;
        }

        const feat = hash2(wx, wz, 7);

        if (biome === Biome.Desert) {
          // Cacti: only interior columns so the 1-wide column fits without
          // reaching a neighbor chunk mid-generation.
          if (feat < 0.02 && lx > 0 && lx < 15 && lz > 0 && lz < 15) {
            const h = 2 + Math.floor(hash2(wx, wz, 11) * 3);
            for (let i = 1; i <= h; i++) {
              blocks[localIndex(lx, surface + i, lz)] = BlockId.Cactus;
            }
          }
          continue;
        }

        if (biome === Biome.Forest && feat < 0.06) {
          this.placeTree(blocks, lx, surface, lz, wx, wz, hash2(wx, wz, 3) < 0.35);
        } else if ((biome === Biome.Plains || biome === Biome.Hills) && feat < 0.012) {
          this.placeTree(blocks, lx, surface, lz, wx, wz, false);
        } else if (biome !== Biome.SnowyMountains) {
          // Ground cover.
          if (feat > 0.6 && feat < 0.78) {
            blocks[localIndex(lx, surface + 1, lz)] = BlockId.TallGrass;
          } else if (feat >= 0.78 && feat < 0.8) {
            blocks[localIndex(lx, surface + 1, lz)] = BlockId.Flower;
          }
        }
      }
    }
  }

  /**
   * Place a small tree. Only writes leaves/logs that fall inside this chunk;
   * canopy that would cross a chunk border is clipped (acceptable for Step 2 —
   * cross-chunk structure carryover is a later refinement).
   */
  private placeTree(
    blocks: Uint8Array,
    lx: number,
    surface: number,
    lz: number,
    wx: number,
    wz: number,
    birch: boolean,
  ): void {
    const trunk = 4 + Math.floor(hash2(wx, wz, 5) * 3);
    const log = birch ? BlockId.BirchLog : BlockId.OakLog;
    const leaf = birch ? BlockId.BirchLeaves : BlockId.OakLeaves;
    const top = surface + trunk;

    // Canopy: 5x5 at the two layers below top, plus a 3x3 cap.
    for (let dy = -2; dy <= 1; dy++) {
      const y = top + dy;
      const r = dy >= 0 ? 1 : 2;
      for (let dz = -r; dz <= r; dz++) {
        for (let dx = -r; dx <= r; dx++) {
          if (dy === 1 && Math.abs(dx) + Math.abs(dz) > 1) continue; // rounded cap
          const x = lx + dx;
          const z = lz + dz;
          if (x < 0 || x > 15 || z < 0 || z > 15 || y < 0 || y > 255) continue;
          const idx = localIndex(x, y, z);
          if (blocks[idx] === BlockId.Air) blocks[idx] = leaf;
        }
      }
    }
    // Trunk (overwrites leaves at the core).
    for (let i = 1; i <= trunk; i++) {
      const y = surface + i;
      if (y <= 255) blocks[localIndex(lx, y, lz)] = log;
    }
  }
}
