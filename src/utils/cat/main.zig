const std = @import("std");

pub fn main() u8 {
    const allocator = std.heap.page_allocator;
    var args = std.process.argsWithAllocator(allocator) catch return 1;
    defer args.deinit();
    if (!args.skip()) {
        return 0;
    }
    const filename = args.next() orelse {
        std.debug.print("Usage: cat <filename>\n", .{});
        return 1;
    };
    if (args.next() != null) {
        std.debug.print("Usage: cat <filename>\n", .{});
        return 1;
    }
    const file_stat = std.fs.cwd().statFile(filename) catch |err| {
        std.debug.print("Unable to stat file {s}: {s}\n", .{ filename, @errorName(err) });
        return 1;
    };
    if (file_stat.kind != .file) {
        std.debug.print("cat: {s}: Is not a file\n", .{filename});
        return 1;
    }
    const file = std.fs.cwd().openFile(filename, .{ .mode = .read_only }) catch {
        std.debug.print("cat: {s}: Unable to open file\n", .{filename});
        return 1;
    };
    const buffer = allocator.alloc(u8, 4096) catch {
        std.debug.print("cat: Out of memory\n", .{});
        return 1;
    };
    defer allocator.free(buffer);
    while (true) {
        const read_result = file.read(buffer) catch |err| {
            std.debug.print("cat: Read error: {s}\n", .{@errorName(err)});
            return 1;
        };
        if (read_result == 0) {
            break;
        }
        const write_result = std.io.getStdOut().write(buffer[0..read_result]) catch |err| {
            std.debug.print("cat: Write error: {s}\n", .{@errorName(err)});
            return 1;
        };
        if (write_result != read_result) {
            std.debug.print("cat: Write error\n", .{});
            return 1;
        }
    }
    return 0;
}
