/**
 * Chunk shader material. Cheap and unlit (no scene lights), but light-aware via
 * the per-vertex attribute packed by the mesher: `color` = (surface, sky,
 * block). Final brightness = surface × max(sky × dayFactor, block), clamped to a
 * small ambient floor so caves aren't pitch black.
 *
 * Because time-of-day lives in the `uDayFactor` uniform, day/night transitions
 * cost one uniform write — no remeshing. Torch placement remeshes (block light
 * changes), which the ChunkManager already triggers on edits.
 */
import * as THREE from 'three';

const VERTEX = /* glsl */ `
  attribute vec3 color; // (surface, sky, block)
  varying vec2 vUv;
  varying vec3 vLight;
  void main() {
    vUv = uv;
    vLight = color;
    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
  }
`;

const FRAGMENT = /* glsl */ `
  precision mediump float;
  uniform sampler2D uMap;
  uniform float uDayFactor;   // 0..1 sky-light multiplier (night..day)
  uniform float uAmbient;     // minimum brightness floor
  uniform vec3 uTint;         // global tint (e.g. slight night blue)
  varying vec2 vUv;
  varying vec3 vLight;
  void main() {
    vec4 tex = texture2D(uMap, vUv);
    if (tex.a < 0.35) discard;                 // alpha-tested foliage/glass
    float sky = vLight.y * uDayFactor;
    float block = vLight.z;
    float lightLevel = max(max(sky, block), uAmbient);
    float brightness = vLight.x * lightLevel;
    gl_FragColor = vec4(tex.rgb * brightness * uTint, tex.a);
  }
`;

export interface ChunkMaterials {
  opaque: THREE.ShaderMaterial;
  transparent: THREE.ShaderMaterial;
  /** Update time-of-day: dayFactor 0(night)..1(day), plus ambient/tint. */
  setDay(dayFactor: number, ambient: number, tint: THREE.Color): void;
}

export function createChunkMaterials(atlas: THREE.Texture): ChunkMaterials {
  const makeUniforms = (): Record<string, THREE.IUniform> => ({
    uMap: { value: atlas },
    uDayFactor: { value: 1 },
    uAmbient: { value: 0.06 },
    uTint: { value: new THREE.Color(1, 1, 1) },
  });

  const opaque = new THREE.ShaderMaterial({
    uniforms: makeUniforms(),
    vertexShader: VERTEX,
    fragmentShader: FRAGMENT,
  });
  const transparent = new THREE.ShaderMaterial({
    uniforms: makeUniforms(),
    vertexShader: VERTEX,
    fragmentShader: FRAGMENT,
    transparent: false, // alpha-tested (discard) rather than blended → sortless
    side: THREE.DoubleSide,
  });

  return {
    opaque,
    transparent,
    setDay(dayFactor, ambient, tint) {
      for (const m of [opaque, transparent]) {
        m.uniforms.uDayFactor!.value = dayFactor;
        m.uniforms.uAmbient!.value = ambient;
        (m.uniforms.uTint!.value as THREE.Color).copy(tint);
      }
    },
  };
}
