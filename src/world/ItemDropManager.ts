/**
 * Physical item drops: mining a block spawns a small spinning 3D item that
 * bounces on the ground, then magnetizes to the player and merges into the
 * inventory. Block items render as mini cubes; other items as billboard-ish
 * quads. All drops share cropped single-tile textures (cached), so a drop is
 * one tiny draw call.
 */
import * as THREE from 'three';
import { GRAVITY } from '../config/constants';
import { getItem } from '../items/Item';
import { getBlock as getBlockDef, RenderKind } from './Block';
import { getTileTexture } from './atlas';
import type { Inventory } from '../player/Inventory';

const MAGNET_RADIUS = 2.2;
const PICKUP_RADIUS = 0.9;
const MERGE_RADIUS = 0.6;
const DROP_SIZE = 0.28;
const PICKUP_DELAY = 0.4; // seconds before a fresh drop can be collected
const MAX_LIFETIME = 300; // despawn after 5 minutes to bound memory

type SolidFn = (x: number, y: number, z: number) => boolean;

interface Drop {
  mesh: THREE.Mesh;
  item: number;
  count: number;
  vx: number;
  vy: number;
  vz: number;
  age: number;
  onGround: boolean;
}

export class ItemDropManager {
  private readonly drops: Drop[] = [];
  private readonly group = new THREE.Group();
  private readonly geometryCache = new Map<number, THREE.BufferGeometry>();
  private readonly materialCache = new Map<number, THREE.Material>();

  constructor(
    private readonly scene: THREE.Scene,
    private readonly inventory: Inventory,
    private readonly isSolid: SolidFn,
  ) {
    scene.add(this.group);
  }

  private materialFor(item: number): THREE.Material {
    const cached = this.materialCache.get(item);
    if (cached) return cached;
    const def = getItem(item);
    const tex = getTileTexture(def.icon);
    const mat = new THREE.MeshBasicMaterial({
      map: tex,
      transparent: true,
      alphaTest: 0.3,
      side: THREE.DoubleSide,
    });
    this.materialCache.set(item, mat);
    return mat;
  }

  private geometryFor(item: number): THREE.BufferGeometry {
    const cached = this.geometryCache.get(item);
    if (cached) return cached;
    const def = getItem(item);
    let geo: THREE.BufferGeometry;
    const isFullBlock =
      def.placeBlock !== undefined &&
      getBlockDef(def.placeBlock).render !== RenderKind.Cross;
    if (isFullBlock) {
      geo = new THREE.BoxGeometry(DROP_SIZE, DROP_SIZE, DROP_SIZE);
    } else {
      geo = new THREE.PlaneGeometry(DROP_SIZE * 1.3, DROP_SIZE * 1.3);
    }
    this.geometryCache.set(item, geo);
    return geo;
  }

  spawn(item: number, count: number, x: number, y: number, z: number): void {
    const mesh = new THREE.Mesh(this.geometryFor(item), this.materialFor(item));
    mesh.position.set(x, y, z);
    this.group.add(mesh);
    // Pop out with a little random horizontal velocity + upward hop.
    const ang = (item * 2.399963) % (Math.PI * 2); // deterministic-ish spread
    this.drops.push({
      mesh,
      item,
      count,
      vx: Math.cos(ang) * 1.2,
      vy: 2.2,
      vz: Math.sin(ang) * 1.2,
      age: 0,
      onGround: false,
    });
  }

  update(dt: number, playerX: number, playerY: number, playerZ: number): void {
    // Player collection point ~ mid-body.
    const cx = playerX;
    const cy = playerY + 0.9;
    const cz = playerZ;

    for (let i = this.drops.length - 1; i >= 0; i--) {
      const d = this.drops[i]!;
      d.age += dt;
      const m = d.mesh;

      // Spin for visibility.
      m.rotation.y += dt * 2.2;

      // Physics: gravity + simple ground rest.
      d.vy += GRAVITY * dt;
      let ny = m.position.y + d.vy * dt;
      const fx = Math.floor(m.position.x);
      const fz = Math.floor(m.position.z);
      if (d.vy < 0 && this.isSolid(fx, Math.floor(ny - DROP_SIZE / 2), fz)) {
        ny = Math.floor(ny - DROP_SIZE / 2) + 1 + DROP_SIZE / 2;
        d.vy = 0;
        d.onGround = true;
      }
      m.position.y = ny;
      m.position.x += d.vx * dt;
      m.position.z += d.vz * dt;
      if (d.onGround) {
        d.vx *= 0.7;
        d.vz *= 0.7;
      }

      // Magnetize toward the player, then collect.
      const dx = cx - m.position.x;
      const dy = cy - m.position.y;
      const dz = cz - m.position.z;
      const dist = Math.hypot(dx, dy, dz);
      if (d.age > PICKUP_DELAY && dist < MAGNET_RADIUS) {
        const pull = 8 * dt;
        m.position.x += dx * pull;
        m.position.y += dy * pull;
        m.position.z += dz * pull;
        if (dist < PICKUP_RADIUS) {
          const leftover = this.inventory.add(d.item, d.count);
          if (leftover === 0) {
            this.remove(i);
            continue;
          }
          d.count = leftover; // inventory full: keep the remainder on the ground
        }
      }

      if (d.age > MAX_LIFETIME) this.remove(i);
    }

    this.mergeNearby();
  }

  /** Merge same-item drops that drift together, capping mesh/draw counts. */
  private mergeNearby(): void {
    for (let i = 0; i < this.drops.length; i++) {
      const a = this.drops[i]!;
      for (let j = this.drops.length - 1; j > i; j--) {
        const b = this.drops[j]!;
        if (a.item !== b.item) continue;
        const dx = a.mesh.position.x - b.mesh.position.x;
        const dy = a.mesh.position.y - b.mesh.position.y;
        const dz = a.mesh.position.z - b.mesh.position.z;
        if (dx * dx + dy * dy + dz * dz < MERGE_RADIUS * MERGE_RADIUS) {
          a.count += b.count;
          this.remove(j);
        }
      }
    }
  }

  private remove(i: number): void {
    const d = this.drops[i]!;
    this.group.remove(d.mesh);
    this.drops.splice(i, 1);
  }

  get count(): number {
    return this.drops.length;
  }

  dispose(): void {
    for (const d of this.drops) this.group.remove(d.mesh);
    this.drops.length = 0;
    for (const g of this.geometryCache.values()) g.dispose();
    this.scene.remove(this.group);
  }
}
