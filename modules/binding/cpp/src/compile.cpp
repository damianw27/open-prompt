#include "compile.hpp"

#include "cst.hpp"
#include "value.hpp"

#include <functional>

namespace openprompt {
namespace {

std::vector<TSNode> collectPromptContent(TSNode parent) {
    std::vector<TSNode> nodes;

    for (const auto child : Cst::namedChildren(parent)) {
        const auto kind = std::string_view(ts_node_type(child));

        if (kind == "prompt_content") {
            nodes.push_back(child);
        }
    }

    return nodes;
}

Value parseUseValue(std::string_view source, TSNode value_node) {
    auto kind = std::string_view(ts_node_type(value_node));

    if (kind == "use_value") {
        const auto children = Cst::namedChildren(value_node);

        if (!children.empty()) {
            kind = std::string_view(ts_node_type(children[0]));
            value_node = children[0];
        }
    }

    if (kind == "number") {
        return Value::makeNumber(std::stod(std::string(Cst::nodeText(source, value_node))));
    }

    if (kind == "boolean") {
        return Value::makeBool(Cst::nodeText(source, value_node) == "true");
    }

    if (kind == "directive_path") {
        const auto path_children = Cst::namedChildren(value_node);

        if (!path_children.empty()) {
            return Value::makeString(Cst::decodeString(Cst::nodeText(source, path_children[0])));
        }
    }

    return Value::makeString(Cst::decodeString(Cst::nodeText(source, value_node)));
}

} // namespace

std::vector<IrNode> Compiler::compilePromptNodes(std::string_view source, const std::vector<TSNode> &nodes) {
    std::vector<IrNode> output;

    const auto is_special_content = [](std::string_view child_kind) -> bool {
        return child_kind == "interpolation" || child_kind == "conditional_block" || child_kind == "for_loop" ||
               child_kind == "inject_directive" || child_kind == "prompt_content" || child_kind == "markdown_block" ||
               child_kind == "markdown_inline" || child_kind == "list_item" || child_kind == "ordered_list_item";
    };

    const auto append_text_span = [&](uint32_t start_byte, uint32_t end_byte) {
        if (end_byte <= start_byte) {
            return;
        }

        IrNode item;
        item.kind = IrKind::Text;
        item.text_start = start_byte;
        item.text_end = end_byte;
        output.push_back(item);
    };

    const std::function<void(TSNode)> appendNode = [&](TSNode node) {
        const auto kind = std::string_view(ts_node_type(node));

        if (kind == "prompt_content") {
            for (const auto child : Cst::namedChildren(node)) {
                appendNode(child);
            }

            return;
        }

        if (kind == "markdown_block" || kind == "markdown_inline" || kind == "list_item" ||
            kind == "ordered_list_item") {
            std::vector<TSNode> special_children;

            for (const auto child : Cst::namedChildren(node)) {
                const auto child_kind = std::string_view(ts_node_type(child));

                if (is_special_content(child_kind)) {
                    special_children.push_back(child);
                }
            }

            if (special_children.empty()) {
                append_text_span(ts_node_start_byte(node), ts_node_end_byte(node));

                return;
            }

            uint32_t cursor = ts_node_start_byte(node);

            for (const auto special_child : special_children) {
                const auto special_start = ts_node_start_byte(special_child);
                const auto special_end = ts_node_end_byte(special_child);

                append_text_span(cursor, special_start);
                appendNode(special_child);
                cursor = special_end;
            }

            append_text_span(cursor, ts_node_end_byte(node));

            return;
        }

        if (kind == "interpolation") {
            const auto variable_node = Cst::childByFieldName(node, "variable");
            const auto root_node = Cst::childByFieldName(variable_node, "root");
            IrNode item;
            item.kind = IrKind::Interpolation;
            item.interpolation.root = Cst::stripVariable(Cst::nodeText(source, root_node));

            for (const auto segment : Cst::findChildren(variable_node, "variable_path_segment")) {
                const auto property_node = Cst::childByFieldName(segment, "property");
                item.interpolation.properties.push_back(std::string(Cst::nodeText(source, property_node)));
            }

            const auto selections = Cst::findChildren(variable_node, "prompt_selection");

            if (!selections.empty()) {
                const auto prompt_node = Cst::childByFieldName(selections[0], "prompt");
                item.interpolation.prompt = Cst::decodeString(Cst::nodeText(source, prompt_node));
                item.interpolation.has_prompt = true;
            }

            output.push_back(item);
            return;
        }

        if (kind == "conditional_block") {
            IrNode item;
            item.kind = IrKind::Conditional;
            enum class BranchState { True, ElseIf, Else } state = BranchState::True;

            for (const auto block_child : Cst::namedChildren(node)) {
                const auto block_kind = std::string_view(ts_node_type(block_child));

                    if (block_kind == "if_start") {
                        item.conditional.condition = Cst::childByFieldName(block_child, "condition");

                        if (ts_node_is_null(item.conditional.condition)) {
                            const auto conditions = Cst::findChildren(block_child, "condition_expr");

                            if (!conditions.empty()) {
                                item.conditional.condition = conditions[0];
                            }
                        }

                        state = BranchState::True;
                        continue;
                    }

                if (block_kind == "elseif_branch") {
                    state = BranchState::ElseIf;
                    item.conditional.elseif_branches.emplace_back();

                    for (const auto branch_child : Cst::namedChildren(block_child)) {
                        const auto branch_kind = std::string_view(ts_node_type(branch_child));

                        if (branch_kind == "elseif_start") {
                            auto condition = Cst::childByFieldName(branch_child, "condition");

                            if (ts_node_is_null(condition)) {
                                const auto conditions = Cst::findChildren(branch_child, "condition_expr");

                                if (!conditions.empty()) {
                                    condition = conditions[0];
                                }
                            }

                            item.conditional.elseif_conditions.push_back(condition);
                        } else if (branch_kind == "prompt_content") {
                            item.conditional.elseif_branches.back().push_back(branch_child);
                        }
                    }

                    continue;
                }

                if (block_kind == "else_branch") {
                    state = BranchState::Else;
                    item.conditional.else_branch = collectPromptContent(block_child);
                    continue;
                }

                if (block_kind == "prompt_content" && state == BranchState::True) {
                    item.conditional.true_branch.push_back(block_child);
                }
            }

            output.push_back(item);
            return;
        }

        if (kind == "for_loop") {
            IrNode item;
            item.kind = IrKind::ForLoop;

            for (const auto loop_child : Cst::namedChildren(node)) {
                const auto loop_kind = std::string_view(ts_node_type(loop_child));

                if (loop_kind == "for_start") {
                    const auto variable_node = Cst::childByFieldName(loop_child, "variable");
                    const auto iterable_node = Cst::childByFieldName(loop_child, "iterable");
                    item.loop.variable = Cst::stripVariable(Cst::nodeText(source, variable_node));
                    item.loop.iterable = std::string(Cst::nodeText(source, iterable_node));
                } else if (loop_kind == "prompt_content") {
                    item.loop.body.push_back(loop_child);
                }
            }

            output.push_back(item);
            return;
        }

        if (kind == "inject_directive") {
            const auto path_node = Cst::childByFieldName(node, "path");
            IrNode item;
            item.kind = IrKind::Inject;
            item.inject_path = Cst::decodeString(Cst::nodeText(source, path_node));
            output.push_back(item);
        }
    };

    for (const auto node : nodes) {
        appendNode(node);
    }

    return output;
}

CompiledModule Compiler::compile(std::string path, std::string source, TSNode root) {
    CompiledModule module;
    module.source = std::move(source);
    module.path = std::move(path);

    for (const auto element : Cst::namedChildren(root)) {
        const auto kind = std::string_view(ts_node_type(element));

        if (kind == "front_matter") {
            continue;
        }

        if (kind == "use_directive") {
            const auto value_node = Cst::childByFieldName(element, "value");
            const auto alias_node = Cst::childByFieldName(element, "alias");
            module.use_bindings.emplace_back(
                Cst::stripVariable(Cst::nodeText(module.source, alias_node)),
                parseUseValue(module.source, value_node));
            continue;
        }

        if (kind == "sub_prompt") {
            TemplateExport export_item;

            for (const auto child : Cst::namedChildren(element)) {
                const auto child_kind = std::string_view(ts_node_type(child));

                if (child_kind == "template_start") {
                    const auto name_node = Cst::childByFieldName(child, "name");
                    export_item.name = Cst::decodeString(Cst::nodeText(module.source, name_node));
                } else if (child_kind == "meta_block") {
                    continue;
                } else if (child_kind == "prompt_content") {
                    const auto chunk = compilePromptNodes(module.source, {child});
                    export_item.body.insert(export_item.body.end(), chunk.begin(), chunk.end());
                }
            }

            if (!export_item.name.empty()) {
                module.templates[export_item.name] = std::move(export_item);
            }

            continue;
        }

        if (kind == "document_element") {
            for (const auto child : Cst::namedChildren(element)) {
                const auto child_kind = std::string_view(ts_node_type(child));

                if (child_kind == "use_directive") {
                    const auto value_node = Cst::childByFieldName(child, "value");
                    const auto alias_node = Cst::childByFieldName(child, "alias");
                    module.use_bindings.emplace_back(
                        Cst::stripVariable(Cst::nodeText(module.source, alias_node)),
                        parseUseValue(module.source, value_node));
                } else if (child_kind == "sub_prompt") {
                    TemplateExport export_item;

                    for (const auto sub_child : Cst::namedChildren(child)) {
                        const auto sub_kind = std::string_view(ts_node_type(sub_child));

                        if (sub_kind == "template_start") {
                            const auto name_node = Cst::childByFieldName(sub_child, "name");
                            export_item.name = Cst::decodeString(Cst::nodeText(module.source, name_node));
                        } else if (sub_kind == "meta_block") {
                            continue;
                        } else if (sub_kind == "prompt_content") {
                            const auto chunk = compilePromptNodes(module.source, {sub_child});
                            export_item.body.insert(export_item.body.end(), chunk.begin(), chunk.end());
                        }
                    }

                    if (!export_item.name.empty()) {
                        module.templates[export_item.name] = std::move(export_item);
                    }
                } else if (child_kind == "prompt_content") {
                    const auto compiled = compilePromptNodes(module.source, {child});
                    module.document_body.insert(module.document_body.end(), compiled.begin(), compiled.end());
                }
            }

            continue;
        }

        if (kind == "prompt_content") {
            const auto compiled = compilePromptNodes(module.source, {element});
            module.document_body.insert(module.document_body.end(), compiled.begin(), compiled.end());
        }
    }

    return module;
}

} // namespace openprompt
