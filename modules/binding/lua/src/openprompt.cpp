#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <cstring>
#include <string>

extern "C" {
#include "openprompt.h"
}

namespace {

struct EngineState {
    op_engine *engine;
    op_vfs *vfs;
};

int pushError(lua_State *state, op_engine *engine, op_status status) {
    char *message = nullptr;
    size_t message_len = 0;
    op_engine_last_error(engine, &message, &message_len);
    lua_pushnil(state);
    lua_pushstring(state, message != nullptr ? std::string(message, message_len).c_str() : "openprompt error");
    op_string_free(message);

    return 2;
}

EngineState *toEngine(lua_State *state, int index) {
    return static_cast<EngineState *>(luaL_checkudata(state, index, "openprompt_engine"));
}

int engineGc(lua_State *state) {
    auto *wrapper = toEngine(state, 1);

    if (wrapper->engine != nullptr) {
        op_engine_destroy(wrapper->engine);
        wrapper->engine = nullptr;
        wrapper->vfs = nullptr;
    }

    return 0;
}

int engineNew(lua_State *state) {
    op_vfs *vfs = nullptr;

    if (lua_isstring(state, 1)) {
        vfs = op_vfs_stdio(lua_tostring(state, 1));
    } else {
        vfs = op_vfs_memory();
    }

    auto *wrapper = static_cast<EngineState *>(lua_newuserdatauv(state, sizeof(EngineState), 0));
    wrapper->vfs = vfs;
    wrapper->engine = op_engine_create(wrapper->vfs);
    luaL_setmetatable(state, "openprompt_engine");

    return 1;
}

int engineRegister(lua_State *state) {
    auto *wrapper = toEngine(state, 1);
    const char *path = luaL_checkstring(state, 2);
    size_t source_len = 0;
    const char *source = luaL_checklstring(state, 3, &source_len);
    const auto status = op_engine_register_module(wrapper->engine, path, source, source_len);

    if (status != OP_OK) {
        return pushError(state, wrapper->engine, status);
    }

    lua_pushboolean(state, 1);

    return 1;
}

int engineLoadFile(lua_State *state) {
    auto *wrapper = toEngine(state, 1);
    const char *path = luaL_checkstring(state, 2);
    const auto status = op_engine_load_file(wrapper->engine, path);

    if (status != OP_OK) {
        return pushError(state, wrapper->engine, status);
    }

    lua_pushboolean(state, 1);

    return 1;
}

int engineLoadString(lua_State *state) {
    auto *wrapper = toEngine(state, 1);
    size_t source_len = 0;
    const char *source = luaL_checklstring(state, 2, &source_len);
    const char *base_path = luaL_optstring(state, 3, "template.op");
    const auto status = op_engine_load_string(wrapper->engine, source, source_len, base_path);

    if (status != OP_OK) {
        return pushError(state, wrapper->engine, status);
    }

    lua_pushboolean(state, 1);

    return 1;
}

int engineSetContext(lua_State *state) {
    auto *wrapper = toEngine(state, 1);
    const char *json = luaL_checkstring(state, 2);
    const auto status = op_engine_set_context_json(wrapper->engine, json, std::strlen(json));

    if (status != OP_OK) {
        return pushError(state, wrapper->engine, status);
    }

    lua_pushboolean(state, 1);

    return 1;
}

int engineRender(lua_State *state) {
    auto *wrapper = toEngine(state, 1);
    char *output = nullptr;
    size_t output_len = 0;
    const auto status = op_engine_render(wrapper->engine, &output, &output_len);

    if (status != OP_OK) {
        return pushError(state, wrapper->engine, status);
    }

    lua_pushlstring(state, output, output_len);
    op_string_free(output);

    return 1;
}

int render(lua_State *state) {
    const char *source = luaL_checkstring(state, 1);
    const char *json = luaL_checkstring(state, 2);
    auto *vfs = op_vfs_memory();
    auto *engine = op_engine_create(vfs);
    op_engine_load_string(engine, source, std::strlen(source), "template.op");
    op_engine_set_context_json(engine, json, std::strlen(json));
    char *output = nullptr;
    size_t output_len = 0;
    const auto status = op_engine_render(engine, &output, &output_len);
    op_engine_destroy(engine);

    if (status != OP_OK) {
        lua_pushnil(state);
        lua_pushstring(state, "render failed");

        return 2;
    }

    lua_pushlstring(state, output, output_len);
    op_string_free(output);

    return 1;
}

const luaL_Reg engine_methods[] = {
    {"register_module", engineRegister},
    {"load_string", engineLoadString},
    {"load_file", engineLoadFile},
    {"set_context_json", engineSetContext},
    {"render", engineRender},
    {nullptr, nullptr},
};

} // namespace

extern "C" int luaopen_openprompt(lua_State *state) {
    luaL_newmetatable(state, "openprompt_engine");
    lua_pushvalue(state, -1);
    lua_setfield(state, -2, "__index");
    lua_pushcfunction(state, engineGc);
    lua_setfield(state, -2, "__gc");
    luaL_setfuncs(state, engine_methods, 0);
    lua_pop(state, 1);

    lua_createtable(state, 0, 2);
    lua_pushcfunction(state, engineNew);
    lua_setfield(state, -2, "new");
    lua_pushcfunction(state, render);
    lua_setfield(state, -2, "render");

    return 1;
}
