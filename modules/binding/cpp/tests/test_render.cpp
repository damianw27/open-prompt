#include "openprompt.h"

#include <cassert>
#include <cstring>
#include <iostream>
#include <string>

namespace {

int failures = 0;

void expectContains(const std::string &haystack, const std::string &needle, const char *name) {
    if (haystack.find(needle) == std::string::npos) {
        std::cerr << "FAIL " << name << ": expected to find '" << needle << "' in output\n";
        ++failures;
    } else {
        std::cout << "PASS " << name << '\n';
    }
}

void expectStatus(op_status status, op_status expected, const char *name) {
    if (status != expected) {
        std::cerr << "FAIL " << name << ": status " << status << " != " << expected << '\n';
        ++failures;
    } else {
        std::cout << "PASS " << name << '\n';
    }
}

} // namespace

int main() {
    auto *vfs = op_vfs_memory();
    auto *engine = op_engine_create(vfs);

    const char *common = "[[@template example]]\n\n## Example Section\n\n[[@end]]\n";
    op_engine_register_module(engine, "common.op", common, std::strlen(common));

    const char *template_source = R"(---
title: Review
---
[[@use "common.op" as $prompts]]
[[@use 14 as $value]]

# Hello

Hello {{ $user.name }}

Test {{ $prompts.example }}

[[@if $user.age >= 18]]
Adult
[[@elseif $user.age == 17]]
Almost adult
[[@else]]
Minor
[[@end]]

[[@for $item in items]]
- {{ $item.name }}
[[@end]]
)";

    const char *context = R"({
  "user": { "name": "Ada", "age": 18 },
  "items": [ { "name": "one" }, { "name": "two" } ]
})";

    expectStatus(op_engine_load_string(engine, template_source, std::strlen(template_source), "basic.op"), OP_OK,
                 "load_string");
    expectStatus(op_engine_set_context_json(engine, context, std::strlen(context)), OP_OK, "set_context");

    char *output = nullptr;
    size_t output_len = 0;
    expectStatus(op_engine_render(engine, &output, &output_len), OP_OK, "render");

    if (output == nullptr) {
        char *err = nullptr;
        size_t err_len = 0;
        op_engine_last_error(engine, &err, &err_len);
        std::cerr << "render error: " << std::string(err, err_len) << '\n';
        op_string_free(err);
    }

    const std::string rendered(output != nullptr ? std::string(output, output_len) : "");
    op_string_free(output);

    expectContains(rendered, "Hello Ada", "interpolation");
    expectContains(rendered, "Adult", "conditional_true");
    expectContains(rendered, "## Example Section", "template_use");
    expectContains(rendered, "- one", "for_loop_list_marker");
    expectContains(rendered, "- two", "for_loop_second");

    op_engine_destroy(engine);

    return failures == 0 ? 0 : 1;
}
