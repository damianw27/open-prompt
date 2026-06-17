# OpenPrompt language bindings

Load `.op` templates, pass context, get a string back.

## Layout

| Directory | Target |
|-----------|--------|
| [`cpp/`](cpp/) | Native core, C ABI, C++ SDK |
| [`zig/`](zig/) | Zig wrapper (`@cImport`) |
| [`ts/`](ts/) | TypeScript/JavaScript (Node N-API, browser WASM) |
| [`java/`](java/) | Java (Panama FFM) |
| [`lua/`](lua/) | Lua C module |
| [`tests/vectors/`](tests/vectors/) | Shared golden fixtures |

## Build order

```bash
# 1. Core library
cd modules/binding/cpp
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build

# 2. Run core tests
ctest --test-dir build --output-on-failure

# 3. Zig
cd ../zig
zig build test

# 4. TypeScript (Node)
cd ../ts
pnpm install && pnpm run build:native && pnpm run build && pnpm test
```

## Environment

- `OPENPROMPT_SEARCH_PATHS` — colon-separated dirs for `@use` / `@inject` (stdio VFS only)

## API (all languages)

```text
createEngine({ searchPaths?, modules? })
loadString(source, { basePath? })
loadFile(path)                 # stdio VFS: @use reads from disk
registerModule(path, source)   # memory VFS / browser / overrides
setContext(map)
render() → string
```

### `@use` / `@inject` resolution

| Binding | From disk | Virtual modules |
|---------|-----------|-----------------|
| Node TS | `createEngine({ searchPaths })` + `loadFile()` | `createEngine({ modules })` or `render(..., { modules })` |
| Zig | `Engine.initStdio(allocator, &paths)` + `loadFile()` | `registerModule` / `registerModules` |
| Lua | `openprompt.new("dir1:dir2")` + `load_file()` | `register_module` |
| Browser | No filesystem | `modules` map + WASM, or `renderRemote()` |

Browser options:

- WASM — render in-tab (small bundle, no round trip)
- Remote — `renderRemote()` hits your backend; zero WASM in the client
- Pure TS port — not planned; would duplicate Tree-sitter + evaluator

`OPENPROMPT_SEARCH_PATHS` also applies with stdio VFS on native.
