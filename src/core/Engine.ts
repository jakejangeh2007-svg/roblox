/**
 * Rendering core: WebGL renderer, camera, scene, fixed-timestep game loop.
 *
 * Mobile decisions baked in here:
 *  - antialias off (MSAA is a fill-rate killer on tile GPUs; voxel art
 *    doesn't need it), pixel ratio capped at 2.
 *  - Physics runs on a fixed 60 Hz accumulator so simulation stays
 *    deterministic when the display is 120 Hz (iPhone ProMotion) or when
 *    frames drop; rendering interpolation can be added per-entity later.
 *  - Loop pauses on document hide to save battery; the time accumulator
 *    clamps so returning from background doesn't fast-forward the world.
 */
import * as THREE from 'three';
import {
  CAMERA_FAR,
  CAMERA_FOV,
  CAMERA_NEAR,
  MAX_PIXEL_RATIO,
  MAX_TICKS_PER_FRAME,
  TICK_DT,
} from '../config/constants';

export interface EngineHooks {
  /** Fixed-timestep simulation update (dt is always TICK_DT). */
  update(dt: number): void;
  /** Per-frame, after updates, before draw. alpha = accumulator fraction. */
  render(alpha: number, frameDt: number): void;
}

export class Engine {
  readonly renderer: THREE.WebGLRenderer;
  readonly scene: THREE.Scene;
  readonly camera: THREE.PerspectiveCamera;

  private hooks: EngineHooks | null = null;
  private rafId = 0;
  private running = false;
  private lastTime = 0;
  private accumulator = 0;

  /** Rolling FPS estimate for the debug overlay. */
  fps = 0;
  private fpsFrames = 0;
  private fpsWindowStart = 0;

  constructor(readonly canvas: HTMLCanvasElement) {
    this.renderer = new THREE.WebGLRenderer({
      canvas,
      antialias: false,
      powerPreference: 'high-performance',
      stencil: false,
    });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, MAX_PIXEL_RATIO));
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;

    this.scene = new THREE.Scene();
    this.camera = new THREE.PerspectiveCamera(
      CAMERA_FOV,
      window.innerWidth / window.innerHeight,
      CAMERA_NEAR,
      CAMERA_FAR,
    );

    this.handleResize();
    window.addEventListener('resize', this.handleResize);
    // iOS fires orientationchange before layout settles; resize again after.
    window.addEventListener('orientationchange', () => setTimeout(this.handleResize, 250));
    document.addEventListener('visibilitychange', this.handleVisibility);
  }

  setHooks(hooks: EngineHooks): void {
    this.hooks = hooks;
  }

  start(): void {
    if (this.running) return;
    this.running = true;
    this.lastTime = performance.now();
    this.fpsWindowStart = this.lastTime;
    this.rafId = requestAnimationFrame(this.frame);
  }

  stop(): void {
    this.running = false;
    cancelAnimationFrame(this.rafId);
  }

  dispose(): void {
    this.stop();
    window.removeEventListener('resize', this.handleResize);
    document.removeEventListener('visibilitychange', this.handleVisibility);
    this.renderer.dispose();
  }

  private frame = (now: number): void => {
    if (!this.running) return;
    this.rafId = requestAnimationFrame(this.frame);

    let frameDt = (now - this.lastTime) / 1000;
    this.lastTime = now;
    // Clamp huge gaps (tab was hidden / debugger paused) instead of spiralling.
    if (frameDt > MAX_TICKS_PER_FRAME * TICK_DT) frameDt = MAX_TICKS_PER_FRAME * TICK_DT;

    this.accumulator += frameDt;
    let steps = 0;
    while (this.accumulator >= TICK_DT && steps < MAX_TICKS_PER_FRAME) {
      this.hooks?.update(TICK_DT);
      this.accumulator -= TICK_DT;
      steps++;
    }

    this.hooks?.render(this.accumulator / TICK_DT, frameDt);
    this.renderer.render(this.scene, this.camera);

    this.fpsFrames++;
    const windowMs = now - this.fpsWindowStart;
    if (windowMs >= 500) {
      this.fps = (this.fpsFrames * 1000) / windowMs;
      this.fpsFrames = 0;
      this.fpsWindowStart = now;
    }
  };

  private handleResize = (): void => {
    const w = window.innerWidth;
    const h = window.innerHeight;
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, MAX_PIXEL_RATIO));
    this.renderer.setSize(w, h, false);
  };

  private handleVisibility = (): void => {
    if (document.hidden) {
      this.stop();
    } else {
      this.start();
    }
  };
}
