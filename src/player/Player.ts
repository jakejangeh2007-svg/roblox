/**
 * The player entity: position/velocity, camera orientation, health/hunger, and
 * the per-tick movement integration that ties input intent to AABB physics.
 *
 * Movement model mirrors Minecraft closely enough to feel right: horizontal
 * acceleration toward the input direction with ground friction, gravity to
 * terminal velocity, jump impulse only when grounded, sneak/ sprint speed
 * modifiers, and fall-damage accounting on landing.
 */
import * as THREE from 'three';
import {
  GRAVITY,
  JUMP_VELOCITY,
  PLAYER_EYE_HEIGHT,
  PLAYER_HEIGHT,
  PLAYER_WIDTH,
  SAFE_FALL_BLOCKS,
  SNEAK_SPEED,
  SPRINT_SPEED,
  TERMINAL_VELOCITY,
  WALK_SPEED,
} from '../config/constants';
import { clamp } from '../core/math';
import { moveAABB, fallDamage, type SolidFn } from './physics';
import type { InputState } from '../input/InputState';

const HALF_PI = Math.PI / 2 - 0.001;

export interface PlayerSpawn {
  x: number;
  y: number;
  z: number;
  yaw?: number;
  pitch?: number;
}

export class Player {
  // Feet-center position.
  position = new THREE.Vector3();
  velocity = new THREE.Vector3();
  yaw = 0; // radians, around +Y
  pitch = 0; // radians, +up

  onGround = false;
  sneaking = false;
  sprinting = false;

  health = 20; // 10 hearts = 20 half-hearts
  maxHealth = 20;
  hunger = 20; // 10 shanks = 20 half-shanks
  maxHunger = 20;

  /** Distance fallen since last on ground, for fall damage. */
  private fallDistance = 0;
  /** Damage dealt this tick (half-hearts), for the caller to surface. */
  lastFallDamage = 0;

  readonly half = PLAYER_WIDTH / 2;
  readonly height = PLAYER_HEIGHT;

  constructor(spawn: PlayerSpawn) {
    this.position.set(spawn.x, spawn.y, spawn.z);
    this.yaw = spawn.yaw ?? 0;
    this.pitch = spawn.pitch ?? 0;
  }

  /** Eye position for the camera. */
  get eyePosition(): THREE.Vector3 {
    const eye = PLAYER_EYE_HEIGHT - (this.sneaking ? 0.3 : 0);
    return new THREE.Vector3(this.position.x, this.position.y + eye, this.position.z);
  }

  applyLook(dYaw: number, dPitch: number): void {
    this.yaw -= dYaw;
    this.pitch = clamp(this.pitch - dPitch, -HALF_PI, HALF_PI);
  }

  /** Advance one fixed physics tick. */
  update(dt: number, input: InputState, isSolid: SolidFn): void {
    this.lastFallDamage = 0;
    // Apply queued look delta.
    if (input.lookYaw !== 0 || input.lookPitch !== 0) {
      this.applyLook(input.lookYaw, input.lookPitch);
      input.lookYaw = 0;
      input.lookPitch = 0;
    }

    this.sneaking = input.sneak;
    // Sprint only while actively moving forward.
    this.sprinting = input.sprint && input.moveZ > 0.1 && !this.sneaking;

    const speed = this.sneaking ? SNEAK_SPEED : this.sprinting ? SPRINT_SPEED : WALK_SPEED;

    // Desired horizontal velocity in world space from yaw-relative intent.
    const sin = Math.sin(this.yaw);
    const cos = Math.cos(this.yaw);
    // Forward is -Z at yaw 0 (Three.js convention).
    let wishX = input.moveX * cos - input.moveZ * sin;
    let wishZ = input.moveX * sin + input.moveZ * cos;
    const len = Math.hypot(wishX, wishZ);
    if (len > 1) {
      wishX /= len;
      wishZ /= len;
    }
    const targetVX = wishX * speed;
    const targetVZ = wishZ * speed;

    // Acceleration: snappy on ground, floaty in air (Minecraft-like control).
    const accel = this.onGround ? 12 : 3;
    this.velocity.x += (targetVX - this.velocity.x) * Math.min(1, accel * dt);
    this.velocity.z += (targetVZ - this.velocity.z) * Math.min(1, accel * dt);

    // Jump.
    if (input.jump && this.onGround) {
      this.velocity.y = JUMP_VELOCITY;
      this.onGround = false;
    }

    // Gravity.
    this.velocity.y += GRAVITY * dt;
    if (this.velocity.y < TERMINAL_VELOCITY) this.velocity.y = TERMINAL_VELOCITY;

    const wasOnGround = this.onGround;
    const prevY = this.position.y;

    const result = moveAABB(
      this.position.x,
      this.position.y,
      this.position.z,
      this.half,
      this.height,
      this.velocity.x * dt,
      this.velocity.y * dt,
      this.velocity.z * dt,
      isSolid,
    );
    this.position.set(result.x, result.y, result.z);

    if (result.hitCeiling && this.velocity.y > 0) this.velocity.y = 0;
    if (result.hitWall) {
      // Zero the blocked horizontal component so we don't creep.
      if (Math.abs(result.x - (this.position.x)) < 1e-9) {
        /* already updated */
      }
    }

    // Fall-distance tracking + landing damage.
    if (!result.onGround) {
      if (this.velocity.y < 0) this.fallDistance += prevY - this.position.y;
    } else {
      if (!wasOnGround) {
        const dmg = fallDamage(this.fallDistance, SAFE_FALL_BLOCKS);
        if (dmg > 0) {
          this.lastFallDamage = dmg;
          this.health = Math.max(0, this.health - dmg);
        }
      }
      this.fallDistance = 0;
      this.velocity.y = 0;
    }
    this.onGround = result.onGround;

    // Reset if we somehow fell out of the world.
    if (this.position.y < -8) {
      this.position.y = 120;
      this.velocity.set(0, 0, 0);
      this.fallDistance = 0;
    }
  }

  /** Point a Three.js camera at the player's eye along yaw/pitch. */
  applyToCamera(camera: THREE.PerspectiveCamera): void {
    const eye = this.eyePosition;
    camera.position.copy(eye);
    camera.rotation.order = 'YXZ';
    camera.rotation.y = this.yaw;
    camera.rotation.x = this.pitch;
  }

  /** Unit forward vector (including pitch), for raycasting. */
  getLookDirection(target = new THREE.Vector3()): THREE.Vector3 {
    const cosPitch = Math.cos(this.pitch);
    target.set(
      -Math.sin(this.yaw) * cosPitch,
      Math.sin(this.pitch),
      -Math.cos(this.yaw) * cosPitch,
    );
    return target;
  }
}
