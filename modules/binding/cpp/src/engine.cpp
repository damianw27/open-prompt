#include "engine.hpp"

#include "compile.hpp"
#include "cst.hpp"

#include <cctype>
#include <sstream>
#include <stdexcept>

extern "C" const TSLanguage *tree_sitter_openprompt(void);

namespace openprompt {

namespace {

TSParser *createParser() {
    auto *parser = ts_parser_new();
    ts_parser_set_language(parser, tree_sitter_openprompt());

    return parser;
}

std::shared_ptr<CompiledModule> compileSource(std::string path, std::string source) {
    auto *parser = createParser();
    const auto tree = ts_parser_parse_string(parser, nullptr, source.c_str(), static_cast<uint32_t>(source.size()));
    const auto root = ts_tree_root_node(tree);

    if (Cst::hasError(root)) {
        ts_tree_delete(tree);
        ts_parser_delete(parser);
        throw std::runtime_error("parse error");
    }

    auto compiled = Compiler::compile(std::move(path), std::move(source), root);
    compiled.tree = std::shared_ptr<TSTree>(tree, ts_tree_delete);
    ts_parser_delete(parser);

    return std::make_shared<CompiledModule>(std::move(compiled));
}

Value parseJsonValue(std::string_view &input);
Value parseJsonObject(std::string_view &input);
Value parseJsonArray(std::string_view &input);

void skipWs(std::string_view &input) {
    while (!input.empty() && (input.front() == ' ' || input.front() == '\t' || input.front() == '\n' || input.front() == '\r')) {
        input.remove_prefix(1);
    }
}

bool consume(std::string_view &input, char ch) {
    skipWs(input);

    if (input.empty() || input.front() != ch) {
        return false;
    }

    input.remove_prefix(1);

    return true;
}

std::string parseJsonString(std::string_view &input) {
    skipWs(input);

    if (input.empty() || input.front() != '"') {
        throw std::runtime_error("invalid json string");
    }

    input.remove_prefix(1);
    std::string out;

    while (!input.empty()) {
        const char ch = input.front();
        input.remove_prefix(1);

        if (ch == '"') {
            return out;
        }

        if (ch == '\\') {
            if (input.empty()) {
                break;
            }

            const char escaped = input.front();
            input.remove_prefix(1);
            out.push_back(escaped);
            continue;
        }

        out.push_back(ch);
    }

    throw std::runtime_error("unterminated json string");
}

Value parseJsonValue(std::string_view &input) {
    skipWs(input);

    if (input.empty()) {
        return Value::makeNull();
    }

    if (input.rfind("null", 0) == 0) {
        input.remove_prefix(4);

        return Value::makeNull();
    }

    if (input.rfind("true", 0) == 0) {
        input.remove_prefix(4);

        return Value::makeBool(true);
    }

    if (input.rfind("false", 0) == 0) {
        input.remove_prefix(5);

        return Value::makeBool(false);
    }

    if (input.front() == '"') {
        return Value::makeString(parseJsonString(input));
    }

    if (input.front() == '{') {
        return parseJsonObject(input);
    }

    if (input.front() == '[') {
        return parseJsonArray(input);
    }

    std::size_t end = 0;

    while (end < input.size() && (std::isdigit(static_cast<unsigned char>(input[end])) || input[end] == '-' ||
                                  input[end] == '+' || input[end] == '.' || input[end] == 'e' || input[end] == 'E')) {
        ++end;
    }

    if (end == 0) {
        throw std::runtime_error("invalid json value");
    }

    const auto number = std::stod(std::string(input.substr(0, end)));
    input.remove_prefix(end);

    return Value::makeNumber(number);
}

Value parseJsonArray(std::string_view &input) {
    if (!consume(input, '[')) {
        throw std::runtime_error("invalid json array");
    }

    std::vector<Value> items;
    skipWs(input);

    if (consume(input, ']')) {
        return Value::makeArray(std::move(items));
    }

    while (true) {
        items.push_back(parseJsonValue(input));
        skipWs(input);

        if (consume(input, ']')) {
            break;
        }

        if (!consume(input, ',')) {
            throw std::runtime_error("invalid json array");
        }
    }

    return Value::makeArray(std::move(items));
}

Value parseJsonObject(std::string_view &input) {
    if (!consume(input, '{')) {
        throw std::runtime_error("invalid json object");
    }

    std::unordered_map<std::string, Value> items;
    skipWs(input);

    if (consume(input, '}')) {
        return Value::makeMap(std::move(items));
    }

    while (true) {
        const auto key = parseJsonString(input);

        if (!consume(input, ':')) {
            throw std::runtime_error("invalid json object");
        }

        items[key] = parseJsonValue(input);
        skipWs(input);

        if (consume(input, '}')) {
            break;
        }

        if (!consume(input, ',')) {
            throw std::runtime_error("invalid json object");
        }
    }

    return Value::makeMap(std::move(items));
}

} // namespace

Engine::Engine(std::unique_ptr<Vfs> vfs)
    : vfs_(std::move(vfs)), evaluator_(*vfs_, context_) {}

void Engine::reset() {
    context_.clear();
    module_.reset();
    last_error_.clear();
}

void Engine::registerModule(std::string_view path, std::string_view source) {
    vfs_->write(path, source);
}

void Engine::setContextJson(std::string_view json) {
    std::string_view input = json;
    const auto value = parseJsonValue(input);

    if (value.kind != ValueKind::Map) {
        throw std::runtime_error("context json must be an object");
    }

    context_.clear();

    for (const auto &[key, item] : value.map_value) {
        context_.setRoot(key, item);
    }
}

void Engine::setContextRoot(std::string root, Value value) {
    context_.setRoot(std::move(root), std::move(value));
}

void Engine::loadString(std::string_view source, std::string_view base_path) {
    module_ = compileSource(std::string(base_path), std::string(source));
}

void Engine::loadFile(std::string_view path) {
    std::string source;

    if (!vfs_->read(path, source)) {
        throw std::runtime_error("unable to read file: " + std::string(path));
    }

    module_ = compileSource(std::string(path), std::move(source));
}

std::string Engine::render() {
    if (module_ == nullptr) {
        throw std::runtime_error("no template loaded");
    }

    return evaluator_.renderModule(*module_);
}

std::string Engine::renderTemplate(std::string_view name) {
    if (module_ == nullptr) {
        throw std::runtime_error("no template loaded");
    }

    return evaluator_.renderTemplate(*module_, name);
}

std::string Engine::lastError() const {
    return last_error_;
}

void Engine::setError(std::string message) {
    last_error_ = std::move(message);
}

} // namespace openprompt
