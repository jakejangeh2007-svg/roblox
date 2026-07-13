/**
 * Boot sequence: open persistence → create/resume world → start renderer.
 *
 * Step 1 scope: the scene contains a placeholder ground plane and a slowly
 * orbiting camera to prove the render loop, resize handling, and IndexedDB
 * round-trip. Steps 2+ replace the placeholder with worker-generated chunks.
 */
import * as THREE from 'three';
import { Engine } from './core/Engine';
import { WorldStore, type WorldMeta } from './storage/WorldStore';
import { SEA_LEVEL } from './config/constants';

const DEFAULT_WORLD_ID = 'default';
const DAY_SKY = new THREE.Color(0x78a7ff);

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
    timeOfDay: 0.25, // start at sunrise
  }));

  // Mobile Safari can kill the tab without beforeunload; flush on pagehide.
  const flush = (): void => {
    world.lastPlayed = Date.now();
    void store.putWorld(world);
  };
  window.addEventListener('pagehide', flush);
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) flush();
  });

  // --- Renderer -------------------------------------------------------------
  const engine = new Engine(canvas);
  engine.scene.background = DAY_SKY;
  engine.scene.fog = new THREE.Fog(DAY_SKY, 60, 140);

  // Placeholder content until Step 2's chunk meshes arrive: a grass-colored
  // ground slab and a grid so camera motion is visible.
  const ground = new THREE.Mesh(
    new THREE.BoxGeometry(160, 1, 160),
    new THREE.MeshLambertMaterial({ color: 0x7cbd6b }),
  );
  ground.position.set(0, SEA_LEVEL - 0.5, 0);
  engine.scene.add(ground);

  const grid = new THREE.GridHelper(160, 160, 0x446644, 0x558855);
  grid.position.y = SEA_LEVEL + 0.01;
  engine.scene.add(grid);

  const marker = new THREE.Mesh(
    new THREE.BoxGeometry(1, 1, 1),
    new THREE.MeshLambertMaterial({ color: 0x9a6b4f }),
  );
  marker.position.set(0, SEA_LEVEL + 0.5, 0);
  engine.scene.add(marker);

  const sun = new THREE.DirectionalLight(0xffffff, 2.2);
  sun.position.set(0.5, 1, 0.3);
  engine.scene.add(sun, new THREE.AmbientLight(0xbfd4ff, 0.7));

  // --- Loop -------------------------------------------------------------------
  let elapsed = 0;
  engine.setHooks({
    update(dt) {
      elapsed += dt;
    },
    render() {
      // Slow orbit around the marker block until player controls exist (Step 3).
      const a = elapsed * 0.15;
      engine.camera.position.set(Math.sin(a) * 14, SEA_LEVEL + 6, Math.cos(a) * 14);
      engine.camera.lookAt(0, SEA_LEVEL + 1, 0);

      debugEl.textContent =
        `Voxelcraft dev — step 1/6\n` +
        `fps ${engine.fps.toFixed(0)}  dpr ${engine.renderer.getPixelRatio()}\n` +
        `world "${world.name}" seed ${world.seed}`;
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
