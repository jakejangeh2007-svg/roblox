/**
 * Procedural texture atlas. Draws a 16x16 grid of 16px block tiles onto a
 * canvas so the game ships with recognizable textures and zero external image
 * assets (keeps the bundle self-contained and instantly loadable on mobile).
 *
 * Tile indices match the T map in Block.ts. NearestFilter keeps the crisp
 * pixel-art look; mipmaps are generated for minification but LOD is clamped in
 * the material to prevent cross-tile bleed at distance.
 */
import * as THREE from 'three';

const TILE = 16;
const COLS = 16;
// The atlas MUST be a full 16x16-tile grid (256x256) because the mesher's UV
// math divides both axes by 16. A shorter canvas would make tiles sample
// undrawn regions. Only the first ~3 rows are used today; the rest is spare.
const ROWS = 16;
const SIZE = TILE * COLS;

type RGB = [number, number, number];

/** Deterministic per-pixel jitter for a speckled, non-flat look. */
function noise(x: number, y: number, salt: number): number {
  let h = (x * 374761393 + y * 668265263 + salt * 2246822519) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
}

function shade([r, g, b]: RGB, f: number): string {
  return `rgb(${Math.min(255, r * f) | 0},${Math.min(255, g * f) | 0},${Math.min(255, b * f) | 0})`;
}

/** Fill a tile with a speckled base color. */
function speckle(ctx: CanvasRenderingContext2D, tile: number, base: RGB, amp: number, salt: number): void {
  const col = tile % COLS;
  const row = Math.floor(tile / COLS);
  const px = col * TILE;
  const py = row * TILE;
  for (let y = 0; y < TILE; y++) {
    for (let x = 0; x < TILE; x++) {
      const n = 1 + (noise(x, y, salt) - 0.5) * amp;
      ctx.fillStyle = shade(base, n);
      ctx.fillRect(px + x, py + y, 1, 1);
    }
  }
}

function overlaySpecks(
  ctx: CanvasRenderingContext2D,
  tile: number,
  color: RGB,
  count: number,
  salt: number,
): void {
  const col = tile % COLS;
  const row = Math.floor(tile / COLS);
  const px = col * TILE;
  const py = row * TILE;
  for (let i = 0; i < count; i++) {
    const x = Math.floor(noise(i, tile, salt) * TILE);
    const y = Math.floor(noise(i, tile, salt + 7) * TILE);
    ctx.fillStyle = shade(color, 1);
    ctx.fillRect(px + x, py + y, 2, 2);
  }
}

// Tile indices (mirror of T in Block.ts).
const T = {
  stone: 0, dirt: 1, grassTop: 2, grassSide: 3, cobble: 4, bedrock: 5, sand: 6,
  gravel: 7, logTop: 8, logSide: 9, leaves: 10, birchTop: 11, birchSide: 12,
  birchLeaves: 13, coal: 14, iron: 15, gold: 16, diamond: 17, water: 18,
  cactusTop: 19, cactusSide: 20, planks: 21, glass: 22, craftTop: 23,
  craftSide: 24, furnaceFront: 25, furnaceSide: 26, furnaceTop: 27, chest: 28,
  torch: 29, flower: 30, tallgrass: 31, snow: 32,
};

let cached: THREE.Texture | null = null;

export function buildAtlasTexture(): THREE.Texture {
  if (cached) return cached;
  const canvas = document.createElement('canvas');
  canvas.width = SIZE;
  canvas.height = TILE * ROWS; // 256x256
  const ctx = canvas.getContext('2d')!;
  ctx.clearRect(0, 0, canvas.width, canvas.height);

  speckle(ctx, T.stone, [128, 128, 128], 0.25, 1);
  speckle(ctx, T.dirt, [134, 96, 67], 0.3, 2);
  speckle(ctx, T.grassTop, [95, 159, 53], 0.3, 3);
  speckle(ctx, T.grassSide, [134, 96, 67], 0.3, 4);
  // grass fringe on top of the side tile
  {
    const px = (T.grassSide % COLS) * TILE;
    const py = Math.floor(T.grassSide / COLS) * TILE;
    for (let x = 0; x < TILE; x++) {
      const h = 3 + Math.floor(noise(x, 0, 9) * 3);
      for (let y = 0; y < h; y++) {
        ctx.fillStyle = shade([95, 159, 53], 1 + (noise(x, y, 5) - 0.5) * 0.3);
        ctx.fillRect(px + x, py + y, 1, 1);
      }
    }
  }
  speckle(ctx, T.cobble, [110, 110, 110], 0.5, 6);
  speckle(ctx, T.bedrock, [60, 60, 62], 0.6, 7);
  speckle(ctx, T.sand, [219, 208, 158], 0.18, 8);
  speckle(ctx, T.gravel, [130, 122, 120], 0.5, 9);
  speckle(ctx, T.logTop, [160, 130, 82], 0.2, 10);
  overlaySpecks(ctx, T.logTop, [120, 92, 55], 6, 11);
  speckle(ctx, T.logSide, [102, 78, 48], 0.25, 12);
  speckle(ctx, T.leaves, [58, 122, 40], 0.4, 13);
  speckle(ctx, T.birchTop, [200, 190, 170], 0.15, 14);
  speckle(ctx, T.birchSide, [215, 210, 200], 0.12, 15);
  overlaySpecks(ctx, T.birchSide, [60, 60, 60], 4, 16);
  speckle(ctx, T.birchLeaves, [95, 145, 70], 0.4, 17);
  speckle(ctx, T.coal, [128, 128, 128], 0.25, 1);
  overlaySpecks(ctx, T.coal, [30, 30, 30], 10, 18);
  speckle(ctx, T.iron, [128, 128, 128], 0.25, 1);
  overlaySpecks(ctx, T.iron, [200, 160, 120], 9, 19);
  speckle(ctx, T.gold, [128, 128, 128], 0.25, 1);
  overlaySpecks(ctx, T.gold, [240, 210, 70], 9, 20);
  speckle(ctx, T.diamond, [128, 128, 128], 0.25, 1);
  overlaySpecks(ctx, T.diamond, [110, 230, 230], 9, 21);
  speckle(ctx, T.water, [50, 90, 200], 0.15, 22);
  speckle(ctx, T.cactusTop, [80, 140, 60], 0.2, 23);
  speckle(ctx, T.cactusSide, [70, 130, 55], 0.25, 24);
  speckle(ctx, T.planks, [163, 130, 79], 0.15, 25);
  overlaySpecks(ctx, T.planks, [120, 92, 55], 5, 26);
  // glass: mostly transparent with a border
  {
    const px = (T.glass % COLS) * TILE;
    const py = Math.floor(T.glass / COLS) * TILE;
    ctx.clearRect(px, py, TILE, TILE);
    ctx.strokeStyle = 'rgba(210,230,240,0.9)';
    ctx.strokeRect(px + 0.5, py + 0.5, TILE - 1, TILE - 1);
  }
  speckle(ctx, T.craftTop, [140, 100, 60], 0.2, 27);
  overlaySpecks(ctx, T.craftTop, [90, 60, 35], 8, 28);
  speckle(ctx, T.craftSide, [150, 110, 66], 0.2, 29);
  speckle(ctx, T.furnaceSide, [96, 96, 100], 0.3, 30);
  speckle(ctx, T.furnaceTop, [110, 110, 114], 0.25, 31);
  speckle(ctx, T.furnaceFront, [96, 96, 100], 0.3, 30);
  {
    const px = (T.furnaceFront % COLS) * TILE;
    const py = Math.floor(T.furnaceFront / COLS) * TILE;
    ctx.fillStyle = '#222';
    ctx.fillRect(px + 4, py + 8, 8, 6);
    ctx.fillStyle = '#e8b04a';
    ctx.fillRect(px + 6, py + 11, 4, 3);
  }
  speckle(ctx, T.chest, [150, 110, 60], 0.18, 32);
  {
    const px = (T.chest % COLS) * TILE;
    const py = Math.floor(T.chest / COLS) * TILE;
    ctx.fillStyle = '#3a2a15';
    ctx.fillRect(px + 1, py + 7, TILE - 2, 1);
    ctx.fillStyle = '#d9c07a';
    ctx.fillRect(px + 7, py + 6, 2, 4);
  }
  // torch: transparent with a stick + flame
  {
    const px = (T.torch % COLS) * TILE;
    const py = Math.floor(T.torch / COLS) * TILE;
    ctx.clearRect(px, py, TILE, TILE);
    ctx.fillStyle = '#6b4a25';
    ctx.fillRect(px + 7, py + 6, 2, 9);
    ctx.fillStyle = '#ffd257';
    ctx.fillRect(px + 6, py + 3, 4, 4);
  }
  // flower: transparent with a stem + red bloom
  {
    const px = (T.flower % COLS) * TILE;
    const py = Math.floor(T.flower / COLS) * TILE;
    ctx.clearRect(px, py, TILE, TILE);
    ctx.fillStyle = '#2f8a2f';
    ctx.fillRect(px + 7, py + 8, 2, 6);
    ctx.fillStyle = '#e04040';
    ctx.fillRect(px + 5, py + 4, 6, 4);
    ctx.fillStyle = '#ffd257';
    ctx.fillRect(px + 7, py + 5, 2, 2);
  }
  // tall grass: transparent with green blades
  {
    const px = (T.tallgrass % COLS) * TILE;
    const py = Math.floor(T.tallgrass / COLS) * TILE;
    ctx.clearRect(px, py, TILE, TILE);
    for (let x = 2; x < TILE - 1; x += 2) {
      const h = 6 + Math.floor(noise(x, 0, 40) * 6);
      ctx.fillStyle = shade([70, 140, 55], 1 + (noise(x, 1, 41) - 0.5) * 0.3);
      ctx.fillRect(px + x, py + (TILE - h), 1, h);
    }
  }
  speckle(ctx, T.snow, [236, 240, 244], 0.08, 42);

  const tex = new THREE.CanvasTexture(canvas);
  tex.magFilter = THREE.NearestFilter;
  tex.minFilter = THREE.NearestMipmapLinearFilter;
  tex.generateMipmaps = true;
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.anisotropy = 1;
  // The mesher indexes tiles from the canvas top-left (row = floor(tile/16)).
  // Three flips V by default, which would invert that mapping and sample the
  // wrong (undrawn) rows — so disable the flip to keep canvas Y aligned with V.
  tex.flipY = false;
  cached = tex;
  return tex;
}

/** Returns [u0,v0,u1,v1] for a tile index — used by 3D item drops (Step 5). */
export function tileUV(tile: number): [number, number, number, number] {
  const col = tile % COLS;
  const row = Math.floor(tile / COLS);
  return [col / COLS, row / COLS, (col + 1) / COLS, (row + 1) / COLS];
}
