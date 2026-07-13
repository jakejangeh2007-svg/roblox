/**
 * Break-progress bookkeeping. Pure state machine: accumulates mining time on a
 * target cell, resets when the target changes or mining stops, and reports a
 * 0..1 progress plus a 0..9 crack stage for the overlay.
 */

export interface BreakState {
  progress: number; // 0..1
  stage: number; // 0..9 (-1 when idle)
  completed: boolean;
}

const IDLE: BreakState = { progress: 0, stage: -1, completed: false };

export class BreakController {
  private key: string | null = null;
  private elapsed = 0;

  /** Reset all progress (e.g. player stopped mining). */
  reset(): void {
    this.key = null;
    this.elapsed = 0;
  }

  get activeKey(): string | null {
    return this.key;
  }

  /**
   * @param targetKey stable key of the targeted cell, or null if none.
   * @param breakTime seconds needed to break the current target.
   * @param dt fixed tick delta.
   * @param mining whether the mine input is currently held.
   */
  update(targetKey: string | null, breakTime: number, dt: number, mining: boolean): BreakState {
    if (!mining || targetKey === null || !Number.isFinite(breakTime)) {
      this.reset();
      return IDLE;
    }
    if (targetKey !== this.key) {
      this.key = targetKey;
      this.elapsed = 0;
    }
    this.elapsed += dt;
    if (breakTime <= 0) {
      return { progress: 1, stage: 9, completed: true };
    }
    const progress = Math.min(1, this.elapsed / breakTime);
    const stage = Math.min(9, Math.floor(progress * 10));
    return { progress, stage, completed: progress >= 1 };
  }
}
