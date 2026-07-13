/**
 * Axis-Aligned Bounding Box collision against the voxel grid, plus gravity and
 * fall-damage bookkeeping. Pure functions over an `isSolid(x,y,z)` predicate so
 * they unit-test without a live world.
 *
 * The player box is described by a horizontal half-width and a height; position
 * is the feet-center (x,z centered, y at the bottom). Movement resolves one
 * axis at a time so the player slides along walls instead of sticking, and the
 * move is sub-stepped when a single tick's displacement exceeds half a block
 * (terminal-velocity falls move >1 block/tick and would otherwise tunnel).
 */

export interface AABB {
  minX: number;
  minY: number;
  minZ: number;
  maxX: number;
  maxY: number;
  maxZ: number;
}

export type SolidFn = (x: number, y: number, z: number) => boolean;

const EPS = 1e-4;

export interface MoveResult {
  x: number;
  y: number;
  z: number;
  onGround: boolean;
  hitCeiling: boolean;
  hitWall: boolean;
}

function boxAt(x: number, y: number, z: number, half: number, height: number): AABB {
  return {
    minX: x - half,
    minY: y,
    minZ: z - half,
    maxX: x + half,
    maxY: y + height,
    maxZ: z + half,
  };
}

/** Resolve a single small Y move; returns clamped dy and whether it hit. */
function resolveY(box: AABB, dy: number, isSolid: SolidFn): { dy: number; hit: boolean } {
  if (dy === 0) return { dy, hit: false };
  const x0 = Math.floor(box.minX + EPS);
  const x1 = Math.floor(box.maxX - EPS);
  const z0 = Math.floor(box.minZ + EPS);
  const z1 = Math.floor(box.maxZ - EPS);
  if (dy > 0) {
    const yc = Math.floor(box.maxY + dy - EPS);
    for (let x = x0; x <= x1; x++)
      for (let z = z0; z <= z1; z++)
        if (isSolid(x, yc, z)) return { dy: yc - box.maxY - EPS, hit: true };
  } else {
    const yc = Math.floor(box.minY + dy + EPS);
    for (let x = x0; x <= x1; x++)
      for (let z = z0; z <= z1; z++)
        if (isSolid(x, yc, z)) return { dy: yc + 1 - box.minY + EPS, hit: true };
  }
  return { dy, hit: false };
}

function resolveX(box: AABB, dx: number, isSolid: SolidFn): { dx: number; hit: boolean } {
  if (dx === 0) return { dx, hit: false };
  const y0 = Math.floor(box.minY + EPS);
  const y1 = Math.floor(box.maxY - EPS);
  const z0 = Math.floor(box.minZ + EPS);
  const z1 = Math.floor(box.maxZ - EPS);
  if (dx > 0) {
    const xc = Math.floor(box.maxX + dx - EPS);
    for (let y = y0; y <= y1; y++)
      for (let z = z0; z <= z1; z++)
        if (isSolid(xc, y, z)) return { dx: xc - box.maxX - EPS, hit: true };
  } else {
    const xc = Math.floor(box.minX + dx + EPS);
    for (let y = y0; y <= y1; y++)
      for (let z = z0; z <= z1; z++)
        if (isSolid(xc, y, z)) return { dx: xc + 1 - box.minX + EPS, hit: true };
  }
  return { dx, hit: false };
}

function resolveZ(box: AABB, dz: number, isSolid: SolidFn): { dz: number; hit: boolean } {
  if (dz === 0) return { dz, hit: false };
  const x0 = Math.floor(box.minX + EPS);
  const x1 = Math.floor(box.maxX - EPS);
  const y0 = Math.floor(box.minY + EPS);
  const y1 = Math.floor(box.maxY - EPS);
  if (dz > 0) {
    const zc = Math.floor(box.maxZ + dz - EPS);
    for (let x = x0; x <= x1; x++)
      for (let y = y0; y <= y1; y++)
        if (isSolid(x, y, zc)) return { dz: zc - box.maxZ - EPS, hit: true };
  } else {
    const zc = Math.floor(box.minZ + dz + EPS);
    for (let x = x0; x <= x1; x++)
      for (let y = y0; y <= y1; y++)
        if (isSolid(x, y, zc)) return { dz: zc + 1 - box.minZ + EPS, hit: true };
  }
  return { dz, hit: false };
}

/**
 * Move a feet-centered box by (dx,dy,dz), resolving collisions. Sub-steps so no
 * single sub-move exceeds ~0.45 blocks. Y is resolved first (so ground contact
 * is known), then X and Z for wall sliding.
 */
export function moveAABB(
  x: number,
  y: number,
  z: number,
  half: number,
  height: number,
  dx: number,
  dy: number,
  dz: number,
  isSolid: SolidFn,
): MoveResult {
  const maxMove = Math.max(Math.abs(dx), Math.abs(dy), Math.abs(dz));
  const steps = Math.max(1, Math.ceil(maxMove / 0.45));
  const sx = dx / steps;
  const sy = dy / steps;
  const sz = dz / steps;

  let onGround = false;
  let hitCeiling = false;
  let hitWall = false;

  for (let s = 0; s < steps; s++) {
    let box = boxAt(x, y, z, half, height);
    const ry = resolveY(box, sy, isSolid);
    y += ry.dy;
    if (ry.hit) {
      if (sy < 0) onGround = true;
      else hitCeiling = true;
    }

    box = boxAt(x, y, z, half, height);
    const rx = resolveX(box, sx, isSolid);
    x += rx.dx;
    if (rx.hit) hitWall = true;

    box = boxAt(x, y, z, half, height);
    const rz = resolveZ(box, sz, isSolid);
    z += rz.dz;
    if (rz.hit) hitWall = true;
  }

  return { x, y, z, onGround, hitCeiling, hitWall };
}

/** True if the box would overlap any solid voxel at the given feet position. */
export function isPositionColliding(
  x: number,
  y: number,
  z: number,
  half: number,
  height: number,
  isSolid: SolidFn,
): boolean {
  const box = boxAt(x, y, z, half, height);
  const x0 = Math.floor(box.minX + EPS);
  const x1 = Math.floor(box.maxX - EPS);
  const y0 = Math.floor(box.minY + EPS);
  const y1 = Math.floor(box.maxY - EPS);
  const z0 = Math.floor(box.minZ + EPS);
  const z1 = Math.floor(box.maxZ - EPS);
  for (let x2 = x0; x2 <= x1; x2++)
    for (let y2 = y0; y2 <= y1; y2++)
      for (let z2 = z0; z2 <= z1; z2++) if (isSolid(x2, y2, z2)) return true;
  return false;
}

/**
 * Fall damage in half-hearts for a landing after falling `fallDistance` blocks.
 * Matches Minecraft: (distance - 3) damage points, 1 point = half a heart.
 */
export function fallDamage(fallDistance: number, safeBlocks: number): number {
  return Math.max(0, Math.floor(fallDistance + 1e-6) - safeBlocks);
}
