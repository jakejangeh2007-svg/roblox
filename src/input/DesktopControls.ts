/**
 * Desktop input parity: WASD/arrows move, Space jumps, Shift sneaks, Ctrl (or
 * double-tap W) sprints, mouse look via Pointer Lock. Left mouse = mine (held),
 * right mouse = place (edge). Writes into the same InputState as touch, so the
 * Player is device-agnostic.
 */
import type { InputState } from './InputState';

const MOUSE_SENSITIVITY = 0.0025;

export class DesktopControls {
  private readonly keys = new Set<string>();
  private lastForwardTap = 0;
  private sprintLatched = false;
  private locked = false;

  constructor(
    private readonly canvas: HTMLElement,
    private readonly input: InputState,
  ) {
    window.addEventListener('keydown', this.onKeyDown);
    window.addEventListener('keyup', this.onKeyUp);
    canvas.addEventListener('mousedown', this.onMouseDown);
    window.addEventListener('mouseup', this.onMouseUp);
    document.addEventListener('mousemove', this.onMouseMove);
    document.addEventListener('pointerlockchange', this.onLockChange);
    canvas.addEventListener('contextmenu', (e) => e.preventDefault());
  }

  private requestLock(): void {
    if (!this.locked) void this.canvas.requestPointerLock();
  }

  private onLockChange = (): void => {
    this.locked = document.pointerLockElement === this.canvas;
    if (!this.locked) {
      // Dropping lock (Esc) should stop movement so the player doesn't drift.
      this.keys.clear();
      this.syncMovement();
      this.input.mining = false;
    }
  };

  private onKeyDown = (e: KeyboardEvent): void => {
    if (e.repeat) return;
    const code = e.code;
    this.keys.add(code);
    if (code === 'KeyW') {
      const now = performance.now();
      if (now - this.lastForwardTap < 300) this.sprintLatched = true;
      this.lastForwardTap = now;
    }
    if (code === 'Space') e.preventDefault();
    this.syncMovement();
  };

  private onKeyUp = (e: KeyboardEvent): void => {
    this.keys.delete(e.code);
    if (e.code === 'KeyW') this.sprintLatched = false;
    this.syncMovement();
  };

  private syncMovement(): void {
    const k = this.keys;
    let x = 0;
    let z = 0;
    if (k.has('KeyW') || k.has('ArrowUp')) z += 1;
    if (k.has('KeyS') || k.has('ArrowDown')) z -= 1;
    if (k.has('KeyD') || k.has('ArrowRight')) x += 1;
    if (k.has('KeyA') || k.has('ArrowLeft')) x -= 1;
    this.input.moveX = x;
    this.input.moveZ = z;
    this.input.jump = k.has('Space');
    this.input.sneak = k.has('ShiftLeft') || k.has('ShiftRight');
    this.input.sprint =
      (this.sprintLatched || k.has('ControlLeft') || k.has('ControlRight')) && z > 0;
  }

  private onMouseDown = (e: MouseEvent): void => {
    if (!this.locked) {
      this.requestLock();
      return;
    }
    if (e.button === 0) {
      this.input.mining = true;
    } else if (e.button === 2) {
      this.input.primaryPressed = true;
      this.input.using = true;
    }
  };

  private onMouseUp = (e: MouseEvent): void => {
    if (e.button === 0) this.input.mining = false;
    else if (e.button === 2) this.input.using = false;
  };

  private onMouseMove = (e: MouseEvent): void => {
    if (!this.locked) return;
    this.input.lookYaw += e.movementX * MOUSE_SENSITIVITY;
    this.input.lookPitch += e.movementY * MOUSE_SENSITIVITY;
  };

  dispose(): void {
    window.removeEventListener('keydown', this.onKeyDown);
    window.removeEventListener('keyup', this.onKeyUp);
    document.removeEventListener('mousemove', this.onMouseMove);
    document.removeEventListener('pointerlockchange', this.onLockChange);
  }
}
