const std = @import("std");
const ts = @import("tree-sitter");

extern fn tree_sitter_openprompt() callconv(.c) *const ts.Language;
extern fn tree_sitter_javascript() callconv(.c) *const ts.Language;
extern fn tree_sitter_java() callconv(.c) *const ts.Language;
extern fn tree_sitter_cpp() callconv(.c) *const ts.Language;
extern fn tree_sitter_typescript() callconv(.c) *const ts.Language;
extern fn tree_sitter_tsx() callconv(.c) *const ts.Language;
extern fn tree_sitter_lua() callconv(.c) *const ts.Language;
extern fn tree_sitter_zig() callconv(.c) *const ts.Language;

pub const HostLanguage = enum {
    cpp,
    java,
    javascript,
    typescript,
    lua,
    zig,

    pub fn fromPath(path: []const u8) ?HostLanguage {
        const ext = std.fs.path.extension(path);
        if (ext.len == 0) {
            return null;
        }

        if (std.ascii.eqlIgnoreCase(ext, ".cpp") or
            std.ascii.eqlIgnoreCase(ext, ".cc") or
            std.ascii.eqlIgnoreCase(ext, ".cxx") or
            std.ascii.eqlIgnoreCase(ext, ".h") or
            std.ascii.eqlIgnoreCase(ext, ".hpp"))
        {
            return .cpp;
        }
        if (std.ascii.eqlIgnoreCase(ext, ".java")) {
            return .java;
        }
        if (std.ascii.eqlIgnoreCase(ext, ".js") or
            std.ascii.eqlIgnoreCase(ext, ".jsx") or
            std.ascii.eqlIgnoreCase(ext, ".mjs") or
            std.ascii.eqlIgnoreCase(ext, ".cjs"))
        {
            return .javascript;
        }
        if (std.ascii.eqlIgnoreCase(ext, ".ts") or std.ascii.eqlIgnoreCase(ext, ".tsx")) {
            return .typescript;
        }
        if (std.ascii.eqlIgnoreCase(ext, ".lua")) {
            return .lua;
        }
        if (std.ascii.eqlIgnoreCase(ext, ".zig")) {
            return .zig;
        }

        return null;
    }

    pub fn treeSitterLanguage(self: HostLanguage) *const ts.Language {
        return switch (self) {
            .cpp => tree_sitter_cpp(),
            .java => tree_sitter_java(),
            .javascript => tree_sitter_javascript(),
            .typescript => tree_sitter_typescript(),
            .lua => tree_sitter_lua(),
            .zig => tree_sitter_zig(),
        };
    }
};

pub fn openPromptLanguage() *const ts.Language {
    return tree_sitter_openprompt();
}

pub fn tsxLanguage() *const ts.Language {
    return tree_sitter_tsx();
}
