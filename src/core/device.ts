/**
 * Runtime device capability detection. Drives render distance and control mode.
 */
import { RENDER_DISTANCE_DESKTOP, RENDER_DISTANCE_MOBILE } from '../config/constants';

export function isTouchDevice(): boolean {
  return (
    'ontouchstart' in window ||
    navigator.maxTouchPoints > 0 ||
    // Coarse pointer catches most phones/tablets even without touch events.
    window.matchMedia('(pointer: coarse)').matches
  );
}

export function defaultRenderDistance(): number {
  return isTouchDevice() ? RENDER_DISTANCE_MOBILE : RENDER_DISTANCE_DESKTOP;
}
