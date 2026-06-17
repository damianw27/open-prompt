#pragma once

#include <memory>
#include <string>

#include "compile.hpp"
#include "eval.hpp"
#include "vfs.hpp"
#include "value.hpp"

namespace openprompt {

class Engine {
public:
    explicit Engine(std::unique_ptr<Vfs> vfs);

    void reset();
    void registerModule(std::string_view path, std::string_view source);
    void setContextJson(std::string_view json);
    void setContextRoot(std::string root, Value value);
    void loadString(std::string_view source, std::string_view base_path);
    void loadFile(std::string_view path);
    std::string render();
    std::string renderTemplate(std::string_view name);
    std::string lastError() const;

private:
    std::unique_ptr<Vfs> vfs_;
    Context context_;
    Evaluator evaluator_;
    std::shared_ptr<CompiledModule> module_;
    std::string last_error_;

    void setError(std::string message);
};

} // namespace openprompt
