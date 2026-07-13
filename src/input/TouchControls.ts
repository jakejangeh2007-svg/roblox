/**
 * Touch input: a floating virtual joystick on the left, action buttons on the
 * right, and drag-to-look everywhere else. A single gesture arbiter routes each
 * touch by where it began:
 *   - on a button element  → that button owns it
 *   - left ~45% of screen  → joystick (movement); double-tap to sprint
 *   - elsewhere            → camera look-drag, plus tap/hold classification
 *     whose flags (primaryPressed / mining) are consumed by interaction (Step 4)
 *
 * Multi-touch is fully supported: move + look + jump simultaneously, each on its
 * own tracked touch identifier.
 */
import { TOUCH_HOLD_MS, TOUCH_SLOP_PX } from '../config/constants';
import type { InputState } from './InputState';

const LOOK_SENSITIVITY = 0.0042; // radians per pixel
const JOYSTICK_RADIUS = 52;
const SPRINT_DOUBLE_TAP_MS = 300;

interface TrackedLook {
  id: number;
  startX: number;
  startY: number;
  lastX: number;
  lastY: number;
  startTime: number;
  moved: boolean;
  holdFired: boolean;
}

export class TouchControls {
  private joystickId = -1;
  private joystickOX = 0;
  private joystickOY = 0;
  private lastJoystickStart = 0;
  private sprintLatched = false;

  private look: TrackedLook | null = null;

  private readonly base: HTMLDivElement;
  private readonly knob: HTMLDivElement;
  private readonly btnSneak: HTMLDivElement;
  private sneakToggled = false;
  private jumpHeld = false;

  private holdTimer: ReturnType<typeof setTimeout> | null = null;

  constructor(
    private readonly hud: HTMLElement,
    private readonly input: InputState,
  ) {
    this.base = this.el('div', 'joystick-base');
    this.knob = this.el('div', 'joystick-knob');
    hud.append(this.base, this.knob);

    const btnJump = this.button('btn-jump', '⤒');
    this.btnSneak = this.button('btn-sneak', '⇩');
    const btnAction = this.button('btn-action', '✦');

    // Jump: held.
    this.holdButton(btnJump, (down) => {
      this.jumpHeld = down;
      this.input.jump = down;
    });
    // Sneak: toggle.
    this.btnSneak.addEventListener('touchstart', (e) => {
      e.preventDefault();
      e.stopPropagation();
      this.sneakToggled = !this.sneakToggled;
      this.input.sneak = this.sneakToggled;
      this.btnSneak.classList.toggle('toggled', this.sneakToggled);
    });
    // Action / place: edge-triggered press (Step 4 consumes primaryPressed).
    this.holdButton(btnAction, (down) => {
      if (down) this.input.primaryPressed = true;
    });

    // World touches (joystick + look) are captured on window, not on #hud:
    // the HUD layer is pointer-events:none so its touches fall through to the
    // canvas. Buttons stopPropagation, so their touches never reach here.
    window.addEventListener('touchstart', this.onTouchStart, { passive: false });
    window.addEventListener('touchmove', this.onTouchMove, { passive: false });
    window.addEventListener('touchend', this.onTouchEnd, { passive: false });
    window.addEventListener('touchcancel', this.onTouchEnd, { passive: false });
  }

  private el(tag: string, cls: string): HTMLDivElement {
    const d = document.createElement(tag) as HTMLDivElement;
    d.className = cls;
    return d;
  }

  private button(id: string, label: string): HTMLDivElement {
    const b = this.el('div', 'touch-btn touch-only');
    b.id = id;
    b.textContent = label;
    this.hud.appendChild(b);
    return b;
  }

  private holdButton(el: HTMLElement, cb: (down: boolean) => void): void {
    el.addEventListener('touchstart', (e) => {
      e.preventDefault();
      e.stopPropagation();
      cb(true);
    });
    const up = (e: Event): void => {
      e.preventDefault();
      e.stopPropagation();
      cb(false);
    };
    el.addEventListener('touchend', up);
    el.addEventListener('touchcancel', up);
  }

  private isLeftZone(x: number): boolean {
    return x < window.innerWidth * 0.45;
  }

  private onTouchStart = (e: TouchEvent): void => {
    e.preventDefault();
    for (const t of Array.from(e.changedTouches)) {
      if (this.joystickId === -1 && this.isLeftZone(t.clientX)) {
        this.joystickId = t.identifier;
        this.joystickOX = t.clientX;
        this.joystickOY = t.clientY;
        this.showJoystick(t.clientX, t.clientY);
        this.updateJoystick(t.clientX, t.clientY);
        // Double-tap → sprint latch.
        const now = performance.now();
        if (now - this.lastJoystickStart < SPRINT_DOUBLE_TAP_MS) this.sprintLatched = true;
        this.lastJoystickStart = now;
      } else if (!this.look) {
        this.look = {
          id: t.identifier,
          startX: t.clientX,
          startY: t.clientY,
          lastX: t.clientX,
          lastY: t.clientY,
          startTime: performance.now(),
          moved: false,
          holdFired: false,
        };
        // Hold-to-mine: after TOUCH_HOLD_MS without moving, latch mining.
        this.holdTimer = setTimeout(() => {
          if (this.look && !this.look.moved) {
            this.look.holdFired = true;
            this.input.mining = true;
          }
        }, TOUCH_HOLD_MS);
      }
    }
  };

  private onTouchMove = (e: TouchEvent): void => {
    e.preventDefault();
    for (const t of Array.from(e.changedTouches)) {
      if (t.identifier === this.joystickId) {
        this.updateJoystick(t.clientX, t.clientY);
      } else if (this.look && t.identifier === this.look.id) {
        const dx = t.clientX - this.look.lastX;
        const dy = t.clientY - this.look.lastY;
        this.look.lastX = t.clientX;
        this.look.lastY = t.clientY;
        const distFromStart = Math.hypot(t.clientX - this.look.startX, t.clientY - this.look.startY);
        if (distFromStart > TOUCH_SLOP_PX) this.look.moved = true;
        this.input.lookYaw += dx * LOOK_SENSITIVITY;
        this.input.lookPitch += dy * LOOK_SENSITIVITY;
      }
    }
  };

  private onTouchEnd = (e: TouchEvent): void => {
    e.preventDefault();
    for (const t of Array.from(e.changedTouches)) {
      if (t.identifier === this.joystickId) {
        this.joystickId = -1;
        this.sprintLatched = false;
        this.input.moveX = 0;
        this.input.moveZ = 0;
        this.input.sprint = false;
        this.hideJoystick();
      } else if (this.look && t.identifier === this.look.id) {
        if (this.holdTimer) {
          clearTimeout(this.holdTimer);
          this.holdTimer = null;
        }
        // Quick tap without movement or hold → primary action (place / use).
        const dt = performance.now() - this.look.startTime;
        if (!this.look.moved && !this.look.holdFired && dt < TOUCH_HOLD_MS) {
          this.input.primaryPressed = true;
        }
        this.input.mining = false;
        this.look = null;
      }
    }
  };

  private showJoystick(x: number, y: number): void {
    this.base.style.left = `${x}px`;
    this.base.style.top = `${y}px`;
    this.base.classList.add('active');
    this.knob.classList.add('active');
  }

  private hideJoystick(): void {
    this.base.classList.remove('active');
    this.knob.classList.remove('active');
  }

  private updateJoystick(x: number, y: number): void {
    let dx = x - this.joystickOX;
    let dy = y - this.joystickOY;
    const dist = Math.hypot(dx, dy);
    if (dist > JOYSTICK_RADIUS) {
      dx = (dx / dist) * JOYSTICK_RADIUS;
      dy = (dy / dist) * JOYSTICK_RADIUS;
    }
    this.knob.style.left = `${this.joystickOX + dx}px`;
    this.knob.style.top = `${this.joystickOY + dy}px`;

    this.input.moveX = dx / JOYSTICK_RADIUS;
    this.input.moveZ = -dy / JOYSTICK_RADIUS; // up = forward
    // Sprint only when latched AND pushed forward.
    this.input.sprint = this.sprintLatched && this.input.moveZ > 0.5;
  }

  /** Whether jump is currently held (for HUD state / debugging). */
  get isJumping(): boolean {
    return this.jumpHeld;
  }

  dispose(): void {
    if (this.holdTimer) clearTimeout(this.holdTimer);
  }
}
