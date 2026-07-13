/**
 * Boot sequence: open persistence → create/resume world → stream chunks →
 * spawn the player with physics + device-appropriate controls.
 *
 * Step 3 scope: first-person player with AABB collision, gravity, jump, sneak,
 * sprint and fall damage, driven by a virtual joystick + buttons on touch and
 * WASD + pointer-lock on desktop. Break/place raycasting arrives in Step 4.
 */
import './ui/styles.css';
import * as THREE from 'three';
import { Engine } from './core/Engine';
import { WorldStore, type WorldMeta } from './storage/WorldStore';
import { ChunkManager } from './world/ChunkManager';
import { TerrainGenerator } from './world/workers/terrain';
import { isSolid as blockIsSolid } from './world/Block';
import { defaultRenderDistance, isTouchDevice } from './core/device';
import { CHUNK_SIZE_Y } from './config/constants';
import { Player } from './player/Player';
import { createInputState } from './input/InputState';
import { TouchControls } from './input/TouchControls';
import { DesktopControls } from './input/DesktopControls';

const DEFAULT_WORLD_ID = 'default';
const DAY_SKY = new THREE.Color(0x8fb7ff);

async function boot(): Promise<void> {
  const canvas = document.getElementById('game-canvas') as HTMLCanvasElement | null;
  const hud = document.getElementById('hud');
  const debugEl = document.getElementById('debug-overlay');
  if (!canvas || !hud || !debugEl) throw new Error('Missing DOM roots');

  const touch = isTouchDevice();
  document.body.classList.toggle('touch', touch);
  buildStaticHud(hud);

  // --- Persistence ----------------------------------------------------------
  const store = await WorldStore.open();
  const world: WorldMeta = await store.openWorld(DEFAULT_WORLD_ID, () => ({
    name: 'New World',
    seed: (Math.random() * 0xffffffff) >>> 0,
    createdAt: Date.now(),
    lastPlayed: Date.now(),
    timeOfDay: 0.25,
  }));

  // --- Renderer + streaming -------------------------------------------------
  const engine = new Engine(canvas);
  engine.scene.background = DAY_SKY;
  const renderDistance = defaultRenderDistance();
  engine.scene.fog = new THREE.Fog(DAY_SKY, renderDistance * 12, renderDistance * 16 + 24);
  engine.scene.add(new THREE.AmbientLight(0xffffff, 1));

  const preview = new TerrainGenerator(world.seed);
  const chunks = new ChunkManager(engine.scene, store, world.worldId, world.seed, renderDistance);

  // --- Player (resume or spawn) --------------------------------------------
  const saved = await store.getPlayer(world.worldId);
  const spawnY = Math.min(CHUNK_SIZE_Y - 2, preview.heightAt(0, 0) + 2);
  const player = saved
    ? new Player({
        x: saved.position.x,
        y: saved.position.y,
        z: saved.position.z,
        yaw: saved.yaw,
        pitch: saved.pitch,
      })
    : new Player({ x: 0.5, y: spawnY, z: 0.5, yaw: 0, pitch: 0 });
  if (saved) {
    player.health = saved.health;
    player.hunger = saved.hunger;
  }

  const input = createInputState();
  // Constructing the controller wires its device listeners; we keep the handle
  // alive for the session (no teardown in this single-page app).
  const controls = touch
    ? new TouchControls(hud, input)
    : new DesktopControls(canvas, input);
  void controls;

  const isSolidAt = (x: number, y: number, z: number): boolean =>
    blockIsSolid(chunks.getBlock(x, y, z));

  // --- Save on hide/kill ----------------------------------------------------
  const flush = (): void => {
    world.lastPlayed = Date.now();
    void store.putWorld(world);
    void chunks.flush();
    void store.putPlayer({
      worldId: world.worldId,
      position: { x: player.position.x, y: player.position.y, z: player.position.z },
      yaw: player.yaw,
      pitch: player.pitch,
      health: player.health,
      hunger: player.hunger,
      selectedSlot: 0,
      inventory: [],
    });
  };
  window.addEventListener('pagehide', flush);
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) flush();
  });

  // --- Loop -----------------------------------------------------------------
  let physicsReady = false;
  let sinceSave = 0;
  engine.setHooks({
    update(dt) {
      chunks.update(player.position.x, player.position.z);
      // Hold the player until the spawn column exists, so we don't fall through
      // not-yet-generated terrain.
      if (!physicsReady) {
        if (chunks.isLoaded(player.position.x, player.position.z)) physicsReady = true;
        else return;
      }
      player.update(dt, input, isSolidAt);

      sinceSave += dt;
      if (sinceSave > 10) {
        sinceSave = 0;
        flush();
      }
    },
    render() {
      player.applyToCamera(engine.camera);
      const p = player.position;
      debugEl.textContent =
        `Voxelcraft dev — step 3/6\n` +
        `fps ${engine.fps.toFixed(0)}  chunks ${chunks.loadedCount}\n` +
        `xyz ${p.x.toFixed(1)} ${p.y.toFixed(1)} ${p.z.toFixed(1)}\n` +
        `hp ${player.health}/20  food ${player.hunger}/20  ` +
        `${player.onGround ? 'ground' : 'air'}${player.sprinting ? ' sprint' : ''}` +
        `${player.sneaking ? ' sneak' : ''}`;
    },
  });
  engine.start();

  // Dev-only handle for automated smoke tests and debugging; stripped in prod.
  if (import.meta.env.DEV) {
    (window as unknown as { __voxelcraft?: unknown }).__voxelcraft = {
      player,
      chunks,
      engine,
      teleport(x: number, y: number, z: number, yaw = 0, pitch = 0): void {
        player.position.set(x, y, z);
        player.velocity.set(0, 0, 0);
        player.yaw = yaw;
        player.pitch = pitch;
      },
    };
  }
}

function buildStaticHud(hud: HTMLElement): void {
  const crosshair = document.createElement('div');
  crosshair.id = 'crosshair';
  const hint = document.createElement('div');
  hint.id = 'desktop-hint';
  hint.textContent = 'Click to look · WASD move · Space jump · Shift sneak · double-W sprint';
  hud.append(crosshair, hint);
}

boot().catch((err: unknown) => {
  console.error(err);
  const el = document.getElementById('boot-error');
  if (el) {
    el.style.display = 'flex';
    el.textContent = `Failed to start: ${err instanceof Error ? err.message : String(err)}`;
  }
});
