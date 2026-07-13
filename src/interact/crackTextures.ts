/**
 * Procedurally generated block-breaking crack overlay textures (10 stages,
 * destroy_stage_0..9 equivalents). Each stage adds more crack pixels, drawn as
 * dark lines radiating from a few seed points. Transparent elsewhere so it
 * composites over the block being mined.
 */
import * as THREE from 'three';

const SIZE = 16;

function hash(x: number, y: number, salt: number): number {
  let h = (x * 374761393 + y * 668265263 + salt * 2246822519) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
}

let cache: THREE.Texture[] | null = null;

export function buildCrackTextures(): THREE.Texture[] {
  if (cache) return cache;
  const textures: THREE.Texture[] = [];

  for (let stage = 0; stage < 10; stage++) {
    const canvas = document.createElement('canvas');
    canvas.width = SIZE;
    canvas.height = SIZE;
    const ctx = canvas.getContext('2d')!;
    ctx.clearRect(0, 0, SIZE, SIZE);

    // Density grows with stage; seed a few crack origins near center.
    const density = (stage + 1) / 10;
    const cracks = Math.floor(density * 26);
    ctx.strokeStyle = 'rgba(0,0,0,0.55)';
    ctx.lineWidth = 1;
    for (let i = 0; i < cracks; i++) {
      const sx = 4 + hash(i, stage, 1) * 8;
      const sy = 4 + hash(i, stage, 2) * 8;
      const len = 2 + hash(i, stage, 3) * (density * 8);
      const ang = hash(i, stage, 4) * Math.PI * 2;
      ctx.beginPath();
      ctx.moveTo(sx, sy);
      ctx.lineTo(sx + Math.cos(ang) * len, sy + Math.sin(ang) * len);
      ctx.stroke();
    }

    const tex = new THREE.CanvasTexture(canvas);
    tex.magFilter = THREE.NearestFilter;
    tex.minFilter = THREE.NearestFilter;
    tex.generateMipmaps = false;
    tex.flipY = false;
    textures.push(tex);
  }

  cache = textures;
  return textures;
}
