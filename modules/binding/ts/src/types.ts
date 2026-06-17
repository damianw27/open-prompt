export type Context = Record<string, unknown>;

export interface EngineOptions {
  /** Colon-separated search roots on disk; enables automatic @use/@inject from files. */
  searchPaths?: string[];
  /** Pre-register virtual modules (required for browser/memory VFS when not using searchPaths). */
  modules?: Record<string, string>;
}

export interface RenderOptions {
  basePath?: string;
  modules?: Record<string, string>;
}

export interface Engine {
  registerModule(path: string, source: string): void;
  loadString(source: string, basePath?: string): void;
  loadFile(path: string): void;
  setContext(context: Context): void;
  render(): string;
}

export declare function createEngine(options?: EngineOptions): Engine;

export declare function render(
  source: string,
  context: Context,
  options?: RenderOptions,
): string;
