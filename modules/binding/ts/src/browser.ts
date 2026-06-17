import type { Context, Engine, EngineOptions, RenderOptions } from "./types.js";

/**
 * Local browser runtime uses WASM (see modules/binding/cpp Emscripten target).
 *
 * To avoid WASM in the browser bundle, use {@link renderRemote} from `./remote.js`
 * and run the native/Node binding on a server instead.
 */
export function createEngine(options?: EngineOptions): Engine {
  void options;

  throw new Error(
    "Local browser OpenPrompt requires WASM. Use renderRemote() for a WASM-free browser setup, or prebuild openprompt.wasm.",
  );
}

export function render(_source: string, _context: Context, _options?: RenderOptions): string {
  throw new Error(
    "Local browser render requires WASM. Use renderRemote() for a WASM-free browser setup, or prebuild openprompt.wasm.",
  );
}

export { renderRemote } from "./remote.js";
export type { RemoteRenderOptions, RemoteRenderRequest, RemoteRenderResponse } from "./remote.js";
