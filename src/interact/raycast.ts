/**
 * Voxel ray traversal (Amanatides & Woo DDA). Steps a ray through the integer
 * voxel grid one cell boundary at a time — exact, no sampling gaps — and stops
 * at the first targetable block. Returns the hit cell plus the face normal
 * (which cell face the ray entered through), used to place blocks against it.
 */

export interface RaycastHit {
  /** Hit block cell. */
  x: number;
  y: number;
  z: number;
  /** Face normal of the entered face (points back toward the ray origin). */
  nx: number;
  ny: number;
  nz: number;
  blockId: number;
  distance: number;
}

export type BlockGetter = (x: number, y: number, z: number) => number;
export type Targetable = (id: number) => boolean;

/**
 * Cast a ray from `origin` along unit `dir` up to `maxDistance` blocks.
 * `getBlock` returns the block id at a cell; `isTargetable` decides whether a
 * given block id stops the ray (e.g. air and water are transparent to it).
 */
export function raycastVoxel(
  ox: number,
  oy: number,
  oz: number,
  dx: number,
  dy: number,
  dz: number,
  maxDistance: number,
  getBlock: BlockGetter,
  isTargetable: Targetable,
): RaycastHit | null {
  // Current voxel.
  let x = Math.floor(ox);
  let y = Math.floor(oy);
  let z = Math.floor(oz);

  const stepX = dx > 0 ? 1 : dx < 0 ? -1 : 0;
  const stepY = dy > 0 ? 1 : dy < 0 ? -1 : 0;
  const stepZ = dz > 0 ? 1 : dz < 0 ? -1 : 0;

  // Distance (in t, where position = origin + dir*t) to the next cell boundary
  // on each axis, and the t-delta to cross a whole cell.
  const tDeltaX = dx !== 0 ? Math.abs(1 / dx) : Infinity;
  const tDeltaY = dy !== 0 ? Math.abs(1 / dy) : Infinity;
  const tDeltaZ = dz !== 0 ? Math.abs(1 / dz) : Infinity;

  const nextBoundary = (o: number, cell: number, step: number): number => {
    if (step > 0) return cell + 1 - o;
    if (step < 0) return o - cell;
    return Infinity;
  };
  let tMaxX = dx !== 0 ? nextBoundary(ox, x, stepX) / Math.abs(dx) : Infinity;
  let tMaxY = dy !== 0 ? nextBoundary(oy, y, stepY) / Math.abs(dy) : Infinity;
  let tMaxZ = dz !== 0 ? nextBoundary(oz, z, stepZ) / Math.abs(dz) : Infinity;

  // Face normal of the most recently crossed boundary.
  let nx = 0;
  let ny = 0;
  let nz = 0;

  // Check the origin cell first (you can be inside a targetable block).
  let id = getBlock(x, y, z);
  if (isTargetable(id)) {
    return { x, y, z, nx: 0, ny: 1, nz: 0, blockId: id, distance: 0 };
  }

  let t = 0;
  while (t <= maxDistance) {
    if (tMaxX < tMaxY && tMaxX < tMaxZ) {
      x += stepX;
      t = tMaxX;
      tMaxX += tDeltaX;
      nx = -stepX;
      ny = 0;
      nz = 0;
    } else if (tMaxY < tMaxZ) {
      y += stepY;
      t = tMaxY;
      tMaxY += tDeltaY;
      nx = 0;
      ny = -stepY;
      nz = 0;
    } else {
      z += stepZ;
      t = tMaxZ;
      tMaxZ += tDeltaZ;
      nx = 0;
      ny = 0;
      nz = -stepZ;
    }
    if (t > maxDistance) break;

    id = getBlock(x, y, z);
    if (isTargetable(id)) {
      return { x, y, z, nx, ny, nz, blockId: id, distance: t };
    }
  }
  return null;
}
