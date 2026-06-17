#pragma once

#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

#include "compile.hpp"
#include "condition.hpp"
#include "value.hpp"
#include "vfs.hpp"

namespace openprompt {

class Evaluator {
public:
    Evaluator(Vfs &vfs, Context &context);

    std::string renderModule(const CompiledModule &module);
    std::string renderTemplate(const CompiledModule &module, std::string_view name);
    std::string renderNodes(std::string_view source, const std::vector<IrNode> &nodes, EvalScope &scope,
                            const std::unordered_map<std::string, CompiledModule> *module_bindings,
                            std::string_view base_path);

private:
    Vfs &vfs_;
    Context &context_;
    std::unordered_map<std::string, std::shared_ptr<CompiledModule>> cache_;
    std::vector<std::string> loading_stack_;

    std::shared_ptr<CompiledModule> loadModule(std::string_view path, std::string_view base_path);
    std::string renderPromptNodes(std::string_view source, const std::vector<TSNode> &nodes, EvalScope &scope,
                                  const std::unordered_map<std::string, CompiledModule> *module_bindings,
                                  std::string_view base_path);
    std::string resolveInterpolation(const IrInterpolation &interpolation, EvalScope &scope,
                                     const std::unordered_map<std::string, CompiledModule> *module_bindings);
    const Value *resolveIterable(std::string_view path, EvalScope &scope,
                                 const std::unordered_map<std::string, CompiledModule> *module_bindings);
};

} // namespace openprompt
