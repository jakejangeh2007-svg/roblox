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
import { InventoryScreen } from './ui/InventoryScreen';
import { ContainerScreen } from './ui/ContainerScreen';
import { StatusBars } from './ui/StatusBars';
import { BlockInteraction } from './interact/BlockInteraction';
import { ItemDropManager } from './world/ItemDropManager';
import { DayNight } from './sim/DayNight';
import { Survival } from './sim/Survival';
import {
  TileEntityManager,
  newChest,
  newFurnace,
  type ChestState,
  type FurnaceState,
} from './sim/tileEntities/TileEntities';

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
  const statusBars = new StatusBars(hud);
  const drops = new ItemDropManager(engine.scene, inventory, isSolidAt);
  const interaction = new BlockInteraction(engine.scene, player, chunks, inventory);
  const inventoryScreen = new InventoryScreen(hud, inventory);
  const containerScreen = new ContainerScreen(hud, inventory);

  // Survival + world simulation.
  const survival = new Survival();
  const tileEntities = new TileEntityManager(store, world.worldId);
  const dayNight = new DayNight(engine.scene, chunks, world.timeOfDay);

  const spillNearPlayer = (item: number, count: number): void =>
    drops.spawn(item, count, player.position.x, player.position.y + 1, player.position.z);

  // Mined blocks spawn physical, magnetizing 3D drops.
  interaction.onDrop = (item, count, x, y, z) => drops.spawn(item, count, x, y, z);
  inventoryScreen.onSpill = spillNearPlayer;
  containerScreen.onSpill = spillNearPlayer;

  // Breaking a chest/furnace returns the block and spills its stored contents.
  interaction.onBreak = (blockId, x, y, z) => {
    if (blockId === BlockId.Chest || blockId === BlockId.Furnace) {
      void tileEntities.remove(x, y, z).then((state) => {
        if (!state) return;
        if (state.kind === 'chest') {
          for (const s of state.slots) if (s) spillNearPlayer(s.item, s.count);
        } else {
          for (const s of [state.input, state.fuel, state.output]) {
            if (s) spillNearPlayer(s.item, s.count);
          }
        }
      });
    }
  };

  // Using an interactive block opens its screen instead of placing.
  interaction.onInteract = (blockId, x, y, z): boolean => {
    if (blockId === BlockId.CraftingTable) {
      openInventory(3);
      return true;
    }
    if (blockId === BlockId.Chest) {
      void tileEntities.getOrCreate(x, y, z, newChest).then((state) => {
        openContainer();
        containerScreen.showChest(state as ChestState, () => tileEntities.markDirty(x, y, z));
      });
      return true;
    }
    if (blockId === BlockId.Furnace) {
      void tileEntities.getOrCreate(x, y, z, newFurnace).then((state) => {
        openContainer();
        containerScreen.showFurnace(state as FurnaceState, () => tileEntities.markDirty(x, y, z));
      });
      return true;
    }
    return false;
  };

  const releaseControlsForUI = (): void => {
    if (document.pointerLockElement) document.exitPointerLock();
    input.mining = false;
    input.using = false;
    input.moveX = 0;
    input.moveZ = 0;
  };
  const openInventory = (width: 2 | 3): void => {
    releaseControlsForUI();
    inventoryScreen.show(width);
  };
  const openContainer = (): void => {
    releaseControlsForUI();
  };
  const anyScreenOpen = (): boolean => inventoryScreen.isOpen || containerScreen.isOpen;

  // Inventory open button (touch) + E/Tab (desktop).
  const invBtn = document.createElement('div');
  invBtn.id = 'btn-inventory';
  invBtn.className = 'touch-only';
  invBtn.textContent = '⋯';
  invBtn.addEventListener('touchstart', (e) => {
    e.preventDefault();
    e.stopPropagation();
    if (inventoryScreen.isOpen) inventoryScreen.close();
    else openInventory(2);
  });
  hud.appendChild(invBtn);
  window.addEventListener('keydown', (e) => {
    if (e.code === 'KeyE' || e.code === 'Tab') {
      e.preventDefault();
      if (containerScreen.isOpen) containerScreen.close();
      else if (inventoryScreen.isOpen) inventoryScreen.close();
      else openInventory(2);
    } else if (e.code === 'Escape') {
      if (containerScreen.isOpen) containerScreen.close();
      else if (inventoryScreen.isOpen) inventoryScreen.close();
    }
  });

  const breakBar = document.getElementById('break-progress') as HTMLDivElement | null;
  const breakFill = breakBar?.firstElementChild as HTMLDivElement | null;

  // --- Save on hide/kill ----------------------------------------------------
  const flush = (): void => {
    world.lastPlayed = Date.now();
    world.timeOfDay = dayNight.time;
    void store.putWorld(world);
    void chunks.flush();
    void tileEntities.flush();
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
  let eatTimer = 0;
  let wasOnGround = true;
  const EAT_TIME = 1.4;
  const spawnPoint = { x: 0.5, y: spawnY, z: 0.5 };

  engine.setHooks({
    update(dt) {
      chunks.update(player.position.x, player.position.z);
      // Hold the player until the spawn column exists, so we don't fall through
      // not-yet-generated terrain.
      if (!physicsReady) {
        if (chunks.isLoaded(player.position.x, player.position.z)) physicsReady = true;
        else return;
      }

      const uiOpen = anyScreenOpen();
      let blocksMined = 0;
      let jumped = false;

      if (!uiOpen) {
        // Eating: holding use/mine while a food item is selected consumes it.
        const heldDef = inventory.getSelectedDef();
        if (heldDef?.food && (input.using || input.mining) && player.hunger < player.maxHunger) {
          input.mining = false; // don't also break blocks while eating
          eatTimer += dt;
          if (eatTimer >= EAT_TIME) {
            eatTimer = 0;
            survival.eat(player, heldDef.food);
            inventory.consumeSelected(1);
          }
        } else {
          eatTimer = 0;
        }

        player.update(dt, input, isSolidAt);
        interaction.update(dt, input);

        if (interaction.minedThisTick) {
          interaction.minedThisTick = false;
          blocksMined = 1;
        }
        if (!player.onGround && wasOnGround) jumped = true;
        wasOnGround = player.onGround;

        survival.update(dt, player, {
          sprinting: player.sprinting,
          jumped,
          blocksMined,
        });

        // Respawn on death.
        if (player.health <= 0) {
          player.position.set(spawnPoint.x, spawnPoint.y, spawnPoint.z);
          player.velocity.set(0, 0, 0);
          player.health = player.maxHealth;
          player.hunger = Math.max(player.hunger, 10);
        }
      }

      drops.update(dt, player.position.x, player.position.y, player.position.z);
      tileEntities.update(dt);
      dayNight.update(dt, player.position);
      if (containerScreen.isOpen) containerScreen.update();

      sinceSave += dt;
      if (sinceSave > 10) {
        sinceSave = 0;
        flush();
      }
    },
    render() {
      player.applyToCamera(engine.camera);
      hotbar.render();
      statusBars.render(player);

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
      const clock = (dayNight.time * 24 + 6) % 24; // 0 phase = 6am
      debugEl.textContent =
        `Voxelcraft dev — step 6/6\n` +
        `fps ${engine.fps.toFixed(0)}  chunks ${chunks.loadedCount}  drops ${drops.count}\n` +
        `xyz ${p.x.toFixed(1)} ${p.y.toFixed(1)} ${p.z.toFixed(1)}  ` +
        `${String(Math.floor(clock)).padStart(2, '0')}:00 ${dayNight.isNight ? '🌙' : '☀'}\n` +
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
      inventoryScreen,
      containerScreen,
      drops,
      dayNight,
      survival,
      tileEntities,
      input,
      openInventory,
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
