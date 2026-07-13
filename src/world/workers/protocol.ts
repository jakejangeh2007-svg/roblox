/**
 * Typed message protocol between the main thread and the generation worker.
 * All heavy payloads (block arrays, vertex buffers) are transferred, not
 * copied — the caller lists them in the postMessage transfer array.
 */

export interface InitMsg {
  type: 'init';
  seed: number;
}

/** Ask the worker to generate a chunk's block data. */
export interface GenerateMsg {
  type: 'generate';
  cx: number;
  cz: number;
}

/** Worker → main: generated block data. */
export interface GeneratedMsg {
  type: 'generated';
  cx: number;
  cz: number;
  blocks: ArrayBuffer; // Uint8Array buffer
}

/**
 * Ask the worker to mesh a chunk. The main thread supplies the center chunk's
 * blocks plus its 8 neighbors (some may be null) so borders cull correctly.
 * Buffers are transferred *back* in the result to avoid a copy, so the main
 * thread must have detached copies or re-request as needed — here we send
 * copies' ownership and the worker returns fresh mesh buffers only.
 */
export interface MeshMsg {
  type: 'mesh';
  cx: number;
  cz: number;
  /** 9 neighbor block buffers, row-major (dz+1)*3+(dx+1); center at 4. */
  neighbors: (ArrayBuffer | null)[];
}

export interface MeshBuffersMsg {
  positions: ArrayBuffer;
  normals: ArrayBuffer;
  uvs: ArrayBuffer;
  shade: ArrayBuffer;
  indices: ArrayBuffer;
}

export interface MeshedMsg {
  type: 'meshed';
  cx: number;
  cz: number;
  opaque: MeshBuffersMsg | null;
  transparent: MeshBuffersMsg | null;
}

export type ToWorker = InitMsg | GenerateMsg | MeshMsg;
export type FromWorker = GeneratedMsg | MeshedMsg;
