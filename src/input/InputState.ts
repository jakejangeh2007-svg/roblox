/**
 * Shared control intent. Control sources (touch, keyboard) write into a single
 * InputState each frame; the Player reads it. Decoupling intent from device
 * means touch and desktop paths converge on one movement code path.
 */
export interface InputState {
  /** Strafe intent, -1 (left) .. +1 (right). */
  moveX: number;
  /** Forward intent, -1 (back) .. +1 (forward). */
  moveZ: number;
  jump: boolean;
  sneak: boolean;
  sprint: boolean;
  /** Accumulated look delta (radians) to apply this frame, then cleared. */
  lookYaw: number;
  lookPitch: number;
  /** Edge-triggered: a primary action press occurred (place / use). */
  primaryPressed: boolean;
  /** Held: currently mining (break) the targeted block. */
  mining: boolean;
}

export function createInputState(): InputState {
  return {
    moveX: 0,
    moveZ: 0,
    jump: false,
    sneak: false,
    sprint: false,
    lookYaw: 0,
    lookPitch: 0,
    primaryPressed: false,
    mining: false,
  };
}
