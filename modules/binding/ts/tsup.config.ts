import { defineConfig } from "tsup";

export default defineConfig([
  {
    entry: {
      index: "src/index.ts",
      node: "src/node.ts",
    },
    platform: "node",
    format: ["esm"],
    target: "node20",
    outDir: "dist",
    dts: true,
    sourcemap: true,
    clean: true,
    splitting: false,
    shims: false,
  },
  {
    entry: {
      browser: "src/index.browser.ts",
    },
    platform: "browser",
    format: ["esm"],
    target: "es2022",
    outDir: "dist",
    dts: true,
    sourcemap: true,
    splitting: false,
  },
  {
    entry: {
      test: "src/test.ts",
    },
    bundle: false,
    platform: "node",
    format: ["esm"],
    target: "node20",
    outDir: "dist",
    dts: false,
    sourcemap: true,
  },
]);
