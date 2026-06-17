#include "openprompt.h"

#include "engine.hpp"
#include "vfs.hpp"
#include "value.hpp"

#include <string.h>
#include <cstdlib>
#include <functional>
#include <unordered_map>
#include <sstream>
#include <stdexcept>
#include <vector>

using namespace openprompt;

namespace {

struct OpVfs {
    std::unique_ptr<Vfs> impl;
};

struct OpValue {
    Value value;
};

struct OpEngine {
    std::unique_ptr<Engine> impl;
    std::unique_ptr<OpVfs> vfs;
    std::string last_error;
};

char *dupString(const std::string &text) {
    auto *out = static_cast<char *>(std::malloc(text.size() + 1));

    if (out == nullptr) {
        return nullptr;
    }

    memcpy(out, text.data(), text.size());
    out[text.size()] = '\0';

    return out;
}

std::vector<std::string> splitSearchPaths(const char *search_paths) {
    std::vector<std::string> paths;

    if (search_paths == nullptr) {
        return paths;
    }

    std::stringstream stream(search_paths);
    std::string item;

    while (std::getline(stream, item, ':')) {
        if (!item.empty()) {
            paths.push_back(item);
        }
    }

    return paths;
}

op_status catchToStatus(OpEngine *engine, const std::function<void()> &fn) {
    try {
        fn();

        return OP_OK;
    } catch (const std::exception &error) {
        if (engine != nullptr) {
            engine->last_error = error.what();
        }

        return OP_ERR_RENDER;
    }
}

} // namespace

extern "C" {

op_vfs *op_vfs_stdio(const char *search_paths) {
    auto *wrapper = new OpVfs;
    wrapper->impl = std::make_unique<StdioVfs>(splitSearchPaths(search_paths));

    return reinterpret_cast<op_vfs *>(wrapper);
}

op_vfs *op_vfs_memory(void) {
    auto *wrapper = new OpVfs;
    wrapper->impl = std::make_unique<MemoryVfs>();

    return reinterpret_cast<op_vfs *>(wrapper);
}

void op_vfs_destroy(op_vfs *vfs) {
    delete reinterpret_cast<OpVfs *>(vfs);
}

op_status op_vfs_register(op_vfs *vfs, const char *path, const char *source, size_t len) {
    if (vfs == nullptr || path == nullptr || source == nullptr) {
        return OP_ERR_INVALID_ARG;
    }

    auto *wrapper = reinterpret_cast<OpVfs *>(vfs);
    wrapper->impl->write(path, std::string_view(source, len));

    return OP_OK;
}

op_status op_vfs_read(op_vfs *vfs, const char *path, char **out_data, size_t *out_len) {
    if (vfs == nullptr || path == nullptr || out_data == nullptr || out_len == nullptr) {
        return OP_ERR_INVALID_ARG;
    }

    auto *wrapper = reinterpret_cast<OpVfs *>(vfs);
    std::string data;

    if (!wrapper->impl->read(path, data)) {
        return OP_ERR_NOT_FOUND;
    }

    *out_data = dupString(data);
    *out_len = data.size();

    return OP_OK;
}

op_engine *op_engine_create(op_vfs *vfs) {
    auto *wrapper = new OpEngine;

    if (vfs == nullptr) {
        wrapper->vfs = std::make_unique<OpVfs>();
        wrapper->vfs->impl = std::make_unique<MemoryVfs>();
    } else {
        wrapper->vfs = std::unique_ptr<OpVfs>(reinterpret_cast<OpVfs *>(vfs));
    }

    wrapper->impl = std::make_unique<Engine>(std::move(wrapper->vfs->impl));

    return reinterpret_cast<op_engine *>(wrapper);
}

void op_engine_destroy(op_engine *engine) {
    delete reinterpret_cast<OpEngine *>(engine);
}

op_status op_engine_reset(op_engine *engine) {
    if (engine == nullptr) {
        return OP_ERR_INVALID_ARG;
    }

    auto *wrapper = reinterpret_cast<OpEngine *>(engine);

    return catchToStatus(wrapper, [&]() { wrapper->impl->reset(); });
}

op_status op_engine_set_context_json(op_engine *engine, const char *json, size_t len) {
    if (engine == nullptr || json == nullptr) {
        return OP_ERR_INVALID_ARG;
    }

    auto *wrapper = reinterpret_cast<OpEngine *>(engine);

    return catchToStatus(wrapper, [&]() { wrapper->impl->setContextJson(std::string_view(json, len)); });
}

op_status op_engine_register_module(op_engine *engine, const char *path, const char *source, size_t len) {
    if (engine == nullptr || path == nullptr || source == nullptr) {
        return OP_ERR_INVALID_ARG;
    }

    auto *wrapper = reinterpret_cast<OpEngine *>(engine);

    return catchToStatus(wrapper, [&]() { wrapper->impl->registerModule(path, std::string_view(source, len)); });
}

op_status op_engine_load_file(op_engine *engine, const char *path) {
    if (engine == nullptr || path == nullptr) {
        return OP_ERR_INVALID_ARG;
    }

    auto *wrapper = reinterpret_cast<OpEngine *>(engine);

    return catchToStatus(wrapper, [&]() { wrapper->impl->loadFile(path); });
}

op_status op_engine_load_string(op_engine *engine, const char *source, size_t len, const char *base_path) {
    if (engine == nullptr || source == nullptr) {
        return OP_ERR_INVALID_ARG;
    }

    auto *wrapper = reinterpret_cast<OpEngine *>(engine);
    const std::string_view base = base_path != nullptr ? std::string_view(base_path) : std::string_view("template.op");

    return catchToStatus(wrapper, [&]() { wrapper->impl->loadString(std::string_view(source, len), base); });
}

op_status op_engine_render(op_engine *engine, char **out, size_t *out_len) {
    if (engine == nullptr || out == nullptr || out_len == nullptr) {
        return OP_ERR_INVALID_ARG;
    }

    auto *wrapper = reinterpret_cast<OpEngine *>(engine);

    return catchToStatus(wrapper, [&]() {
        const auto rendered = wrapper->impl->render();
        *out = dupString(rendered);
        *out_len = rendered.size();
    });
}

op_status op_engine_render_template(op_engine *engine, const char *name, char **out, size_t *out_len) {
    if (engine == nullptr || name == nullptr || out == nullptr || out_len == nullptr) {
        return OP_ERR_INVALID_ARG;
    }

    auto *wrapper = reinterpret_cast<OpEngine *>(engine);

    return catchToStatus(wrapper, [&]() {
        const auto rendered = wrapper->impl->renderTemplate(name);
        *out = dupString(rendered);
        *out_len = rendered.size();
    });
}

op_status op_engine_last_error(op_engine *engine, char **out, size_t *out_len) {
    if (engine == nullptr || out == nullptr || out_len == nullptr) {
        return OP_ERR_INVALID_ARG;
    }

    auto *wrapper = reinterpret_cast<OpEngine *>(engine);
    *out = dupString(wrapper->last_error);
    *out_len = wrapper->last_error.size();

    return OP_OK;
}

void op_string_free(char *value) {
    std::free(value);
}

op_value *op_value_null(void) {
    return reinterpret_cast<op_value *>(new OpValue{Value::makeNull()});
}

op_value *op_value_bool(int value) {
    return reinterpret_cast<op_value *>(new OpValue{Value::makeBool(value != 0)});
}

op_value *op_value_number(double value) {
    return reinterpret_cast<op_value *>(new OpValue{Value::makeNumber(value)});
}

op_value *op_value_string(const char *value, size_t len) {
    return reinterpret_cast<op_value *>(new OpValue{Value::makeString(std::string(value, len))});
}

op_value *op_value_array(op_value **items, size_t count) {
    std::vector<Value> values;

    for (size_t index = 0; index < count; ++index) {
        values.push_back(reinterpret_cast<OpValue *>(items[index])->value);
    }

    return reinterpret_cast<op_value *>(new OpValue{Value::makeArray(std::move(values))});
}

op_value *op_value_map(const char **keys, op_value **values, size_t count) {
    std::unordered_map<std::string, Value> map;

    for (size_t index = 0; index < count; ++index) {
        map[keys[index]] = reinterpret_cast<OpValue *>(values[index])->value;
    }

    return reinterpret_cast<op_value *>(new OpValue{Value::makeMap(std::move(map))});
}

void op_value_release(op_value *value) {
    delete reinterpret_cast<OpValue *>(value);
}

op_status op_engine_set_context_value(op_engine *engine, const char *root, op_value *value) {
    if (engine == nullptr || root == nullptr || value == nullptr) {
        return OP_ERR_INVALID_ARG;
    }

    auto *wrapper = reinterpret_cast<OpEngine *>(engine);

    return catchToStatus(wrapper, [&]() { wrapper->impl->setContextRoot(root, reinterpret_cast<OpValue *>(value)->value); });
}

} // extern "C"
