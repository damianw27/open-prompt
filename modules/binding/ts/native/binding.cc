#include <napi.h>
#include <stdexcept>
#include <string>
#include <vector>

extern "C" {
#include "openprompt.h"
}

namespace {

op_status wrapStatus(op_status status, op_engine *engine, Napi::Env env) {
    if (status == OP_OK) {
        return OP_OK;
    }

    char *message = nullptr;
    size_t message_len = 0;
    op_engine_last_error(engine, &message, &message_len);
    std::string error_text = message != nullptr ? std::string(message, message_len) : "openprompt error";
    op_string_free(message);
    throw Napi::Error::New(env, error_text);
}

void ensureOk(op_status status, op_engine *engine) {
    if (status == OP_OK) {
        return;
    }

    char *message = nullptr;
    size_t message_len = 0;
    op_engine_last_error(engine, &message, &message_len);
    std::string error_text = message != nullptr ? std::string(message, message_len) : "openprompt error";
    op_string_free(message);
    throw std::runtime_error(error_text);
}

std::string joinSearchPaths(const Napi::Array &paths) {
    std::string joined;

    for (uint32_t index = 0; index < paths.Length(); ++index) {
        if (index > 0) {
            joined.push_back(':');
        }

        joined += paths.Get(index).As<Napi::String>().Utf8Value();
    }

    return joined;
}

class EngineWrapper : public Napi::ObjectWrap<EngineWrapper> {
public:
    static Napi::Object Init(Napi::Env env, Napi::Object exports) {
        Napi::Function func = DefineClass(env, "Engine", {
            InstanceMethod("registerModule", &EngineWrapper::RegisterModule),
            InstanceMethod("loadString", &EngineWrapper::LoadString),
            InstanceMethod("loadFile", &EngineWrapper::LoadFile),
            InstanceMethod("setContext", &EngineWrapper::SetContext),
            InstanceMethod("render", &EngineWrapper::Render),
        });

        exports.Set("Engine", func);

        return exports;
    }

    EngineWrapper(const Napi::CallbackInfo &info)
        : Napi::ObjectWrap<EngineWrapper>(info) {
        if (info.Length() > 0 && info[0].IsObject()) {
            const auto options = info[0].As<Napi::Object>();

            if (options.Has("searchPaths") && options.Get("searchPaths").IsArray()) {
                const auto joined = joinSearchPaths(options.Get("searchPaths").As<Napi::Array>());
                vfs_ = op_vfs_stdio(joined.c_str());
            } else {
                vfs_ = op_vfs_memory();
            }

            if (options.Has("modules") && options.Get("modules").IsObject()) {
                engine_ = op_engine_create(vfs_);
                const auto modules = options.Get("modules").As<Napi::Object>();
                const auto keys = modules.GetPropertyNames();

                for (uint32_t index = 0; index < keys.Length(); ++index) {
                    const auto key = keys.Get(index).As<Napi::String>();
                    const auto source = modules.Get(key).As<Napi::String>().Utf8Value();
                    ensureOk(op_engine_register_module(engine_, key.Utf8Value().c_str(), source.c_str(),
                                                       source.size()),
                             engine_);
                }

                return;
            }
        } else {
            vfs_ = op_vfs_memory();
        }

        engine_ = op_engine_create(vfs_);
    }

    ~EngineWrapper() override {
        if (engine_ != nullptr) {
            op_engine_destroy(engine_);
            engine_ = nullptr;
            vfs_ = nullptr;
        }
    }

private:
    op_engine *engine_ = nullptr;
    op_vfs *vfs_ = nullptr;

    Napi::Value RegisterModule(const Napi::CallbackInfo &info) {
        const auto path = info[0].As<Napi::String>().Utf8Value();
        const auto source = info[1].As<Napi::String>().Utf8Value();
        wrapStatus(op_engine_register_module(engine_, path.c_str(), source.c_str(), source.size()), engine_,
                   info.Env());

        return info.Env().Undefined();
    }

    Napi::Value LoadString(const Napi::CallbackInfo &info) {
        const auto source = info[0].As<Napi::String>().Utf8Value();
        const auto base_path = info.Length() > 1 ? info[1].As<Napi::String>().Utf8Value() : "template.op";
        wrapStatus(op_engine_load_string(engine_, source.c_str(), source.size(), base_path.c_str()), engine_,
                   info.Env());

        return info.Env().Undefined();
    }

    Napi::Value LoadFile(const Napi::CallbackInfo &info) {
        const auto path = info[0].As<Napi::String>().Utf8Value();
        wrapStatus(op_engine_load_file(engine_, path.c_str()), engine_, info.Env());

        return info.Env().Undefined();
    }

    Napi::Value SetContext(const Napi::CallbackInfo &info) {
        const auto json = info[0].As<Napi::String>().Utf8Value();
        wrapStatus(op_engine_set_context_json(engine_, json.c_str(), json.size()), engine_, info.Env());

        return info.Env().Undefined();
    }

    Napi::Value Render(const Napi::CallbackInfo &info) {
        char *output = nullptr;
        size_t output_len = 0;
        wrapStatus(op_engine_render(engine_, &output, &output_len), engine_, info.Env());
        std::string rendered(output, output_len);
        op_string_free(output);

        return Napi::String::New(info.Env(), rendered);
    }
};

Napi::Object InitAll(Napi::Env env, Napi::Object exports) {
    return EngineWrapper::Init(env, exports);
}

} // namespace

NODE_API_MODULE(openprompt, InitAll)
