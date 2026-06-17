#pragma once

#include <cstdint>
#include <memory>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

#include <tree_sitter/api.h>

#include "value.hpp"

namespace openprompt {

enum class IrKind : std::uint8_t {
    Text,
    Interpolation,
    Conditional,
    ForLoop,
    Inject,
};

struct IrInterpolation {
    std::string root;
    std::vector<std::string> properties;
    std::string prompt;
    bool has_prompt = false;
};

struct IrConditional {
    TSNode condition = {};
    std::vector<TSNode> true_branch;
    std::vector<TSNode> elseif_conditions;
    std::vector<std::vector<TSNode>> elseif_branches;
    std::vector<TSNode> else_branch;
};

struct IrForLoop {
    std::string variable;
    std::string iterable;
    std::vector<TSNode> body;
};

struct IrNode {
    IrKind kind = IrKind::Text;
    std::uint32_t text_start = 0;
    std::uint32_t text_end = 0;
    IrInterpolation interpolation;
    IrConditional conditional;
    IrForLoop loop;
    std::string inject_path;
};

struct TemplateExport {
    std::string name;
    std::vector<IrNode> body;
};

struct CompiledModule {
    std::string source;
    std::string path;
    std::vector<IrNode> document_body;
    std::unordered_map<std::string, TemplateExport> templates;
    std::vector<std::pair<std::string, Value>> use_bindings;
    std::vector<std::string> inject_paths;
    std::shared_ptr<TSTree> tree;
};

class Compiler {
public:
    static CompiledModule compile(std::string path, std::string source, TSNode root);
    static std::vector<IrNode> compilePromptNodes(std::string_view source, const std::vector<TSNode> &nodes);
};

} // namespace openprompt
