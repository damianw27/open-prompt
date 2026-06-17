const std = @import("std");
const ts = @import("tree-sitter");
const ast = @import("ast.zig");
const language = @import("language.zig");

pub const ParsedDocument = struct {
    tree: *ts.Tree,
    ast: ast.Document,
    source: []const u8,

    pub fn deinit(self: *ParsedDocument, allocator: std.mem.Allocator) void {
        self.tree.destroy();
        self.ast.deinit(allocator);
        allocator.free(self.source);
        self.* = undefined;
    }
};

pub const Parser = struct {
    parser: *ts.Parser,
    language: *const ts.Language,

    pub fn init() !Parser {
        const parser = ts.Parser.create();
        const lang = language.openPromptLanguage();
        try parser.setLanguage(lang);

        return .{
            .parser = parser,
            .language = lang,
        };
    }

    pub fn deinit(self: *Parser) void {
        self.parser.destroy();
        self.* = undefined;
    }

    pub fn parse(self: *Parser, allocator: std.mem.Allocator, source: []const u8, old_tree: ?*ts.Tree) !ParsedDocument {
        const owned = try allocator.dupe(u8, source);
        errdefer allocator.free(owned);

        const tree = self.parser.parseString(owned, old_tree) orelse {
            allocator.free(owned);
            return error.ParseFailed;
        };

        const root = tree.rootNode();
        const document = try ast.buildDocument(allocator, owned, root);

        return .{
            .tree = tree,
            .ast = document,
            .source = owned,
        };
    }
};
