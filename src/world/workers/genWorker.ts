/**
 * Generation + meshing worker. Runs terrain generation and mesh building off
 * the main thread so chunk loading never drops frames. Communicates via the
 * typed protocol; returns transferable buffers.
 */
/// <reference lib="webworker" />
import type { ToWorker, GeneratedMsg, MeshedMsg, MeshBuffersMsg } from './protocol';
import { TerrainGenerator } from './terrain';
import { meshChunk, type NeighborGrid, type MeshBuffers } from './mesher';

let generator: TerrainGenerator | null = null;

function toMsgBuffers(m: MeshBuffers | null): MeshBuffersMsg | null {
  if (!m) return null;
  // These typed arrays are always ArrayBuffer-backed (never SharedArrayBuffer),
  // but TS types .buffer as ArrayBufferLike; assert the concrete type.
  return {
    positions: m.positions.buffer as ArrayBuffer,
    normals: m.normals.buffer as ArrayBuffer,
    uvs: m.uvs.buffer as ArrayBuffer,
    shade: m.shade.buffer as ArrayBuffer,
    indices: m.indices.buffer as ArrayBuffer,
  };
}

function collectTransfers(m: MeshBuffersMsg | null, out: ArrayBuffer[]): void {
  if (!m) return;
  out.push(m.positions, m.normals, m.uvs, m.shade, m.indices);
}

self.onmessage = (ev: MessageEvent<ToWorker>): void => {
  const msg = ev.data;
  switch (msg.type) {
    case 'init': {
      generator = new TerrainGenerator(msg.seed);
      break;
    }
    case 'generate': {
      if (!generator) throw new Error('Worker not initialized');
      const blocks = generator.generateChunk(msg.cx, msg.cz);
      const buffer = blocks.buffer as ArrayBuffer;
      const reply: GeneratedMsg = {
        type: 'generated',
        cx: msg.cx,
        cz: msg.cz,
        blocks: buffer,
      };
      (self as unknown as Worker).postMessage(reply, [buffer]);
      break;
    }
    case 'mesh': {
      const grid: NeighborGrid = {
        blocks: msg.neighbors.map((buf) => (buf ? new Uint8Array(buf) : null)),
      };
      const result = meshChunk(grid);
      const opaque = toMsgBuffers(result.opaque);
      const transparent = toMsgBuffers(result.transparent);
      const reply: MeshedMsg = {
        type: 'meshed',
        cx: msg.cx,
        cz: msg.cz,
        opaque,
        transparent,
      };
      const transfers: ArrayBuffer[] = [];
      collectTransfers(opaque, transfers);
      collectTransfers(transparent, transfers);
      (self as unknown as Worker).postMessage(reply, transfers);
      break;
    }
  }
};
