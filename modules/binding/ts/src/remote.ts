import type { Context, RenderOptions } from "./types.js";

export interface RemoteRenderOptions extends RenderOptions {
  /** POST endpoint that accepts { source, context, basePath?, modules? } and returns { output }. */
  endpoint?: string;
}

export interface RemoteRenderRequest {
  source: string;
  context: Context;
  basePath?: string;
  modules?: Record<string, string>;
}

export interface RemoteRenderResponse {
  output: string;
}

/**
 * Browser/server-side render without shipping WASM to the client.
 * The OpenPrompt runtime runs on your backend (Node/native); the browser only fetches the result.
 */
export async function renderRemote(
  source: string,
  context: Context,
  options?: RemoteRenderOptions,
): Promise<string> {
  const endpoint = options?.endpoint ?? "/api/openprompt/render";
  const response = await fetch(endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      source,
      context,
      basePath: options?.basePath,
      modules: options?.modules,
    } satisfies RemoteRenderRequest),
  });

  if (!response.ok) {
    throw new Error(`OpenPrompt remote render failed: ${response.status} ${response.statusText}`);
  }

  const payload = (await response.json()) as RemoteRenderResponse;

  return payload.output;
}
