#pragma once

#include <cstddef>
#include <memory>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

namespace openprompt {

enum class ValueKind {
    Null,
    Bool,
    Number,
    String,
    Array,
    Map,
};

struct Value {
    ValueKind kind = ValueKind::Null;
    bool bool_value = false;
    double number_value = 0.0;
    std::string string_value;
    std::vector<Value> array_value;
    std::unordered_map<std::string, Value> map_value;

    static Value makeNull() {
        return {};
    }

    static Value makeBool(bool value) {
        Value out;
        out.kind = ValueKind::Bool;
        out.bool_value = value;

        return out;
    }

    static Value makeNumber(double value) {
        Value out;
        out.kind = ValueKind::Number;
        out.number_value = value;

        return out;
    }

    static Value makeString(std::string value) {
        Value out;
        out.kind = ValueKind::String;
        out.string_value = std::move(value);

        return out;
    }

    static Value makeArray(std::vector<Value> items) {
        Value out;
        out.kind = ValueKind::Array;
        out.array_value = std::move(items);

        return out;
    }

    static Value makeMap(std::unordered_map<std::string, Value> items) {
        Value out;
        out.kind = ValueKind::Map;
        out.map_value = std::move(items);

        return out;
    }

    bool isTruthy() const;
    std::string toString() const;
    const Value *lookupPath(const std::vector<std::string_view> &properties) const;
    const Value *lookupTemplate(std::string_view prompt) const;
};

class Context {
public:
    void clear();
    void setRoot(std::string root, Value value);
    const Value *getRoot(std::string_view root) const;

private:
    std::unordered_map<std::string, Value> roots_;
};

} // namespace openprompt
