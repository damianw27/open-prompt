#pragma once

#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

#include <tree_sitter/api.h>

#include "value.hpp"

namespace openprompt {

struct EvalScope {
    std::unordered_map<std::string, Value> locals;
};

class ConditionEval {
public:
    static bool evaluate(TSNode node, std::string_view source, const Context &context, EvalScope &scope);
};

} // namespace openprompt
