const std = @import("std");
const ts = @import("tree-sitter");
const util = @import("../util.zig");
const cst = @import("cst.zig");
const front_matter = @import("front_matter.zig");

const Node = ts.Node;

pub const UseDirective = struct {
    path: []const u8,
    alias: []const u8,
    range: util.ByteRange,
};

pub const InjectDirective = struct {
    path: []const u8,
    range: util.ByteRange,
};

pub const Template = struct {
    name: []const u8,
    range: util.ByteRange,
    meta: []MetaEntry,
};

pub const MetaEntry = struct {
    key: []const u8,
    value: []const u8,
};

pub const ForLoop = struct {
    variable: []const u8,
    iterable: []const u8,
    body_range: util.ByteRange,
    range: util.ByteRange,
};

pub const VariableRef = struct {
    root: []const u8,
    properties: []const []const u8,
    prompt: ?[]const u8,
    range: util.ByteRange,
};

pub const ParseError = struct {
    message: []const u8,
    range: util.ByteRange,
};

pub const Document = struct {
    uses: []UseDirective,
    injects: []InjectDirective,
    templates: []Template,
    for_loops: []ForLoop,
    variable_refs: []VariableRef,
    front_matter: front_matter.Document,
    front_matter_lines: []const []const u8,
    context_paths: []const []const u8,
    has_errors: bool,

    pub fn deinit(self: *Document, allocator: std.mem.Allocator) void {
        for (self.uses) |item| {
            allocator.free(item.path);
            allocator.free(item.alias);
        }
        allocator.free(self.uses);

        for (self.injects) |item| {
            allocator.free(item.path);
        }
        allocator.free(self.injects);

        for (self.templates) |item| {
            allocator.free(item.name);
            for (item.meta) |meta| {
                allocator.free(meta.key);
                allocator.free(meta.value);
            }
            allocator.free(item.meta);
        }
        allocator.free(self.templates);

        for (self.for_loops) |item| {
            allocator.free(item.variable);
            allocator.free(item.iterable);
        }
        allocator.free(self.for_loops);

        for (self.variable_refs) |item| {
            allocator.free(item.root);
            for (item.properties) |prop| allocator.free(prop);
            allocator.free(item.properties);
            if (item.prompt) |prompt| allocator.free(prompt);
        }
        allocator.free(self.variable_refs);

        self.front_matter.deinit(allocator);
        for (self.front_matter_lines) |line| allocator.free(line);
        allocator.free(self.front_matter_lines);
        for (self.context_paths) |path| allocator.free(path);
        allocator.free(self.context_paths);
        self.* = undefined;
    }
};

pub fn buildDocument(allocator: std.mem.Allocator, source: []const u8, root: Node) !Document {
    const uses = try cst.findChildren(root, "use_directive", allocator);
    defer allocator.free(uses);
    const injects = try cst.findChildren(root, "inject_directive", allocator);
    defer allocator.free(injects);
    const templates = try cst.findChildren(root, "sub_prompt", allocator);
    defer allocator.free(templates);
    const for_loops = try cst.findChildren(root, "for_loop", allocator);
    defer allocator.free(for_loops);
    const interpolations = try cst.findChildren(root, "interpolation", allocator);
    defer allocator.free(interpolations);
    const cond_refs = try cst.findChildren(root, "cond_variable_ref", allocator);
    defer allocator.free(cond_refs);

    var use_list: std.ArrayList(UseDirective) = .empty;
    errdefer {
        for (use_list.items) |item| {
            allocator.free(item.path);
            allocator.free(item.alias);
        }
        use_list.deinit(allocator);
    }

    for (uses) |node| {
        const value_node = cst.childByFieldName(node, "value") orelse continue;
        const alias_node = cst.childByFieldName(node, "alias") orelse continue;
        const path_text = util.decodeString(cst.nodeText(source, value_node));
        const alias_text = cst.nodeText(source, alias_node);
        const alias = if (alias_text.len > 0 and alias_text[0] == '$') alias_text[1..] else alias_text;

        try use_list.append(allocator, .{
            .path = try allocator.dupe(u8, path_text),
            .alias = try allocator.dupe(u8, alias),
            .range = byteRange(node),
        });
    }

    var inject_list: std.ArrayList(InjectDirective) = .empty;
    errdefer {
        for (inject_list.items) |item| allocator.free(item.path);
        inject_list.deinit(allocator);
    }

    for (injects) |node| {
        const path_node = cst.childByFieldName(node, "path") orelse continue;
        const path_text = util.decodeString(cst.nodeText(source, path_node));
        try inject_list.append(allocator, .{
            .path = try allocator.dupe(u8, path_text),
            .range = byteRange(node),
        });
    }

    var template_list: std.ArrayList(Template) = .empty;
    errdefer {
        for (template_list.items) |item| {
            allocator.free(item.name);
            for (item.meta) |meta| {
                allocator.free(meta.key);
                allocator.free(meta.value);
            }
            allocator.free(item.meta);
        }
        template_list.deinit(allocator);
    }

    for (templates) |node| {
        const starts = try cst.findChildren(node, "template_start", allocator);
        defer allocator.free(starts);
        if (starts.len == 0) {
            continue;
        }
        const start_node = starts[0];
        const name_node = cst.childByFieldName(start_node, "name") orelse continue;
        const name = util.decodeString(cst.nodeText(source, name_node));
        const meta_nodes = try cst.findChildren(node, "meta_entry", allocator);
        defer allocator.free(meta_nodes);

        var meta_entries: std.ArrayList(MetaEntry) = .empty;
        errdefer {
            for (meta_entries.items) |meta| {
                allocator.free(meta.key);
                allocator.free(meta.value);
            }
            meta_entries.deinit(allocator);
        }

        for (meta_nodes) |meta_node| {
            const key_node = cst.childByFieldName(meta_node, "key") orelse continue;
            const value_node = cst.childByFieldName(meta_node, "value") orelse continue;
            try meta_entries.append(allocator, .{
                .key = try allocator.dupe(u8, cst.nodeText(source, key_node)),
                .value = try allocator.dupe(u8, util.decodeString(cst.nodeText(source, value_node))),
            });
        }

        try template_list.append(allocator, .{
            .name = try allocator.dupe(u8, name),
            .range = byteRange(node),
            .meta = try meta_entries.toOwnedSlice(allocator),
        });
    }

    var for_list: std.ArrayList(ForLoop) = .empty;
    errdefer {
        for (for_list.items) |item| {
            allocator.free(item.variable);
            allocator.free(item.iterable);
        }
        for_list.deinit(allocator);
    }

    for (for_loops) |node| {
        const starts = try cst.findChildren(node, "for_start", allocator);
        defer allocator.free(starts);
        if (starts.len == 0) {
            continue;
        }
        const start = starts[0];
        const variable_node = cst.childByFieldName(start, "variable") orelse continue;
        const iterable_node = cst.childByFieldName(start, "iterable") orelse continue;
        const variable_text = cst.nodeText(source, variable_node);
        const variable = if (variable_text.len > 0 and variable_text[0] == '$') variable_text[1..] else variable_text;

        try for_list.append(allocator, .{
            .variable = try allocator.dupe(u8, variable),
            .iterable = try allocator.dupe(u8, cst.nodeText(source, iterable_node)),
            .body_range = byteRange(node),
            .range = byteRange(node),
        });
    }

    var ref_list: std.ArrayList(VariableRef) = .empty;
    errdefer {
        for (ref_list.items) |item| {
            allocator.free(item.root);
            for (item.properties) |prop| allocator.free(prop);
            allocator.free(item.properties);
            if (item.prompt) |prompt| allocator.free(prompt);
        }
        ref_list.deinit(allocator);
    }

    for (interpolations) |node| {
        const variable_node = cst.childByFieldName(node, "variable") orelse continue;
        try appendVariableRef(allocator, source, variable_node, byteRange(node), &ref_list);
    }

    for (cond_refs) |node| {
        try appendVariableRef(allocator, source, node, byteRange(node), &ref_list);
    }

    const fm_lines = try collectFrontMatterLines(allocator, source, root);
    errdefer {
        for (fm_lines) |line| allocator.free(line);
        allocator.free(fm_lines);
    }
    const fm_doc = try front_matter.parseLines(allocator, fm_lines);
    const context_paths = try front_matter.collectContextPaths(allocator, fm_doc);

    return .{
        .uses = try use_list.toOwnedSlice(allocator),
        .injects = try inject_list.toOwnedSlice(allocator),
        .templates = try template_list.toOwnedSlice(allocator),
        .for_loops = try for_list.toOwnedSlice(allocator),
        .variable_refs = try ref_list.toOwnedSlice(allocator),
        .front_matter = fm_doc,
        .front_matter_lines = fm_lines,
        .context_paths = context_paths,
        .has_errors = cst.hasError(root),
    };
}

fn appendVariableRef(
    allocator: std.mem.Allocator,
    source: []const u8,
    node: Node,
    range: util.ByteRange,
    list: *std.ArrayList(VariableRef),
) !void {
    const root_node = cst.childByFieldName(node, "root") orelse return;
    const root_text = cst.nodeText(source, root_node);
    const root = if (root_text.len > 0 and root_text[0] == '$') root_text[1..] else root_text;

    const segments = try cst.findChildren(node, "variable_path_segment", allocator);
    defer allocator.free(segments);

    var properties: std.ArrayList([]const u8) = .empty;
    errdefer {
        for (properties.items) |prop| allocator.free(prop);
        properties.deinit(allocator);
    }

    for (segments) |segment| {
        const property_node = cst.childByFieldName(segment, "property") orelse continue;
        try properties.append(allocator, try allocator.dupe(u8, cst.nodeText(source, property_node)));
    }

    var prompt_value: ?[]const u8 = null;
    const selections = try cst.findChildren(node, "prompt_selection", allocator);
    defer allocator.free(selections);
    if (selections.len > 0) {
        const prompt_node = cst.childByFieldName(selections[0], "prompt") orelse null;
        if (prompt_node) |prompt| {
            prompt_value = try allocator.dupe(u8, util.decodeString(cst.nodeText(source, prompt)));
        }
    }

    try list.append(allocator, .{
        .root = try allocator.dupe(u8, root),
        .properties = try properties.toOwnedSlice(allocator),
        .prompt = prompt_value,
        .range = range,
    });
}

fn collectFrontMatterLines(allocator: std.mem.Allocator, source: []const u8, root: Node) ![]const []const u8 {
    const front_nodes = try cst.findChildren(root, "front_matter", allocator);
    defer allocator.free(front_nodes);
    if (front_nodes.len == 0) {
        return &[_][]const u8{};
    }

    const text_nodes = try cst.findChildren(front_nodes[0], "front_matter_text", allocator);
    defer allocator.free(text_nodes);

    var lines: std.ArrayList([]const u8) = .empty;
    errdefer {
        for (lines.items) |line| allocator.free(line);
        lines.deinit(allocator);
    }

    for (text_nodes) |node| {
        const text = std.mem.trim(u8, cst.nodeText(source, node), " \t\r\n");
        if (text.len == 0) {
            continue;
        }
        try lines.append(allocator, try allocator.dupe(u8, text));
    }

    return try lines.toOwnedSlice(allocator);
}

fn byteRange(node: Node) util.ByteRange {
    return .{
        .start = node.startByte(),
        .end = node.endByte(),
    };
}
