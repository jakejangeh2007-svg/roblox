/**
 * Streams chunk columns around the player: requests generation/meshing from the
 * worker, builds Three.js meshes, unloads distant chunks, and persists edited
 * chunks to IndexedDB.
 *
 * Ownership model: the main thread holds the authoritative block data (needed
 * synchronously for physics and interaction). To mesh, it sends *copies* of the
 * relevant chunk + neighbor block buffers to the worker (transferred, so the
 * copies detach cleanly) and receives fresh vertex buffers back.
 */
import * as THREE from 'three';
import {
  CHUNK_SIZE_X,
  CHUNK_SIZE_Z,
  SAVE_DEBOUNCE_MS,
} from '../config/constants';
import { chunkKey, worldToChunk, worldToLocal } from '../core/math';
import { WorldStore, CHUNK_FORMAT_VERSION, type StoredChunk } from '../storage/WorldStore';
import { Chunk, ChunkState } from './Chunk';
import { BlockId } from './Block';
import { buildAtlasTexture } from './atlas';
import { createChunkMaterials, type ChunkMaterials } from './ChunkMaterial';
import type {
  FromWorker,
  ToWorker,
  MeshBuffersMsg,
} from './workers/protocol';
import GenWorker from './workers/genWorker?worker';

interface ChunkMeshes {
  opaque: THREE.Mesh | null;
  transparent: THREE.Mesh | null;
}

export class ChunkManager {
  private readonly worker: Worker;
  private readonly chunks = new Map<number, Chunk>();
  private readonly meshes = new Map<number, ChunkMeshes>();
  private readonly pending = new Set<number>();
  /** Chunks awaiting an async DB lookup before we decide gen vs load. */
  private readonly loading = new Set<number>();
  private readonly dirty = new Set<number>();

  private readonly materials: ChunkMaterials;
  private readonly group = new THREE.Group();

  private saveTimer: ReturnType<typeof setTimeout> | null = null;
  private centerCx = Infinity;
  private centerCz = Infinity;

  /** Current streaming radius in chunks. */
  renderDistance: number;

  constructor(
    private readonly scene: THREE.Scene,
    private readonly store: WorldStore,
    private readonly worldId: string,
    seed: number,
    renderDistance: number,
  ) {
    this.renderDistance = renderDistance;
    this.scene.add(this.group);

    const atlas = buildAtlasTexture();
    // Custom light-aware shader: baked surface shade + sky/block light per
    // vertex, combined with a day/night uniform so time-of-day is free.
    this.materials = createChunkMaterials(atlas);

    this.worker = new GenWorker();
    this.worker.onmessage = (ev: MessageEvent<FromWorker>) => this.onWorkerMessage(ev.data);
    this.post({ type: 'init', seed });
  }

  private post(msg: ToWorker, transfer: Transferable[] = []): void {
    this.worker.postMessage(msg, transfer);
  }

  /** Called each tick with the player's world position. */
  update(px: number, pz: number): void {
    const ccx = worldToChunk(Math.floor(px));
    const ccz = worldToChunk(Math.floor(pz));
    if (ccx === this.centerCx && ccz === this.centerCz) return;
    this.centerCx = ccx;
    this.centerCz = ccz;

    const r = this.renderDistance;
    // Load ring, nearest-first so the player's surroundings appear first.
    const wanted: [number, number, number][] = [];
    for (let dz = -r; dz <= r; dz++) {
      for (let dx = -r; dx <= r; dx++) {
        const dist = dx * dx + dz * dz;
        if (dist > r * r + r) continue; // roughly circular
        wanted.push([ccx + dx, ccz + dz, dist]);
      }
    }
    wanted.sort((a, b) => a[2] - b[2]);
    for (const [cx, cz] of wanted) this.ensureChunk(cx, cz);

    // Unload chunks outside the ring (+1 hysteresis to avoid thrash).
    const keep = r + 1;
    for (const key of this.chunks.keys()) {
      const chunk = this.chunks.get(key)!;
      if (Math.abs(chunk.cx - ccx) > keep || Math.abs(chunk.cz - ccz) > keep) {
        this.unloadChunk(chunk.cx, chunk.cz);
      }
    }
  }

  private ensureChunk(cx: number, cz: number): void {
    const key = chunkKey(cx, cz);
    if (this.chunks.has(key) || this.pending.has(key) || this.loading.has(key)) return;
    this.loading.add(key);
    // Prefer a persisted (player-edited) chunk; otherwise generate from seed.
    void this.store
      .getChunk(this.worldId, cx, cz)
      .then((stored) => {
        this.loading.delete(key);
        // The player may have moved away while we waited.
        if (Math.abs(cx - this.centerCx) > this.renderDistance + 1) return;
        if (this.chunks.has(key) || this.pending.has(key)) return;
        if (stored) {
          const chunk = new Chunk(cx, cz, new Uint8Array(stored.blocks));
          chunk.state = ChunkState.Generated;
          chunk.modified = true; // it was persisted because it was edited
          this.chunks.set(key, chunk);
          this.requestMesh(cx, cz);
          this.remeshNeighbors(cx, cz);
        } else {
          this.pending.add(key);
          this.post({ type: 'generate', cx, cz });
        }
      })
      .catch((err: unknown) => {
        this.loading.delete(key);
        console.error(`Chunk load failed ${cx},${cz}`, err);
      });
  }

  private onWorkerMessage(msg: FromWorker): void {
    if (msg.type === 'generated') {
      const key = chunkKey(msg.cx, msg.cz);
      this.pending.delete(key);
      if (this.chunks.has(key)) return;
      const chunk = new Chunk(msg.cx, msg.cz, new Uint8Array(msg.blocks));
      chunk.state = ChunkState.Generated;
      this.chunks.set(key, chunk);
      this.requestMesh(msg.cx, msg.cz);
      // Neighbors that were meshed against "air" now need to hide border faces.
      this.remeshNeighbors(msg.cx, msg.cz);
    } else {
      this.applyMesh(msg.cx, msg.cz, msg.opaque, msg.transparent);
    }
  }

  /** Gather 9 neighbor block copies and ask the worker to mesh. */
  private requestMesh(cx: number, cz: number): void {
    const center = this.chunks.get(chunkKey(cx, cz));
    if (!center) return;
    const neighbors: (ArrayBuffer | null)[] = new Array<ArrayBuffer | null>(9).fill(null);
    const transfer: Transferable[] = [];
    for (let dz = -1; dz <= 1; dz++) {
      for (let dx = -1; dx <= 1; dx++) {
        const n = this.chunks.get(chunkKey(cx + dx, cz + dz));
        if (n) {
          // Copy so the authoritative buffer stays on the main thread.
          const copy = n.blocks.slice().buffer;
          neighbors[(dz + 1) * 3 + (dx + 1)] = copy;
          transfer.push(copy);
        }
      }
    }
    this.post({ type: 'mesh', cx, cz, neighbors }, transfer);
  }

  private remeshNeighbors(cx: number, cz: number): void {
    for (let dz = -1; dz <= 1; dz++) {
      for (let dx = -1; dx <= 1; dx++) {
        if (dx === 0 && dz === 0) continue;
        const n = this.chunks.get(chunkKey(cx + dx, cz + dz));
        if (n && n.state === ChunkState.Meshed) this.requestMesh(n.cx, n.cz);
      }
    }
  }

  private applyMesh(
    cx: number,
    cz: number,
    opaque: MeshBuffersMsg | null,
    transparent: MeshBuffersMsg | null,
  ): void {
    const key = chunkKey(cx, cz);
    const chunk = this.chunks.get(key);
    if (!chunk) return; // unloaded before mesh returned
    chunk.state = ChunkState.Meshed;

    const existing = this.meshes.get(key);
    if (existing) this.disposeMeshes(existing);

    const ox = cx * CHUNK_SIZE_X;
    const oz = cz * CHUNK_SIZE_Z;
    const meshes: ChunkMeshes = {
      opaque: opaque ? this.buildMesh(opaque, this.materials.opaque, ox, oz) : null,
      transparent: transparent
        ? this.buildMesh(transparent, this.materials.transparent, ox, oz)
        : null,
    };
    if (meshes.opaque) this.group.add(meshes.opaque);
    if (meshes.transparent) this.group.add(meshes.transparent);
    this.meshes.set(key, meshes);
  }

  private buildMesh(
    buf: MeshBuffersMsg,
    material: THREE.Material,
    ox: number,
    oz: number,
  ): THREE.Mesh {
    const geo = new THREE.BufferGeometry();
    const positions = new Float32Array(buf.positions);
    geo.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    geo.setAttribute('normal', new THREE.BufferAttribute(new Float32Array(buf.normals), 3));
    geo.setAttribute('uv', new THREE.BufferAttribute(new Float32Array(buf.uvs), 2));

    // Per-vertex light (surface, sky, block) → the shader's `color` attribute.
    geo.setAttribute('color', new THREE.BufferAttribute(new Float32Array(buf.light), 3));
    geo.setIndex(new THREE.BufferAttribute(new Uint32Array(buf.indices), 1));
    geo.computeBoundingSphere(); // enables Three's per-mesh frustum culling

    const mesh = new THREE.Mesh(geo, material);
    mesh.position.set(ox, 0, oz);
    mesh.frustumCulled = true;
    return mesh;
  }

  private unloadChunk(cx: number, cz: number): void {
    const key = chunkKey(cx, cz);
    const chunk = this.chunks.get(key);
    if (!chunk) return;
    if (chunk.modified) this.queueSave(chunk);
    const m = this.meshes.get(key);
    if (m) {
      this.disposeMeshes(m);
      this.meshes.delete(key);
    }
    this.chunks.delete(key);
  }

  private disposeMeshes(m: ChunkMeshes): void {
    for (const mesh of [m.opaque, m.transparent]) {
      if (!mesh) continue;
      this.group.remove(mesh);
      mesh.geometry.dispose();
    }
  }

  // -- world-space block API (physics + interaction) -------------------------

  getBlock(wx: number, wy: number, wz: number): number {
    const chunk = this.chunks.get(chunkKey(worldToChunk(wx), worldToChunk(wz)));
    if (!chunk) return BlockId.Air;
    return chunk.getBlock(worldToLocal(wx), wy, worldToLocal(wz));
  }

  /** True only if the chunk containing (wx,wz) is currently loaded. */
  isLoaded(wx: number, wz: number): boolean {
    return this.chunks.has(chunkKey(worldToChunk(wx), worldToChunk(wz)));
  }

  /**
   * Set a block in world space. Marks the chunk modified, remeshes it, and
   * remeshes neighbors if the edit is on a border. Returns false if unloaded.
   */
  setBlock(wx: number, wy: number, wz: number, id: number): boolean {
    if (wy < 0 || wy > 255) return false;
    const cx = worldToChunk(wx);
    const cz = worldToChunk(wz);
    const chunk = this.chunks.get(chunkKey(cx, cz));
    if (!chunk) return false;
    const lx = worldToLocal(wx);
    const lz = worldToLocal(wz);
    if (chunk.getBlock(lx, wy, lz) === id) return true;
    chunk.setBlock(lx, wy, lz, id);
    chunk.modified = true;
    this.queueSave(chunk);
    this.requestMesh(cx, cz);
    if (lx === 0) this.requestMeshIfLoaded(cx - 1, cz);
    if (lx === CHUNK_SIZE_X - 1) this.requestMeshIfLoaded(cx + 1, cz);
    if (lz === 0) this.requestMeshIfLoaded(cx, cz - 1);
    if (lz === CHUNK_SIZE_Z - 1) this.requestMeshIfLoaded(cx, cz + 1);
    return true;
  }

  private requestMeshIfLoaded(cx: number, cz: number): void {
    if (this.chunks.has(chunkKey(cx, cz))) this.requestMesh(cx, cz);
  }

  // -- persistence -----------------------------------------------------------

  private queueSave(chunk: Chunk): void {
    this.dirty.add(chunkKey(chunk.cx, chunk.cz));
    if (this.saveTimer) return;
    this.saveTimer = setTimeout(() => {
      this.saveTimer = null;
      void this.flush();
    }, SAVE_DEBOUNCE_MS);
  }

  /** Persist all dirty chunks in one transaction. Call on pagehide too. */
  async flush(): Promise<void> {
    if (this.dirty.size === 0) return;
    const records: StoredChunk[] = [];
    for (const key of this.dirty) {
      const chunk = this.chunks.get(key);
      if (!chunk) continue;
      records.push({
        worldId: this.worldId,
        cx: chunk.cx,
        cz: chunk.cz,
        version: CHUNK_FORMAT_VERSION,
        blocks: chunk.blocks.slice().buffer,
      });
    }
    this.dirty.clear();
    if (records.length) await this.store.putChunks(records);
  }

  /** Update time-of-day lighting on all chunk meshes (one uniform write). */
  setDay(dayFactor: number, ambient: number, tint: THREE.Color): void {
    this.materials.setDay(dayFactor, ambient, tint);
  }

  get loadedCount(): number {
    return this.chunks.size;
  }

  dispose(): void {
    if (this.saveTimer) clearTimeout(this.saveTimer);
    this.worker.terminate();
    for (const m of this.meshes.values()) this.disposeMeshes(m);
    this.meshes.clear();
    this.chunks.clear();
    this.scene.remove(this.group);
  }
}
