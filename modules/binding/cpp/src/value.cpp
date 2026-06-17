#include "value.hpp"

#include <cmath>
#include <sstream>

namespace openprompt {

bool Value::isTruthy() const {
    switch (kind) {
    case ValueKind::Null:
        return false;
    case ValueKind::Bool:
        return bool_value;
    case ValueKind::Number:
        return number_value != 0.0;
    case ValueKind::String:
        return !string_value.empty();
    case ValueKind::Array:
        return !array_value.empty();
    case ValueKind::Map:
        return !map_value.empty();
    }

    return false;
}

std::string Value::toString() const {
    switch (kind) {
    case ValueKind::Null:
        return "";
    case ValueKind::Bool:
        return bool_value ? "true" : "false";
    case ValueKind::Number: {
        std::ostringstream stream;
        stream << number_value;

        return stream.str();
    }
    case ValueKind::String:
        return string_value;
    case ValueKind::Array: {
        std::ostringstream stream;

        for (std::size_t index = 0; index < array_value.size(); ++index) {
            if (index > 0) {
                stream << ',';
            }

            stream << array_value[index].toString();
        }

        return stream.str();
    }
    case ValueKind::Map:
        return "[object]";
    }

    return "";
}

const Value *Value::lookupPath(const std::vector<std::string_view> &properties) const {
    const Value *current = this;

    for (auto property : properties) {
        if (current->kind != ValueKind::Map) {
            return nullptr;
        }

        auto iterator = current->map_value.find(std::string(property));

        if (iterator == current->map_value.end()) {
            return nullptr;
        }

        current = &iterator->second;
    }

    return current;
}

const Value *Value::lookupTemplate(std::string_view prompt) const {
    if (kind != ValueKind::Map) {
        return nullptr;
    }

    auto iterator = map_value.find(std::string(prompt));

    if (iterator == map_value.end()) {
        return nullptr;
    }

    return &iterator->second;
}

void Context::clear() {
    roots_.clear();
}

void Context::setRoot(std::string root, Value value) {
    roots_[std::move(root)] = std::move(value);
}

const Value *Context::getRoot(std::string_view root) const {
    auto iterator = roots_.find(std::string(root));

    if (iterator == roots_.end()) {
        return nullptr;
    }

    return &iterator->second;
}

} // namespace openprompt
