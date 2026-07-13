/**
 * Boot sequence: open persistence → create/resume world → stream chunks →
 * spawn the player with physics, controls, inventory and block interaction.
 *
 * Step 4 scope: first-person player (Step 3) plus voxel-DDA raycasting for
 * hold-to-mine (tool-scaled, animated cracks) and tap/right-click placing, a
 * 9-slot hotbar, and a block-item inventory. Full inventory screen + crafting
 * arrive in Step 5.
 */
import './ui/styles.css';
import * as THREE from 'three';
import { Engine } from './core/Engine';
import { WorldStore, type WorldMeta, type ItemStackData } from './storage/WorldStore';
import { ChunkManager } from './world/ChunkManager';
import { TerrainGenerator } from './world/workers/terrain';
import { isSolid as blockIsSolid, BlockId } from './world/Block';
import { defaultRenderDistance, isTouchDevice } from './core/device';
import { CHUNK_SIZE_Y } from './config/constants';
import { Player } from './player/Player';
import { Inventory, type ItemStack } from './player/Inventory';
import { ItemId } from './items/Item';
import { createInputState } from './input/InputState';
import { TouchControls } from './input/TouchControls';
import { DesktopControls } from './input/DesktopControls';
import { Hotbar } from './ui/Hotbar';
import { BlockInteraction } from './interact/BlockInteraction';

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

  // --- Inventory (resume or starter kit) -----------------------------------
  const inventory = new Inventory();
  if (saved?.inventory?.length) {
    inventory.load(saved.inventory.map(fromStoredStack));
    inventory.selectedSlot = saved.selectedSlot ?? 0;
  } else {
    grantStarterKit(inventory);
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

  // --- HUD + interaction ----------------------------------------------------
  const hotbar = new Hotbar(hud, inventory);
  const interaction = new BlockInteraction(engine.scene, player, chunks, inventory);
  const breakBar = document.getElementById('break-progress') as HTMLDivElement | null;
  const breakFill = breakBar?.firstElementChild as HTMLDivElement | null;

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
      selectedSlot: inventory.selectedSlot,
      inventory: inventory.serialize().map(toStoredStack),
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
      interaction.update(dt, input);

      sinceSave += dt;
      if (sinceSave > 10) {
        sinceSave = 0;
        flush();
      }
    },
    render() {
      player.applyToCamera(engine.camera);
      hotbar.render();

      // Break-progress bar under the crosshair.
      if (breakBar && breakFill) {
        if (interaction.breakProgress > 0) {
          breakBar.style.display = 'block';
          breakFill.style.width = `${(interaction.breakProgress * 100).toFixed(0)}%`;
        } else {
          breakBar.style.display = 'none';
        }
      }

      const p = player.position;
      debugEl.textContent =
        `Voxelcraft dev — step 4/6\n` +
        `fps ${engine.fps.toFixed(0)}  chunks ${chunks.loadedCount}\n` +
        `xyz ${p.x.toFixed(1)} ${p.y.toFixed(1)} ${p.z.toFixed(1)}\n` +
        `hp ${player.health}/20  food ${player.hunger}/20  ` +
        `${player.onGround ? 'ground' : 'air'}${player.sprinting ? ' sprint' : ''}` +
        `${player.sneaking ? ' sneak' : ''}\n` +
        `held ${interaction.heldName()}  →  ${interaction.targetName}`;
    },
  });
  engine.start();

  // Dev-only handle for automated smoke tests and debugging; stripped in prod.
  if (import.meta.env.DEV) {
    (window as unknown as { __voxelcraft?: unknown }).__voxelcraft = {
      player,
      chunks,
      engine,
      inventory,
      interaction,
      input,
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
  const breakBar = document.createElement('div');
  breakBar.id = 'break-progress';
  breakBar.appendChild(document.createElement('div'));
  const hint = document.createElement('div');
  hint.id = 'desktop-hint';
  hint.textContent =
    'Click to look · WASD move · Space jump · L-click mine · R-click place · 1–9 select';
  hud.append(crosshair, breakBar, hint);
}

/** Convert between the runtime ItemStack ({item}) and stored form ({itemId}). */
function toStoredStack(s: ItemStack | null): ItemStackData | null {
  if (!s) return null;
  return s.durability === undefined
    ? { itemId: s.item, count: s.count }
    : { itemId: s.item, count: s.count, durability: s.durability };
}
function fromStoredStack(s: ItemStackData | null): ItemStack | null {
  if (!s) return null;
  return s.durability === undefined
    ? { item: s.itemId, count: s.count }
    : { item: s.itemId, count: s.count, durability: s.durability };
}

/** New players start with tools and some building blocks so they can play. */
function grantStarterKit(inv: Inventory): void {
  inv.slots[0] = { item: ItemId.StonePickaxe, count: 1 };
  inv.slots[1] = { item: ItemId.StoneAxe, count: 1 };
  inv.slots[2] = { item: ItemId.StoneShovel, count: 1 };
  inv.slots[3] = { item: BlockId.Cobblestone, count: 64 };
  inv.slots[4] = { item: BlockId.OakLog, count: 32 };
  inv.slots[5] = { item: BlockId.Planks, count: 64 };
  inv.slots[6] = { item: BlockId.Torch, count: 32 };
  inv.slots[7] = { item: BlockId.CraftingTable, count: 1 };
  inv.slots[8] = { item: BlockId.Glass, count: 32 };
  // Extra supplies in the main inventory.
  inv.slots[9] = { item: BlockId.Furnace, count: 1 };
  inv.slots[10] = { item: BlockId.Chest, count: 2 };
  inv.slots[11] = { item: BlockId.Dirt, count: 64 };
}

boot().catch((err: unknown) => {
  console.error(err);
  const el = document.getElementById('boot-error');
  if (el) {
    el.style.display = 'flex';
    el.textContent = `Failed to start: ${err instanceof Error ? err.message : String(err)}`;
  }
});
