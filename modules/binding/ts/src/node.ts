import { createRequire } from "node:module";
import type { Context, Engine, EngineOptions, RenderOptions } from "./types.js";

const require = createRequire(import.meta.url);

type NativeEngineOptions = {
  searchPaths?: string[];
  modules?: Record<string, string>;
};

type NativeEngine = {
  new (options?: NativeEngineOptions): {
    registerModule(path: string, source: string): void;
    loadString(source: string, basePath?: string): void;
    loadFile(path: string): void;
    setContext(json: string): void;
    render(): string;
  };
};

const native = require("../build/Release/openprompt_native.node") as {
  Engine: NativeEngine;
};

export function createEngine(options?: EngineOptions): Engine {
  const handle = new native.Engine(options);

  return {
    registerModule(path: string, source: string) {
      handle.registerModule(path, source);
    },
    loadString(source: string, basePath = "template.op") {
      handle.loadString(source, basePath);
    },
    loadFile(path: string) {
      handle.loadFile(path);
    },
    setContext(context: Context) {
      handle.setContext(JSON.stringify(context));
    },
    render() {
      return handle.render();
    },
  };
}

export function render(source: string, context: Context, options?: RenderOptions): string {
  const engine = createEngine({ modules: options?.modules });

  engine.loadString(source, options?.basePath);
  engine.setContext(context);

  return engine.render();
}
