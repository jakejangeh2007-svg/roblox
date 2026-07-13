/**
 * Block interaction: aims a voxel ray from the player's eye, renders a
 * selection wireframe + animated crack overlay on the targeted block, and
 * drives breaking (hold) and placing (tap/right-click) against the world.
 *
 * Breaking speed scales with the held tool; drops (when the tool can harvest)
 * are handed to `onDrop`, which by default deposits into the inventory. Step 5
 * swaps that for physical, magnetizing 3D item drops.
 */
import * as THREE from 'three';
import { REACH_DISTANCE } from '../config/constants';
import { BlockId, getBlock as getBlockDef, isSolid } from '../world/Block';
import {
  breakTimeSeconds,
  canHarvest,
  getItem,
  placeableBlock,
  type ItemDef,
} from '../items/Item';
import type { Inventory } from '../player/Inventory';
import type { Player } from '../player/Player';
import type { ChunkManager } from '../world/ChunkManager';
import type { InputState } from '../input/InputState';
import { raycastVoxel, type RaycastHit } from './raycast';
import { BreakController } from './mining';
import { buildCrackTextures } from './crackTextures';

const REPLACEABLE = new Set<number>([
  BlockId.Air,
  BlockId.Water,
  BlockId.TallGrass,
  BlockId.Flower,
]);

export type DropHandler = (itemId: number, count: number, x: number, y: number, z: number) => void;

export class BlockInteraction {
  private readonly highlight: THREE.LineSegments;
  private readonly crack: THREE.Mesh;
  private readonly crackTextures: THREE.Texture[];
  private readonly breaker = new BreakController();

  private readonly origin = new THREE.Vector3();
  private readonly dir = new THREE.Vector3();

  /** Current targeted block (null when nothing in reach). */
  target: RaycastHit | null = null;
  /** 0..1 progress on the current break, for HUD. */
  breakProgress = 0;

  onDrop: DropHandler;
  /** Optional hook: return true to consume a use-press on an interactive block
   * (crafting table, furnace, chest) instead of placing. */
  onInteract: ((blockId: number, x: number, y: number, z: number) => boolean) | null = null;
  /** Called after a block is broken (for tile-entity cleanup, exertion). */
  onBreak: ((blockId: number, x: number, y: number, z: number) => void) | null = null;
  /** True on the tick a block was broken; the caller reads and clears it. */
  minedThisTick = false;

  constructor(
    scene: THREE.Scene,
    private readonly player: Player,
    private readonly chunks: ChunkManager,
    private readonly inventory: Inventory,
  ) {
    // Selection wireframe.
    const edges = new THREE.EdgesGeometry(new THREE.BoxGeometry(1.002, 1.002, 1.002));
    const mat = new THREE.LineBasicMaterial({ color: 0x000000, transparent: true, opacity: 0.5 });
    this.highlight = new THREE.LineSegments(edges, mat);
    this.highlight.visible = false;
    this.highlight.renderOrder = 2;
    scene.add(this.highlight);

    // Crack overlay (slightly inflated so it sits on the block surface).
    this.crackTextures = buildCrackTextures();
    const crackMat = new THREE.MeshBasicMaterial({
      map: this.crackTextures[0]!,
      transparent: true,
      polygonOffset: true,
      polygonOffsetFactor: -1,
      depthWrite: false,
    });
    this.crack = new THREE.Mesh(new THREE.BoxGeometry(1.01, 1.01, 1.01), crackMat);
    this.crack.visible = false;
    this.crack.renderOrder = 3;
    scene.add(this.crack);

    // Default drop behavior: straight into the inventory.
    this.onDrop = (itemId, count) => {
      this.inventory.add(itemId, count);
    };
  }

  private isTargetable = (id: number): boolean => {
    return id !== BlockId.Air && id !== BlockId.Water;
  };

  update(dt: number, input: InputState): void {
    const eye = this.player.eyePosition;
    this.origin.copy(eye);
    this.player.getLookDirection(this.dir);

    const hit = raycastVoxel(
      this.origin.x,
      this.origin.y,
      this.origin.z,
      this.dir.x,
      this.dir.y,
      this.dir.z,
      REACH_DISTANCE,
      (x, y, z) => this.chunks.getBlock(x, y, z),
      this.isTargetable,
    );
    this.target = hit;

    if (!hit) {
      this.highlight.visible = false;
      this.crack.visible = false;
      this.breaker.reset();
      this.breakProgress = 0;
      // Still consume a stray place-press so it doesn't fire later.
      input.primaryPressed = false;
      return;
    }

    this.highlight.position.set(hit.x + 0.5, hit.y + 0.5, hit.z + 0.5);
    this.highlight.visible = true;

    // --- Use / place (edge-triggered) ---------------------------------------
    if (input.primaryPressed) {
      input.primaryPressed = false;
      const handled = this.onInteract?.(hit.blockId, hit.x, hit.y, hit.z) ?? false;
      if (!handled) this.tryPlace(hit);
    }

    // --- Breaking (held) ----------------------------------------------------
    const def = getBlockDef(hit.blockId);
    const held = this.inventory.getSelectedDef();
    const breakTime = breakTimeSeconds(def, held);
    const key = `${hit.x},${hit.y},${hit.z}`;
    const state = this.breaker.update(key, breakTime, dt, input.mining);
    this.breakProgress = state.progress;

    if (state.stage >= 0 && input.mining) {
      this.crack.visible = true;
      this.crack.position.set(hit.x + 0.5, hit.y + 0.5, hit.z + 0.5);
      const mat = this.crack.material as THREE.MeshBasicMaterial;
      mat.map = this.crackTextures[state.stage]!;
      mat.needsUpdate = true;
    } else {
      this.crack.visible = false;
    }

    if (state.completed) {
      this.breakBlock(hit, def, held);
      this.breaker.reset();
      this.breakProgress = 0;
      this.crack.visible = false;
    }
  }

  private tryPlace(hit: RaycastHit): void {
    const held = this.inventory.getSelected();
    if (!held) return;
    const placeId = placeableBlock(held.item);
    if (placeId === null) return;

    const px = hit.x + hit.nx;
    const py = hit.y + hit.ny;
    const pz = hit.z + hit.nz;
    if (py < 0 || py > 255) return;

    const existing = this.chunks.getBlock(px, py, pz);
    if (!REPLACEABLE.has(existing)) return;

    // Don't place a solid block inside the player's body.
    if (isSolid(placeId) && this.intersectsPlayer(px, py, pz)) return;

    if (this.chunks.setBlock(px, py, pz, placeId)) {
      this.inventory.consumeSelected(1);
    }
  }

  private intersectsPlayer(bx: number, by: number, bz: number): boolean {
    const p = this.player.position;
    const half = this.player.half;
    const minX = p.x - half;
    const maxX = p.x + half;
    const minZ = p.z - half;
    const maxZ = p.z + half;
    const minY = p.y;
    const maxY = p.y + this.player.height;
    return (
      bx + 1 > minX &&
      bx < maxX &&
      by + 1 > minY &&
      by < maxY &&
      bz + 1 > minZ &&
      bz < maxZ
    );
  }

  private breakBlock(hit: RaycastHit, def: ReturnType<typeof getBlockDef>, held: ItemDef | undefined): void {
    // Determine the drop: explicit def.drop wins; undefined means "drops self";
    // Air means "drops nothing". Wrong tool → no drop.
    if (canHarvest(def, held)) {
      const dropId = def.drop === undefined ? def.id : def.drop;
      if (dropId !== BlockId.Air) {
        this.onDrop(dropId, 1, hit.x + 0.5, hit.y + 0.5, hit.z + 0.5);
      }
    }
    this.chunks.setBlock(hit.x, hit.y, hit.z, BlockId.Air);
    this.damageHeldTool(held);
    this.minedThisTick = true;
    this.onBreak?.(hit.blockId, hit.x, hit.y, hit.z);
  }

  private damageHeldTool(held: ItemDef | undefined): void {
    if (!held?.tool) return;
    const stack = this.inventory.getSelected();
    if (!stack) return;
    const max = held.tool.maxDurability;
    stack.durability = (stack.durability ?? max) - 1;
    if (stack.durability <= 0) {
      this.inventory.consumeSelected(1); // tool breaks
    }
  }

  /** Human-readable name of the targeted block, for HUD/debug. */
  get targetName(): string {
    return this.target ? getBlockDef(this.target.blockId).name : '—';
  }

  /** Name of the held item, for HUD/debug. */
  heldName(): string {
    const s = this.inventory.getSelected();
    return s ? getItem(s.item).name : 'Empty hand';
  }
}
