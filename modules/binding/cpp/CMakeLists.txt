cmake_minimum_required(VERSION 3.16)
project(openprompt LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

option(OPENPROMPT_BUILD_TESTS "Build OpenPrompt core tests" ON)
option(OPENPROMPT_BUILD_WASM "Build Emscripten WASM target" OFF)

set(OPENPROMPT_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../..")
set(TREE_SITTER_GRAMMAR_DIR "${OPENPROMPT_ROOT}/tree-sitter/src")
set(TREE_SITTER_RUNTIME_DIR "${OPENPROMPT_ROOT}/lsp/zig-pkg/tree_sitter-0.27.0-Tw2sR0TDCwBUIKjCd2avkJKfxXvSNZmdynJqiXMUYgAv/lib")

set(TREE_SITTER_SOURCES
    "${TREE_SITTER_RUNTIME_DIR}/src/lib.c"
    "${TREE_SITTER_RUNTIME_DIR}/src/parser.c"
    "${TREE_SITTER_RUNTIME_DIR}/src/tree.c"
    "${TREE_SITTER_RUNTIME_DIR}/src/node.c"
    "${TREE_SITTER_RUNTIME_DIR}/src/lexer.c"
    "${TREE_SITTER_RUNTIME_DIR}/src/subtree.c"
    "${TREE_SITTER_RUNTIME_DIR}/src/language.c"
    "${TREE_SITTER_RUNTIME_DIR}/src/alloc.c"
    "${TREE_SITTER_RUNTIME_DIR}/src/stack.c"
    "${TREE_SITTER_RUNTIME_DIR}/src/tree_cursor.c"
    "${TREE_SITTER_RUNTIME_DIR}/src/point.c"
    "${TREE_SITTER_RUNTIME_DIR}/src/get_changed_ranges.c"
)

set(OPENPROMPT_GRAMMAR_SOURCES
    "${TREE_SITTER_GRAMMAR_DIR}/parser.c"
    "${TREE_SITTER_GRAMMAR_DIR}/scanner.c"
)

set(OPENPROMPT_CORE_SOURCES
    src/arena.cpp
    src/value.cpp
    src/vfs.cpp
    src/cst.cpp
    src/condition.cpp
    src/compile.cpp
    src/eval.cpp
    src/engine.cpp
    src/api.cpp
)

add_library(openprompt_core STATIC
    ${TREE_SITTER_SOURCES}
    ${OPENPROMPT_GRAMMAR_SOURCES}
    ${OPENPROMPT_CORE_SOURCES}
)

target_include_directories(openprompt_core
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${TREE_SITTER_RUNTIME_DIR}/include
        ${TREE_SITTER_GRAMMAR_DIR}
        ${TREE_SITTER_GRAMMAR_DIR}/tree_sitter
)

target_compile_definitions(openprompt_core PRIVATE TREE_SITTER_HIDE_SYMBOLS)
target_compile_options(openprompt_core PRIVATE -Wall -Wextra -Wpedantic)
set_target_properties(openprompt_core PROPERTIES POSITION_INDEPENDENT_CODE ON)

add_library(openprompt SHARED src/api_shim.cpp)
target_link_libraries(openprompt PRIVATE openprompt_core)
target_include_directories(openprompt PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)

if(OPENPROMPT_BUILD_TESTS)
    enable_testing()
    add_executable(openprompt_tests tests/test_render.cpp)
    target_link_libraries(openprompt_tests PRIVATE openprompt_core)
    target_include_directories(openprompt_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
    add_test(NAME render_tests COMMAND openprompt_tests)
endif()

if(OPENPROMPT_BUILD_WASM)
    message(STATUS "WASM build: link openprompt_core with Emscripten toolchain")
endif()
