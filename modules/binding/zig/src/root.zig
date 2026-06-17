const std = @import("std");

pub const Engine = @import("engine.zig").Engine;
pub const Value = @import("value.zig").Value;

test "render basic vector" {
    const allocator = std.testing.allocator;
    var engine = Engine.initMemory(allocator);
    defer engine.deinit();

    const common =
        \\[[@template example]]
        \\
        \\## Example Section
        \\
        \\[[@end]]
        \\
    ;
    try engine.registerModule("common.op", common);

    const template_source =
        \\---
        \\title: Review
        \\---
        \\[[@use "common.op" as $prompts]]
        \\
        \\Hello {{ $user.name }}
        \\
        \\[[@if $user.age >= 18]]
        \\Adult
        \\[[@else]]
        \\Minor
        \\[[@end]]
        \\
    ;
    const context = "{\"user\":{\"name\":\"Ada\",\"age\":18}}";

    try engine.loadString(template_source, "basic.op");
    try engine.setContextJson(context);
    const rendered = try engine.render();
    defer allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "Hello Ada") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "Adult") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "## Example Section") != null);
}
