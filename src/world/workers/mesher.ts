/**
 * Culled voxel mesher. Emits one interleaved vertex stream for opaque geometry
 * and one for transparent (water/glass/leaves), plus cross-plane sprites for
 * flowers/torches. Hidden faces (touching an opaque neighbor) are skipped, so a
 * solid chunk interior costs zero triangles.
 *
 * Ambient occlusion is baked per-vertex from the 3 neighbors around each corner
 * (the standard "0 4 3 1" voxel AO), giving free contact shadows. Sky/block
 * light is baked per-face into the same color channel so no runtime light
 * uniform is needed for the base look (dynamic light comes in Step 6).
 *
 * Output arrays are plain typed arrays so they transfer to the main thread
 * with zero copy.
 */
import { CHUNK_SIZE_X, CHUNK_SIZE_Y, CHUNK_SIZE_Z } from '../../config/constants';
import { BLOCKS, RenderKind, BlockId } from '../Block';

const ATLAS_COLS = 16;
const TILE_INSET = 0.0005; // shrink UVs to avoid neighbor-tile bleed

/**
 * Reads a block at chunk-local coords that may extend one block outside the
 * [0,16) range into neighbors. `neighbors` is a 3x3 grid of block arrays keyed
 * (dz+1)*3+(dx+1); the center (index 4) is the chunk being meshed.
 */
export interface NeighborGrid {
  /** 9 entries; each is a chunk's block Uint8Array or null (ungenerated). */
  blocks: (Uint8Array | null)[];
}

function sample(grid: NeighborGrid, x: number, y: number, z: number): number {
  if (y < 0 || y >= CHUNK_SIZE_Y) return BlockId.Air;
  let dx = 0;
  let dz = 0;
  let lx = x;
  let lz = z;
  if (x < 0) {
    dx = -1;
    lx = x + CHUNK_SIZE_X;
  } else if (x >= CHUNK_SIZE_X) {
    dx = 1;
    lx = x - CHUNK_SIZE_X;
  }
  if (z < 0) {
    dz = -1;
    lz = z + CHUNK_SIZE_Z;
  } else if (z >= CHUNK_SIZE_Z) {
    dz = 1;
    lz = z - CHUNK_SIZE_Z;
  }
  const arr = grid.blocks[(dz + 1) * 3 + (dx + 1)];
  if (!arr) return BlockId.Air;
  return arr[(y << 8) | (lz << 4) | lx]!;
}

// Face definitions: for each of the 6 faces, the neighbor offset (to test
// visibility) and the 4 corner vertex offsets in CCW winding, plus the two
// tangent axes used to look up AO neighbors.
interface FaceDef {
  dir: [number, number, number];
  // 4 corners: each [x,y,z]
  corners: [number, number, number][];
  tile: number; // index into BlockDef.tiles
  normal: [number, number, number];
}

const FACES: FaceDef[] = [
  {
    // +Y top
    dir: [0, 1, 0],
    corners: [[0, 1, 0], [0, 1, 1], [1, 1, 1], [1, 1, 0]],
    tile: 0,
    normal: [0, 1, 0],
  },
  {
    // -Y bottom
    dir: [0, -1, 0],
    corners: [[0, 0, 1], [0, 0, 0], [1, 0, 0], [1, 0, 1]],
    tile: 1,
    normal: [0, -1, 0],
  },
  {
    // -Z north
    dir: [0, 0, -1],
    corners: [[1, 0, 0], [0, 0, 0], [0, 1, 0], [1, 1, 0]],
    tile: 2,
    normal: [0, 0, -1],
  },
  {
    // +Z south
    dir: [0, 0, 1],
    corners: [[0, 0, 1], [1, 0, 1], [1, 1, 1], [0, 1, 1]],
    tile: 3,
    normal: [0, 0, 1],
  },
  {
    // +X east
    dir: [1, 0, 0],
    corners: [[1, 0, 1], [1, 0, 0], [1, 1, 0], [1, 1, 1]],
    tile: 4,
    normal: [1, 0, 0],
  },
  {
    // -X west
    dir: [-1, 0, 0],
    corners: [[0, 0, 0], [0, 0, 1], [0, 1, 1], [0, 1, 0]],
    tile: 5,
    normal: [-1, 0, 0],
  },
];

/** Face brightness by normal — cheap directional shading (Minecraft-style). */
const FACE_SHADE = [1.0, 0.5, 0.8, 0.8, 0.6, 0.6];

export interface MeshBuffers {
  positions: Float32Array;
  normals: Float32Array;
  uvs: Float32Array;
  /** Per-vertex baked light/AO as a single grayscale factor in [0,1]. */
  shade: Float32Array;
  indices: Uint32Array;
}

export interface MeshResult {
  opaque: MeshBuffers | null;
  transparent: MeshBuffers | null;
}

class MeshBuilder {
  positions: number[] = [];
  normals: number[] = [];
  uvs: number[] = [];
  shade: number[] = [];
  indices: number[] = [];
  private vcount = 0;

  addQuad(
    corners: [number, number, number][],
    ox: number,
    oy: number,
    oz: number,
    normal: [number, number, number],
    tile: number,
    light: [number, number, number, number],
    flip: boolean,
  ): void {
    const col = tile % ATLAS_COLS;
    const row = Math.floor(tile / ATLAS_COLS);
    const u0 = col / ATLAS_COLS + TILE_INSET;
    const v0 = row / ATLAS_COLS + TILE_INSET;
    const u1 = (col + 1) / ATLAS_COLS - TILE_INSET;
    const v1 = (row + 1) / ATLAS_COLS - TILE_INSET;
    // UV per corner (matches CCW corner ordering used in FACES).
    const cuv: [number, number][] = [
      [u0, v1],
      [u1, v1],
      [u1, v0],
      [u0, v0],
    ];

    const base = this.vcount;
    for (let i = 0; i < 4; i++) {
      const c = corners[i]!;
      this.positions.push(ox + c[0], oy + c[1], oz + c[2]);
      this.normals.push(normal[0], normal[1], normal[2]);
      this.uvs.push(cuv[i]![0], cuv[i]![1]);
      this.shade.push(light[i]!);
    }
    this.vcount += 4;
    // Flip the quad's triangulation toward the darker diagonal to avoid AO
    // artifacts (standard voxel-AO fix).
    if (flip) {
      this.indices.push(base, base + 1, base + 2, base, base + 2, base + 3);
    } else {
      this.indices.push(base + 1, base + 2, base + 3, base + 1, base + 3, base);
    }
  }

  build(): MeshBuffers | null {
    if (this.indices.length === 0) return null;
    return {
      positions: new Float32Array(this.positions),
      normals: new Float32Array(this.normals),
      uvs: new Float32Array(this.uvs),
      shade: new Float32Array(this.shade),
      indices: new Uint32Array(this.indices),
    };
  }
}

/** AO factor (0..3) for a vertex given the two side neighbors and the corner. */
function vertexAO(side1: boolean, side2: boolean, corner: boolean): number {
  if (side1 && side2) return 0;
  return 3 - ((side1 ? 1 : 0) + (side2 ? 1 : 0) + (corner ? 1 : 0));
}

function occludes(grid: NeighborGrid, x: number, y: number, z: number): boolean {
  return BLOCKS[sample(grid, x, y, z)]?.opaque ?? false;
}

export function meshChunk(grid: NeighborGrid): MeshResult {
  const opaque = new MeshBuilder();
  const transparent = new MeshBuilder();

  for (let y = 0; y < CHUNK_SIZE_Y; y++) {
    for (let z = 0; z < CHUNK_SIZE_Z; z++) {
      for (let x = 0; x < CHUNK_SIZE_X; x++) {
        const id = sample(grid, x, y, z);
        if (id === BlockId.Air) continue;
        const def = BLOCKS[id]!;

        if (def.render === RenderKind.Cross) {
          addCross(opaque, x, y, z, def.tiles[0]);
          continue;
        }

        const isTransparent = def.render === RenderKind.Transparent;
        const builder = isTransparent ? transparent : opaque;

        for (let f = 0; f < 6; f++) {
          const face = FACES[f]!;
          const nx = x + face.dir[0];
          const ny = y + face.dir[1];
          const nz = z + face.dir[2];
          const neighbor = sample(grid, nx, ny, nz);
          const ndef = BLOCKS[neighbor]!;

          // Cull rules: opaque faces hidden by any opaque neighbor.
          // Transparent faces hidden only by the *same* block type (so water
          // surfaces and glass panes still draw their outer shell).
          if (isTransparent) {
            if (neighbor === id) continue;
            if (ndef.opaque) continue;
          } else if (ndef.opaque) {
            continue;
          }

          const tile = def.tiles[face.tile]!;
          const shadeBase = FACE_SHADE[f]!;

          // Compute AO for each of the 4 corners.
          const light: [number, number, number, number] = [1, 1, 1, 1];
          for (let ci = 0; ci < 4; ci++) {
            const c = face.corners[ci]!;
            // Corner position relative to block, mapped to the two tangent dirs.
            const ao = cornerAO(grid, x, y, z, face, c);
            const aoFactor = 0.5 + (ao / 3) * 0.5; // 0.5..1.0
            light[ci] = shadeBase * aoFactor;
          }
          // Flip triangulation to the brighter diagonal.
          const flip = light[0] + light[2] < light[1] + light[3];

          builder.addQuad(face.corners, x, y, z, face.normal, tile, light, flip);
        }
      }
    }
  }

  return { opaque: opaque.build(), transparent: transparent.build() };
}

/**
 * AO for a single face corner. The corner offset c is in {0,1}^3; we look at
 * the two edge-adjacent blocks and the diagonal, all offset along the face
 * normal by 1 (i.e. in the "outside" layer).
 */
function cornerAO(
  grid: NeighborGrid,
  x: number,
  y: number,
  z: number,
  face: FaceDef,
  c: [number, number, number],
): number {
  const [dnx, dny, dnz] = face.dir;
  // Base of the outside layer.
  const ox = x + dnx;
  const oy = y + dny;
  const oz = z + dnz;
  // The two tangent axes are the ones not equal to the face normal axis.
  // Determine per-corner side offsets by converting the {0,1} corner to {-1,+1}
  // in the tangent plane.
  const sx = c[0] === 1 ? 1 : -1;
  const sy = c[1] === 1 ? 1 : -1;
  const sz = c[2] === 1 ? 1 : -1;

  // Zero-out the component along the face normal so we only step in tangents.
  const tx = dnx !== 0 ? 0 : sx;
  const ty = dny !== 0 ? 0 : sy;
  const tz = dnz !== 0 ? 0 : sz;

  // Two side neighbors: step along each tangent axis independently.
  // Identify the two tangent axes.
  const axes: [number, number, number][] = [];
  if (dnx === 0) axes.push([tx, 0, 0]);
  if (dny === 0) axes.push([0, ty, 0]);
  if (dnz === 0) axes.push([0, 0, tz]);
  // axes has exactly 2 entries.
  const a = axes[0]!;
  const b = axes[1]!;
  const side1 = occludes(grid, ox + a[0], oy + a[1], oz + a[2]);
  const side2 = occludes(grid, ox + b[0], oy + b[1], oz + b[2]);
  const corner = occludes(grid, ox + tx, oy + ty, oz + tz);
  return vertexAO(side1, side2, corner);
}

/** Cross-plane sprite (flower, torch, tall grass): two quads in an X. */
function addCross(builder: MeshBuilder, x: number, y: number, z: number, tile: number): void {
  const light: [number, number, number, number] = [1, 1, 1, 1];
  // Plane 1: diagonal from (0,0,0)->(1,_,1)
  builder.addQuad(
    [[0.15, 0, 0.15], [0.85, 0, 0.85], [0.85, 1, 0.85], [0.15, 1, 0.15]],
    x, y, z, [0, 1, 0], tile, light, false,
  );
  // Plane 2: opposite diagonal
  builder.addQuad(
    [[0.85, 0, 0.15], [0.15, 0, 0.85], [0.15, 1, 0.85], [0.85, 1, 0.15]],
    x, y, z, [0, 1, 0], tile, light, false,
  );
}
