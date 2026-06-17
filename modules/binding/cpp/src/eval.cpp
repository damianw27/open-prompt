#include "eval.hpp"

#include "condition.hpp"
#include "cst.hpp"

#include <filesystem>
#include <stdexcept>

extern "C" const TSLanguage *tree_sitter_openprompt(void);

namespace openprompt {

namespace {

TSParser *createParser() {
    auto *parser = ts_parser_new();
    ts_parser_set_language(parser, tree_sitter_openprompt());

    return parser;
}

std::shared_ptr<CompiledModule> parseSource(std::string path, std::string source) {
    auto *parser = createParser();
    const auto tree = ts_parser_parse_string(parser, nullptr, source.c_str(), static_cast<uint32_t>(source.size()));
    const auto root = ts_tree_root_node(tree);
    auto compiled = Compiler::compile(std::move(path), std::move(source), root);
    compiled.tree = std::shared_ptr<TSTree>(tree, ts_tree_delete);
    ts_parser_delete(parser);

    return std::make_shared<CompiledModule>(std::move(compiled));
}

} // namespace

Evaluator::Evaluator(Vfs &vfs, Context &context)
    : vfs_(vfs), context_(context) {}

std::shared_ptr<CompiledModule> Evaluator::loadModule(std::string_view path, std::string_view base_path) {
    const auto normalized = normalizePath(path);
    const auto cache_key = normalized;

    if (auto iterator = cache_.find(cache_key); iterator != cache_.end()) {
        return iterator->second;
    }

    for (const auto &loading : loading_stack_) {
        if (loading == cache_key) {
            throw std::runtime_error("cyclic include: " + cache_key);
        }
    }

    loading_stack_.push_back(cache_key);

    std::string resolved = normalized;

    if (!std::filesystem::path(resolved).is_absolute() && !base_path.empty()) {
        const auto dir = std::filesystem::path(base_path).parent_path().string();
        resolved = joinPath(dir.empty() ? "." : dir, normalized);
    }

    std::vector<std::string> candidates;
    candidates.push_back(resolved);
    candidates.push_back(normalized);

    const auto base = basename(normalized);

    if (base != normalized) {
        candidates.push_back(base);
    }

    std::string source;

    for (const auto &candidate : candidates) {
        if (vfs_.read(candidate, source)) {
            auto module = parseSource(candidate, std::move(source));
            cache_[cache_key] = module;
            loading_stack_.pop_back();

            return module;
        }
    }

    loading_stack_.pop_back();
    throw std::runtime_error("unable to read module: " + resolved);
}

const Value *Evaluator::resolveIterable(std::string_view path, EvalScope &scope,
                                        const std::unordered_map<std::string, CompiledModule> *module_bindings) {
    (void)module_bindings;

    std::vector<std::string_view> segments;
    std::size_t start = 0;

    while (start < path.size()) {
        const auto dot = path.find('.', start);

        if (dot == std::string_view::npos) {
            segments.push_back(path.substr(start));
            break;
        }

        segments.push_back(path.substr(start, dot - start));
        start = dot + 1;
    }

    if (segments.empty()) {
        return nullptr;
    }

    const auto root = std::string(segments.front());
    std::vector<std::string_view> properties(segments.begin() + 1, segments.end());

    if (auto iterator = scope.locals.find(root); iterator != scope.locals.end()) {
        return iterator->second.lookupPath(properties);
    }

    if (const auto *root_value = context_.getRoot(root)) {
        return root_value->lookupPath(properties);
    }

    return nullptr;
}

std::string Evaluator::resolveInterpolation(const IrInterpolation &interpolation, EvalScope &scope,
                                              const std::unordered_map<std::string, CompiledModule> *module_bindings) {
    if (interpolation.has_prompt) {
        if (module_bindings != nullptr) {
            auto iterator = module_bindings->find(interpolation.root);

            if (iterator != module_bindings->end()) {
                return renderTemplate(iterator->second, interpolation.prompt);
            }
        }

        if (const auto *root_value = context_.getRoot(interpolation.root)) {
            if (const auto *prompt_value = root_value->lookupTemplate(interpolation.prompt)) {
                return prompt_value->toString();
            }
        }

        return "";
    }

    if (module_bindings != nullptr && interpolation.properties.size() == 1) {
        auto iterator = module_bindings->find(interpolation.root);

        if (iterator != module_bindings->end()) {
            return renderTemplate(iterator->second, interpolation.properties[0]);
        }
    }

    std::vector<std::string_view> properties;

    for (const auto &property : interpolation.properties) {
        properties.push_back(property);
    }

    if (auto local_iterator = scope.locals.find(interpolation.root); local_iterator != scope.locals.end()) {
        if (const auto *value = local_iterator->second.lookupPath(properties)) {
            return value->toString();
        }
    }

    if (const auto *root_value = context_.getRoot(interpolation.root)) {
        if (const auto *value = root_value->lookupPath(properties)) {
            return value->toString();
        }
    }

    return "";
}

std::string Evaluator::renderPromptNodes(std::string_view source, const std::vector<TSNode> &nodes, EvalScope &scope,
                                           const std::unordered_map<std::string, CompiledModule> *module_bindings,
                                           std::string_view base_path) {
    const auto compiled = Compiler::compilePromptNodes(source, nodes);

    return renderNodes(source, compiled, scope, module_bindings, base_path);
}

std::string Evaluator::renderNodes(std::string_view source, const std::vector<IrNode> &nodes, EvalScope &scope,
                                     const std::unordered_map<std::string, CompiledModule> *module_bindings,
                                     std::string_view base_path) {
    std::string output;

    for (const auto &node : nodes) {
        if (node.kind == IrKind::Text) {
            output.append(source.substr(node.text_start, node.text_end - node.text_start));
            continue;
        }

        if (node.kind == IrKind::Interpolation) {
            output.append(resolveInterpolation(node.interpolation, scope, module_bindings));
            continue;
        }

        if (node.kind == IrKind::Inject) {
            const auto module = loadModule(node.inject_path, base_path);
            output.append(renderModule(*module));
            continue;
        }

        if (node.kind == IrKind::Conditional) {
            bool matched = false;
            const bool condition_value =
                ConditionEval::evaluate(node.conditional.condition, source, context_, scope);

            if (condition_value) {
                output.append(renderPromptNodes(source, node.conditional.true_branch, scope, module_bindings, base_path));
                matched = true;
            } else {
                for (std::size_t index = 0; index < node.conditional.elseif_conditions.size(); ++index) {
                    if (index >= node.conditional.elseif_branches.size()) {
                        break;
                    }

                    if (ConditionEval::evaluate(node.conditional.elseif_conditions[index], source, context_, scope)) {
                        output.append(renderPromptNodes(source, node.conditional.elseif_branches[index], scope,
                                                        module_bindings, base_path));
                        matched = true;
                        break;
                    }
                }
            }

            if (!matched && !node.conditional.else_branch.empty()) {
                output.append(
                    renderPromptNodes(source, node.conditional.else_branch, scope, module_bindings, base_path));
            }

            continue;
        }

        if (node.kind == IrKind::ForLoop) {
            const auto *iterable_value = resolveIterable(node.loop.iterable, scope, module_bindings);

            if (iterable_value == nullptr || iterable_value->kind != ValueKind::Array) {
                continue;
            }

            for (const auto &item : iterable_value->array_value) {
                EvalScope child_scope = scope;
                child_scope.locals[node.loop.variable] = item;
                output.append(renderPromptNodes(source, node.loop.body, child_scope, module_bindings, base_path));
            }
        }
    }

    return output;
}

std::string Evaluator::renderTemplate(const CompiledModule &module, std::string_view name) {
    auto iterator = module.templates.find(std::string(name));

    if (iterator == module.templates.end()) {
        return "";
    }

    EvalScope scope;
    std::unordered_map<std::string, CompiledModule> bindings;

    return renderNodes(module.source, iterator->second.body, scope, &bindings, module.path);
}

std::string Evaluator::renderModule(const CompiledModule &module) {
    EvalScope scope;
    std::unordered_map<std::string, CompiledModule> module_bindings;

    for (const auto &[alias, value] : module.use_bindings) {
        if (value.kind == ValueKind::String) {
            const auto loaded = loadModule(value.string_value, module.path);
            module_bindings[alias] = *loaded;
        } else {
            scope.locals[alias] = value;
        }
    }

    return renderNodes(module.source, module.document_body, scope, &module_bindings, module.path);
}

} // namespace openprompt
