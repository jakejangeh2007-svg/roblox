/**
 * Day/night cycle: a continuous 20-minute loop that drives the sky color, sun
 * and moon transforms, and the global sky-light factor fed to the chunk shader.
 *
 * timeOfDay is a 0..1 fraction: 0 = sunrise, 0.25 = noon, 0.5 = sunset,
 * 0.75 = midnight. The sun orbits the sky on that phase; the moon is opposite.
 * The sky-light factor ramps smoothly between day (1.0) and night (~0.16) with
 * short dawn/dusk transitions, so nights are dark but not unplayable.
 */
import * as THREE from 'three';
import { DAY_LENGTH_SECONDS } from '../config/constants';
import type { ChunkManager } from '../world/ChunkManager';

const SKY_DAY = new THREE.Color(0x8fb7ff);
const SKY_NIGHT = new THREE.Color(0x0a0e1f);
const SKY_SUNSET = new THREE.Color(0xf2a04a);
const NIGHT_TINT = new THREE.Color(0.7, 0.75, 1.0); // cool moonlight
const DAY_TINT = new THREE.Color(1, 1, 1);

function smoothstep(edge0: number, edge1: number, x: number): number {
  const t = Math.min(1, Math.max(0, (x - edge0) / (edge1 - edge0)));
  return t * t * (3 - 2 * t);
}

export class DayNight {
  /** 0..1 phase of the day. */
  time: number;

  private readonly sun: THREE.DirectionalLight;
  private readonly moon: THREE.DirectionalLight;
  private readonly ambient: THREE.AmbientLight;
  private readonly sunMesh: THREE.Mesh;
  private readonly moonMesh: THREE.Mesh;
  private readonly celestial = new THREE.Group();

  private readonly skyColor = new THREE.Color();
  private readonly tint = new THREE.Color();

  constructor(
    private readonly scene: THREE.Scene,
    private readonly chunks: ChunkManager,
    startTime = 0.1,
  ) {
    this.time = startTime;

    this.sun = new THREE.DirectionalLight(0xfff4d6, 1.0);
    this.moon = new THREE.DirectionalLight(0x9fb4ff, 0.25);
    this.ambient = new THREE.AmbientLight(0xffffff, 0.5);
    scene.add(this.sun, this.moon, this.ambient);

    // Visible sun + moon discs on a large sphere around the player.
    this.sunMesh = new THREE.Mesh(
      new THREE.SphereGeometry(18, 12, 12),
      new THREE.MeshBasicMaterial({ color: 0xfff2b0, fog: false }),
    );
    this.moonMesh = new THREE.Mesh(
      new THREE.SphereGeometry(12, 12, 12),
      new THREE.MeshBasicMaterial({ color: 0xdfe6ff, fog: false }),
    );
    this.celestial.add(this.sunMesh, this.moonMesh);
    scene.add(this.celestial);
  }

  /** 1.0 at day, ~0.16 at night, smooth dawn/dusk ramps. */
  private skyLightFactor(): number {
    // Daytime window roughly time in [0, 0.5]; night in [0.5, 1].
    // Ramp up around sunrise (0.0) and down around sunset (0.5).
    const day = smoothstep(-0.05, 0.06, this.time) - smoothstep(0.44, 0.55, this.time);
    return 0.16 + 0.84 * Math.max(0, Math.min(1, day + (this.time > 0.9 ? smoothstep(0.94, 1.02, this.time) : 0)));
  }

  update(dt: number, playerPos: THREE.Vector3): number {
    this.time = (this.time + dt / DAY_LENGTH_SECONDS) % 1;

    const factor = this.skyLightFactor();

    // Sky color: blend day↔night, tinting toward orange at sunrise/sunset.
    const sunsetGlow =
      smoothstep(0.42, 0.5, this.time) * (1 - smoothstep(0.5, 0.58, this.time)) +
      smoothstep(-0.02, 0.04, this.time) * (1 - smoothstep(0.04, 0.12, this.time));
    this.skyColor.copy(SKY_NIGHT).lerp(SKY_DAY, factor);
    this.skyColor.lerp(SKY_SUNSET, Math.min(0.6, sunsetGlow));
    (this.scene.background as THREE.Color).copy(this.skyColor);
    if (this.scene.fog) (this.scene.fog as THREE.Fog).color.copy(this.skyColor);

    // Celestial transforms: sun angle from the day phase.
    const sunAngle = this.time * Math.PI * 2 - Math.PI / 2; // sunrise at horizon
    const sx = Math.cos(sunAngle);
    const sy = Math.sin(sunAngle);
    this.sun.position.set(sx, sy, 0.3).normalize();
    this.moon.position.set(-sx, -sy, -0.3).normalize();
    this.sun.intensity = Math.max(0, sy) * 1.1;
    this.moon.intensity = Math.max(0, -sy) * 0.3;
    this.ambient.intensity = 0.3 + 0.35 * factor;

    // Keep the celestial group centered on the player; place discs far away.
    this.celestial.position.copy(playerPos);
    this.sunMesh.position.set(sx * 300, sy * 300, 0.3 * 300);
    this.moonMesh.position.set(-sx * 300, -sy * 300, -0.3 * 300);

    // Feed the chunk shader.
    this.tint.copy(NIGHT_TINT).lerp(DAY_TINT, factor);
    const ambientFloor = 0.05 + 0.03 * factor;
    this.chunks.setDay(factor, ambientFloor, this.tint);

    return factor;
  }

  get isNight(): boolean {
    return this.skyLightFactor() < 0.4;
  }
}
