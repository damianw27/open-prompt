#pragma once

#include <string>
#include <string_view>
#include <vector>

#include <tree_sitter/api.h>

namespace openprompt {

class Cst {
public:
    static TSNode childByFieldName(TSNode node, const char *name);
    static std::vector<TSNode> namedChildren(TSNode node);
    static std::vector<TSNode> findChildren(TSNode node, const char *kind);
    static std::string_view nodeText(std::string_view source, TSNode node);
    static bool hasError(TSNode node);
    static std::string decodeString(std::string_view raw);
    static std::string stripVariable(std::string_view raw);
};

} // namespace openprompt
