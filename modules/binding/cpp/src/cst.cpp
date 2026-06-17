#include "cst.hpp"

#include <cstring>
#include <string>

namespace openprompt {

TSNode Cst::childByFieldName(TSNode node, const char *name) {
    return ts_node_child_by_field_name(node, name, ::strlen(name));
}

std::vector<TSNode> Cst::namedChildren(TSNode node) {
    std::vector<TSNode> children;
    const uint32_t count = ts_node_named_child_count(node);

    for (uint32_t index = 0; index < count; ++index) {
        children.push_back(ts_node_named_child(node, index));
    }

    return children;
}

std::vector<TSNode> Cst::findChildren(TSNode node, const char *kind) {
    std::vector<TSNode> matches;

    if (std::string_view(ts_node_type(node)) == kind) {
        matches.push_back(node);
    }

    const uint32_t count = ts_node_child_count(node);

    for (uint32_t index = 0; index < count; ++index) {
        const auto child_matches = findChildren(ts_node_child(node, index), kind);
        matches.insert(matches.end(), child_matches.begin(), child_matches.end());
    }

    return matches;
}

std::string_view Cst::nodeText(std::string_view source, TSNode node) {
    const uint32_t start = ts_node_start_byte(node);
    const uint32_t end = ts_node_end_byte(node);

    if (start >= source.size() || end > source.size() || start > end) {
        return {};
    }

    return source.substr(start, end - start);
}

bool Cst::hasError(TSNode node) {
    if (ts_node_has_error(node)) {
        return true;
    }

    const uint32_t count = ts_node_child_count(node);

    for (uint32_t index = 0; index < count; ++index) {
        if (hasError(ts_node_child(node, index))) {
            return true;
        }
    }

    return false;
}

std::string Cst::decodeString(std::string_view raw) {
    if (raw.size() < 2) {
        return std::string(raw);
    }

    const char quote = raw.front();

    if (quote != '"' && quote != '\'') {
        return std::string(raw);
    }

    if (raw.back() != quote) {
        return std::string(raw);
    }

    return std::string(raw.substr(1, raw.size() - 2));
}

std::string Cst::stripVariable(std::string_view raw) {
    if (!raw.empty() && raw.front() == '$') {
        return std::string(raw.substr(1));
    }

    return std::string(raw);
}

} // namespace openprompt
