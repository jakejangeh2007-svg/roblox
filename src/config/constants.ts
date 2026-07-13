/**
 * Global tunables. Everything gameplay-critical lives here so later steps
 * (worker world-gen, physics, lighting) share one source of truth — the
 * worker imports from this module too, so main thread and worker can never
 * disagree about chunk geometry.
 */

// ---------------------------------------------------------------------------
// Chunk geometry
// ---------------------------------------------------------------------------
export const CHUNK_SIZE_X = 16;
export const CHUNK_SIZE_Y = 256;
export const CHUNK_SIZE_Z = 16;
export const BLOCKS_PER_CHUNK = CHUNK_SIZE_X * CHUNK_SIZE_Y * CHUNK_SIZE_Z;

/** Bedrock floor. */
export const WORLD_MIN_Y = 0;
export const WORLD_MAX_Y = CHUNK_SIZE_Y - 1;
/** Baseline terrain height around which noise oscillates (Minecraft sea level). */
export const SEA_LEVEL = 63;

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------
/** Chunk-columns radius streamed around the player (adaptive later). */
export const RENDER_DISTANCE_MOBILE = 4;
export const RENDER_DISTANCE_DESKTOP = 8;
/** Cap devicePixelRatio: >2 is invisible on phones but quadruples fill cost. */
export const MAX_PIXEL_RATIO = 2;
export const CAMERA_FOV = 70;
export const CAMERA_NEAR = 0.1;
export const CAMERA_FAR = 1000;

// ---------------------------------------------------------------------------
// Simulation timing
// ---------------------------------------------------------------------------
/** Fixed physics timestep (Hz). Rendering is uncapped; physics is deterministic. */
export const TICK_RATE = 60;
export const TICK_DT = 1 / TICK_RATE;
/** Max physics steps per frame before we drop time (background-tab recovery). */
export const MAX_TICKS_PER_FRAME = 5;
/** Full day/night cycle: 20 minutes, as in Minecraft. */
export const DAY_LENGTH_SECONDS = 20 * 60;

// ---------------------------------------------------------------------------
// Player physics (units: blocks, seconds) — Minecraft-equivalent values
// ---------------------------------------------------------------------------
export const GRAVITY = -32;
export const TERMINAL_VELOCITY = -78;
export const PLAYER_WIDTH = 0.6;
export const PLAYER_HEIGHT = 1.8;
export const PLAYER_EYE_HEIGHT = 1.62;
export const WALK_SPEED = 4.317;
export const SPRINT_SPEED = 5.612;
export const SNEAK_SPEED = 1.295;
export const JUMP_VELOCITY = 9.0;
/** Fall damage: half-hearts per block fallen beyond this. */
export const SAFE_FALL_BLOCKS = 3;

// ---------------------------------------------------------------------------
// Interaction
// ---------------------------------------------------------------------------
export const REACH_DISTANCE = 5;
/** Hold duration that distinguishes "mine" from "place" on touch. */
export const TOUCH_HOLD_MS = 300;
/** Movement (px) beyond which a touch becomes a camera drag, not a tap. */
export const TOUCH_SLOP_PX = 12;

// ---------------------------------------------------------------------------
// Persistence
// ---------------------------------------------------------------------------
export const DB_NAME = 'voxelcraft';
export const DB_VERSION = 1;
/** Debounce for batching dirty-chunk writes into one transaction. */
export const SAVE_DEBOUNCE_MS = 3000;
