/**
 * Boot sequence: open persistence → create/resume world → stream chunks.
 *
 * Step 2 scope: worker-driven infinite chunk generation renders around a spawn
 * point, with a slow fly-over camera so terrain, biomes, caves and trees are
 * visible. Step 3 replaces the fly-over with player controls + physics.
 */
import * as THREE from 'three';
import { Engine } from './core/Engine';
import { WorldStore, type WorldMeta } from './storage/WorldStore';
import { ChunkManager } from './world/ChunkManager';
import { TerrainGenerator } from './world/workers/terrain';
import { defaultRenderDistance } from './core/device';
import { CHUNK_SIZE_Y } from './config/constants';

const DEFAULT_WORLD_ID = 'default';
const DAY_SKY = new THREE.Color(0x8fb7ff);

async function boot(): Promise<void> {
  const canvas = document.getElementById('game-canvas') as HTMLCanvasElement | null;
  const debugEl = document.getElementById('debug-overlay');
  if (!canvas || !debugEl) throw new Error('Missing #game-canvas or #debug-overlay in DOM');

  // --- Persistence: open DB, create-or-resume the default world ------------
  const store = await WorldStore.open();
  const world: WorldMeta = await store.openWorld(DEFAULT_WORLD_ID, () => ({
    name: 'New World',
    seed: (Math.random() * 0xffffffff) >>> 0,
    createdAt: Date.now(),
    lastPlayed: Date.now(),
    timeOfDay: 0.25,
  }));

  // --- Renderer -------------------------------------------------------------
  const engine = new Engine(canvas);
  engine.scene.background = DAY_SKY;
  const renderDistance = defaultRenderDistance();
  engine.scene.fog = new THREE.Fog(DAY_SKY, renderDistance * 12, renderDistance * 16 + 24);

  // Compute a spawn surface height on the main thread (pure + cheap) so the
  // camera frames the terrain immediately.
  const preview = new TerrainGenerator(world.seed);
  const spawnY = Math.min(CHUNK_SIZE_Y - 4, preview.heightAt(0, 0) + 3);

  // --- Chunk streaming ------------------------------------------------------
  const chunks = new ChunkManager(engine.scene, store, world.worldId, world.seed, renderDistance);

  // Save on tab hide/kill (mobile Safari gives no beforeunload).
  const flush = (): void => {
    world.lastPlayed = Date.now();
    void store.putWorld(world);
    void chunks.flush();
  };
  window.addEventListener('pagehide', flush);
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) flush();
  });

  // --- Loop -------------------------------------------------------------------
  let elapsed = 0;
  engine.setHooks({
    update(dt) {
      elapsed += dt;
      chunks.update(0, 0); // spawn-centered streaming until player exists (Step 3)
    },
    render() {
      const a = elapsed * 0.08;
      const radius = renderDistance * 6;
      engine.camera.position.set(Math.sin(a) * radius, spawnY + 10, Math.cos(a) * radius);
      engine.camera.lookAt(0, spawnY - 4, 0);

      debugEl.textContent =
        `Voxelcraft dev — step 2/6\n` +
        `fps ${engine.fps.toFixed(0)}  dpr ${engine.renderer.getPixelRatio()}\n` +
        `chunks ${chunks.loadedCount}  rd ${renderDistance}\n` +
        `world "${world.name}" seed ${world.seed}  spawnY ${spawnY}`;
    },
  });
  engine.start();
}

boot().catch((err: unknown) => {
  console.error(err);
  const el = document.getElementById('boot-error');
  if (el) {
    el.style.display = 'flex';
    el.textContent = `Failed to start: ${err instanceof Error ? err.message : String(err)}`;
  }
});
