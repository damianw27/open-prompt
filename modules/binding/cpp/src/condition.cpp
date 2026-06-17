#include "condition.hpp"

#include "cst.hpp"

#include <cmath>

namespace openprompt {

namespace {

Value evalPrimary(TSNode node, std::string_view source, const Context &context, EvalScope &scope) {
    const auto kind = std::string_view(ts_node_type(node));

    if (kind == "cond_primary_expr" || kind == "cond_unary_expr") {
        for (const auto child : Cst::namedChildren(node)) {
            return evalPrimary(child, source, context, scope);
        }

        return Value::makeNull();
    }

    if (kind == "boolean" || kind == "true" || kind == "false") {
        const auto text = kind == "boolean" ? Cst::nodeText(source, node) : kind;

        return Value::makeBool(text == "true");
    }

    if (kind == "null") {
        return Value::makeNull();
    }

    if (kind == "number" || kind == "float") {
        const auto text = Cst::nodeText(source, node);

        return Value::makeNumber(std::stod(std::string(text)));
    }

    if (kind == "string") {
        return Value::makeString(Cst::decodeString(Cst::nodeText(source, node)));
    }

    if (kind == "cond_variable_ref") {
        const auto root_node = Cst::childByFieldName(node, "root");
        const auto root = Cst::stripVariable(Cst::nodeText(source, root_node));
        std::vector<std::string_view> properties;

        properties.clear();

        for (const auto child : Cst::namedChildren(node)) {
            if (std::string_view(ts_node_type(child)) == "identifier") {
                properties.push_back(Cst::nodeText(source, child));
            }
        }

        if (auto iterator = scope.locals.find(root); iterator != scope.locals.end()) {
            if (const auto *value = iterator->second.lookupPath(properties)) {
                return *value;
            }
        }

        if (const auto *root_value = context.getRoot(root)) {
            if (const auto *value = root_value->lookupPath(properties)) {
                return *value;
            }
        }

        return Value::makeNull();
    }

    if (kind == "condition_expr") {
        return ConditionEval::evaluate(node, source, context, scope) ? Value::makeBool(true) : Value::makeNull();
    }

    for (const auto child : Cst::namedChildren(node)) {
        if (std::string_view(ts_node_type(child)) == "condition_expr") {
            return ConditionEval::evaluate(child, source, context, scope) ? Value::makeBool(true) : Value::makeNull();
        }
    }

    return Value::makeNull();
}

Value evalUnary(TSNode node, std::string_view source, const Context &context, EvalScope &scope) {
    const auto kind = std::string_view(ts_node_type(node));
    const auto text = Cst::nodeText(source, node);

    if (kind == "cond_unary_expr" && text.rfind("not", 0) == 0) {
        for (const auto child : Cst::namedChildren(node)) {
            if (std::string_view(ts_node_type(child)) == "cond_unary_expr") {
                return Value::makeBool(!evalUnary(child, source, context, scope).isTruthy());
            }
        }
    }

    if (kind == "cond_primary_expr") {
        for (const auto child : Cst::namedChildren(node)) {
            return evalPrimary(child, source, context, scope);
        }
    }

    if (kind == "cond_unary_expr") {
        for (const auto child : Cst::namedChildren(node)) {
            if (std::string_view(ts_node_type(child)) == "cond_primary_expr") {
                return evalPrimary(child, source, context, scope);
            }
        }
    }

    return evalPrimary(node, source, context, scope);
}

bool applyOperator(std::string_view op, const Value &left, const Value &right) {
    while (!op.empty() && (op.front() == ' ' || op.front() == '\t')) {
        op.remove_prefix(1);
    }

    while (!op.empty() && (op.back() == ' ' || op.back() == '\t')) {
        op.remove_suffix(1);
    }

    if (op == "==") {
        if (left.kind == ValueKind::Number && right.kind == ValueKind::Number) {
            return left.number_value == right.number_value;
        }

        return left.toString() == right.toString();
    }

    if (op == "!=") {
        if (left.kind == ValueKind::Number && right.kind == ValueKind::Number) {
            return left.number_value != right.number_value;
        }

        return left.toString() != right.toString();
    }

    if (op == "<") {
        return left.number_value < right.number_value;
    }

    if (op == ">") {
        return left.number_value > right.number_value;
    }

    if (op == "<=") {
        return left.number_value <= right.number_value;
    }

    if (op == ">=") {
        const auto left_number = left.kind == ValueKind::Number ? left.number_value : std::stod(left.toString());
        const auto right_number = right.kind == ValueKind::Number ? right.number_value : std::stod(right.toString());

        return left_number >= right_number;
    }

    if (op == "and") {
        return left.isTruthy() && right.isTruthy();
    }

    if (op == "or") {
        return left.isTruthy() || right.isTruthy();
    }

    if (op == "in") {
        if (right.kind == ValueKind::Array) {
            const auto left_string = left.toString();

            for (const auto &item : right.array_value) {
                if (item.toString() == left_string) {
                    return true;
                }
            }

            return false;
        }

        return right.toString().find(left.toString()) != std::string::npos;
    }

    if (op == "matches") {
        return right.toString().find(left.toString()) != std::string::npos;
    }

    return false;
}

} // namespace

bool ConditionEval::evaluate(TSNode node, std::string_view source, const Context &context, EvalScope &scope) {
    const uint32_t child_count = ts_node_child_count(node);
    std::vector<Value> values;
    std::vector<std::string_view> operators;

    for (uint32_t index = 0; index < child_count; ++index) {
        const auto child = ts_node_child(node, index);
        const auto kind = std::string_view(ts_node_type(child));

        if (kind == "cond_unary_expr") {
            values.push_back(evalUnary(child, source, context, scope));
            continue;
        }

        if (kind == "cond_operator") {
            operators.push_back(Cst::nodeText(source, child));
        }
    }

    if (values.empty()) {
        return false;
    }

    Value current = values.front();

    for (std::size_t index = 0; index < operators.size() && index + 1 < values.size(); ++index) {
        current = Value::makeBool(applyOperator(operators[index], current, values[index + 1]));
    }

    return current.isTruthy();
}

} // namespace openprompt
