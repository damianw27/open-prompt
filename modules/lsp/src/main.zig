const std = @import("std");
const lsp = openprompt_lsp.lsp;
const openprompt_lsp = @import("openprompt_lsp");

pub fn main(init: std.process.Init) !void {
    var read_buffer: [4096]u8 = undefined;
    var stdio_transport: lsp.Transport.Stdio = .init(&read_buffer, .stdin(), .stdout());
    const transport: *lsp.Transport = &stdio_transport.transport;

    var server = try openprompt_lsp.server.Server.init(init.gpa, init.io);
    defer server.deinit();

    try lsp.basic_server.run(
        init.io,
        init.gpa,
        transport,
        &server,
        std.log.err,
    );
}
