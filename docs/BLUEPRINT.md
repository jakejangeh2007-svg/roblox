# Voxelcraft — System Blueprint

A 1:1 web-based recreation of Minecraft Survival Mode, mobile-first, targeting 60 fps
in iOS/Android Safari & Chrome and on desktop browsers.

---

## 1. Tech Stack

| Concern          | Choice                                   | Rationale                                                        |
| ---------------- | ---------------------------------------- | ---------------------------------------------------------------- |
| Language         | TypeScript (strict)                      | Type safety across worker boundaries, zero runtime cost          |
| Rendering        | Three.js (thin usage: raw `BufferGeometry`, custom `ShaderMaterial`s) | WebGL abstraction without engine overhead |
| Bundler/dev      | Vite                                     | Native ESM dev server, first-class Web Worker + module support    |
| Persistence      | IndexedDB (custom promise wrapper, no dependency) | Massive world storage; transactional chunk writes       |
| Threading        | Dedicated Web Worker (terrain gen + meshing), transferable `ArrayBuffer`s | Main thread never blocks on chunk loading |
| Testing          | Vitest + fake-indexeddb                  | Fast unit tests for pure logic + storage layer                    |
| Linting          | ESLint (typescript-eslint, flat config)  | CI-enforceable validation gate                                    |

No frameworks. DOM/CSS for the HUD (cheaper and crisper than in-canvas UI, and it
composites on its own layer on mobile GPUs).

## 2. Repository Structure

```
/
├── index.html                  # Mobile viewport, safe-area, canvas + HUD roots
├── package.json
├── tsconfig.json
├── vite.config.ts
├── eslint.config.js
├── docs/
│   └── BLUEPRINT.md            # This document
├── public/                     # (later) texture atlas png
└── src/
    ├── main.ts                 # Boot: storage → engine → (later) world, input, UI
    ├── config/
    │   └── constants.ts        # Chunk dims, physics, timing, world-gen tunables
    ├── core/
    │   ├── Engine.ts           # WebGLRenderer, camera, scene, resize, RAF loop
    │   └── math.ts             # Coord helpers: world↔chunk↔local, key packing
    ├── storage/
    │   ├── Database.ts         # Promise-based IndexedDB wrapper (open/tx/migrate)
    │   └── WorldStore.ts       # chunks / player / tileEntities / meta stores
    ├── world/                  # Step 2+
    │   ├── Block.ts            # Block registry: id, hardness, tool, light, drops
    │   ├── Chunk.ts            # 16×256×16 Uint8Array column + dirty flags
    │   ├── ChunkManager.ts     # Load/unload ring around player, worker dispatch
    │   ├── mesher.ts           # Greedy/culled meshing → interleaved buffers
    │   └── workers/
    │       ├── genWorker.ts    # Terrain gen + meshing off-thread
    │       ├── noise.ts        # Simplex noise (deterministic, seeded)
    │       └── protocol.ts     # Typed messages, transferable buffers
    ├── player/                 # Step 3+
    │   ├── Player.ts           # State: position, velocity, health, hunger
    │   └── physics.ts          # AABB sweep vs voxels, gravity, fall damage
    ├── input/                  # Step 3+
    │   ├── TouchControls.ts    # Joystick, look-drag, buttons, tap/hold routing
    │   └── DesktopControls.ts  # Pointer-lock + WASD parity
    ├── interact/               # Step 4+
    │   ├── raycast.ts          # Voxel DDA traversal
    │   └── mining.ts           # Break progress, tool speed, crack overlay
    ├── items/                  # Step 5+
    │   ├── Item.ts             # Item registry, tools, durability, stacking
    │   ├── recipes.ts          # 2×2 / 3×3 shaped + shapeless recipes
    │   └── ItemDrop.ts         # Spinning 3D drops, magnetize, merge
    ├── ui/                     # Step 5+
    │   ├── Hotbar.ts
    │   ├── InventoryScreen.ts  # Full-screen inventory + crafting + armor
    │   └── StatusBars.ts       # Hearts, shanks, air bubbles
    └── sim/                    # Step 6
        ├── DayNight.ts         # 20-min cycle, sky shader, sun/moon transform
        ├── lighting.ts         # BFS sky + block light (4-bit each, packed)
        └── tileEntities/       # Furnace, Chest, CraftingTable behaviors
```

## 3. Core Architecture Decisions

### 3.1 Data model
- **Chunk column**: `16×256×16` blocks, stored as a flat `Uint8Array(65536)`
  indexed `(y << 8) | (z << 4) | x` — Y-major so vertical runs (gen, lighting)
  are cache-friendly. One byte per block = 256 block types (enough; can widen
  to Uint16 later without format changes thanks to a `version` field per record).
- **Light**: a parallel `Uint8Array(65536)` — low nibble block light, high
  nibble sky light.
- **Chunk key**: `"cx,cz"` string in IndexedDB; packed 32-bit int in hot maps.

### 3.2 Threading model
- Main thread: rendering, input, physics, UI, light *application*.
- `genWorker`: seeded noise terrain, caves, ores, trees → returns block buffer
  (transferable). Also runs remeshing: main thread sends the chunk + neighbor
  edge slices, worker returns vertex/index buffers (transferable). Zero copies.
- Block *edits* apply instantly main-side to a local copy for responsiveness,
  then the worker remeshes; a dirty-chunk queue in WorldStore batches saves.

### 3.3 Persistence (IndexedDB)
Database `voxelcraft`, versioned migrations:
- `worlds` — world metadata: seed, name, createdAt, lastPlayed, timeOfDay.
- `chunks` — key `[worldId, cx, cz]` → `{ version, blocks: ArrayBuffer }`.
  Only chunks *modified from procedural output* are stored; pristine chunks
  regenerate from seed (this is what makes "endless" storage feasible).
- `players` — key `worldId` → position, look, inventory, health, hunger.
- `tileEntities` — key `[worldId, cx, cz, index]` → chest/furnace state.

Writes are debounced and batched in a single transaction per save tick;
`visibilitychange`/`pagehide` triggers a flush (mobile Safari kills tabs
without warning).

### 3.4 Rendering budget (mobile 60 fps)
- One draw call per chunk mesh (opaque) + one (transparent: water/leaves).
- `renderer.setPixelRatio(min(devicePixelRatio, 2))`, antialias **off**,
  `powerPreference: "high-performance"`.
- Single 16×16-tile texture atlas, `NearestFilter`, mipmaps with clamped LOD
  bias to avoid bleeding.
- Frustum culling per chunk (Three does this per-mesh via bounding boxes);
  additionally skip meshing fully-occluded chunks.
- Vertex data interleaved & quantized: position bytes, packed normal/AO/light
  in one attribute; target ≤ 24 bytes/vertex.
- No per-frame allocations in the loop; object pools for vectors and AABBs.

### 3.5 Input routing (touch)
A single gesture arbiter owns all touches and classifies them:
- Touch begins on HUD element → owned by that control (joystick, button).
- Otherwise it's a *world* touch: movement > slop ⇒ camera look-drag;
  hold ≥ 300 ms without moving ⇒ mining (progress scales with tool);
  release < 300 ms without moving ⇒ tap ⇒ place/interact.
- Double-tap joystick-forward ⇒ sprint latch. Multi-touch is fully supported
  (look while moving while jumping).

## 4. Game Systems (summary of later steps)

- **World gen** (Step 2): 2-D simplex fractal for continentalness/erosion →
  height; biome from temperature/moisture noise (Desert/Plains/Forest/Hills);
  3-D noise carves caves to bedrock at Y=0; ore veins by depth —
  coal Y5–52 (up to ~128 in mountains), iron Y5–64, gold Y5–32, diamond Y5–16.
- **Physics** (Step 3): swept AABB vs voxel grid, gravity −32 m/s²,
  terminal −78 m/s, fall damage `max(0, blocksFallen − 3)` half-hearts.
- **Mining/placing** (Step 4): voxel DDA raycast (≤ 5 blocks), crack-stage
  decal, hardness ÷ tool multiplier (wood 2×, stone 4×, iron 6×, diamond 8×).
- **Inventory/crafting** (Step 5): 36 slots + hotbar mirror + armor + offhand;
  shaped/shapeless recipe matcher shared by 2×2 and 3×3 grids.
- **Survival sim** (Step 6): 20-min day cycle driving sky-light level 15→4;
  BFS flood-fill light with removal queues; hunger drains by exertion,
  regen ≥ 18/20 hunger; furnace smelts on real-time countdown persisted
  through save/load.

## 5. Iterative Plan & Validation Gates

Each step must pass: `npm run typecheck` && `npm run lint` && `npm test`
&& `npm run build` before the next begins.

1. ✅ **Boilerplate** — Vite+TS+Three scaffold, IndexedDB layer, renderer with
   day-sky clear color, placeholder ground grid, FPS/debug overlay.
2. ✅ **Worker world gen** — infinite chunk streaming, simplex terrain, biomes,
   caves, ores, culled meshing, frustum culling.
3. ✅ **Touch HUD + physics** — joystick, buttons, look-drag, AABB collisions,
   gravity, sprint/sneak/jump, fall damage.
4. ✅ **Break/place** — DDA raycast, hold-to-mine with crack animation, tap-to-place,
   tool-scaled break speed, block drops, durability.
5. ✅ **Inventory/crafting** — hotbar, full inventory screen, 2×2/3×3 crafting,
   tap-to-move item handling, tools & durability, physical magnetizing drops.
6. ✅ **Survival systems** — health/hunger with regen/starvation/eating,
   day/night cycle + sun/moon, sky+block voxel lighting via a light-aware chunk
   shader, torch propagation, furnace/chest/crafting-table tile entities,
   status bars, respawn.

All six steps complete. 115 unit tests; typecheck, lint, and production build
green; each step browser-verified under mobile emulation.
