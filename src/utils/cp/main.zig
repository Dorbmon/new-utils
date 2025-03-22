const std = @import("std");
const args = @import("args");
const allocator = std.heap.page_allocator;
const args_struct = struct {
    recursive: bool = false,
    pub const shorthands = .{
        .R = "recursive",
    };
    pub const meta = .{};
};
fn copy_director(source: []const u8, target: []const u8) u8 {
    const source_folder = std.fs.cwd().openDir(source, .{}) catch |err| {
        std.debug.print("Unable to open directory {s}: {s}\n", .{ source, @errorName(err) });
        return 1;
    };
    var walker = source_folder.walk(allocator) catch {
        std.debug.print("Out of memory\n", .{});
        return 1;
    };
    defer walker.deinit();
    while (walker.next() catch |err| {
        std.debug.print("Error walking directory: {s}\n", .{@errorName(err)});
        return 1;
    }) |entry| {
        const source_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ source, entry.basename }) catch {
            std.debug.print("Out of memory\n", .{});
            return 1;
        };
        const target_path = std.fmt.allocPrint(allocator, "{s}/{s}", .{ target, entry.basename }) catch {
            std.debug.print("Out of memory\n", .{});
            return 1;
        };
        const source_stat = std.fs.cwd().statFile(source_path) catch |err| {
            std.debug.print("Unable to stat file {s}: {s}\n", .{ source_path, @errorName(err) });
            return 1;
        };
        var code: u8 = 0;
        switch (source_stat.kind) {
            .directory => {
                std.fs.cwd().makePath(target_path) catch {
                    std.debug.print("Unable to create directory {s}\n", .{target_path});
                    code = 1;
                    break;
                };
                code = copy_director(source_path, target_path);
                break;
            },
            .file => {
                const source_file = std.fs.cwd().openFile(source_path, .{ .mode = .read_only }) catch |err| {
                    std.debug.print("Unable to open file {s}: {s}\n", .{ source_path, @errorName(err) });
                    code = 1;
                    break;
                };
                const target_file = std.fs.cwd().openFile(target_path, .{ .mode = .read_write }) catch |err| {
                    std.debug.print("Unable to open file {s}: {s}\n", .{ target_path, @errorName(err) });
                    code = 1;
                    break;
                };
                const buffer = allocator.alloc(u8, 4096) catch {
                    std.debug.print("Out of memory\n", .{});
                    code = 1;
                    break;
                };
                defer allocator.free(buffer);
                while (true) {
                    const read_len = source_file.read(buffer) catch |err| {
                        std.debug.print("Error reading file {s}: {s}\n", .{ source_path, @errorName(err) });
                        code = 1;
                        break;
                    };
                    if (read_len == 0) {
                        break;
                    }
                    const write_len = target_file.write(buffer[0..read_len]) catch |err| {
                        std.debug.print("Error writing to file {s}: {s}\n", .{ target_path, @errorName(err) });
                        code = 1;
                        break;
                    };
                    if (write_len != read_len) {
                        std.debug.print("Unable to write to file {s}\n", .{target_path});
                        code = 1;
                        break;
                    }
                }
                code = 0;
                break;
            },
            else => std.debug.panic("Unsupported file type: {s}", .{@tagName(source_stat.kind)}),
        }
        if (code != 0) {
            return code;
        }
    }
    return 0;
}
fn copy_file(source: []const u8, target: []const u8) u8 {
    const source_file = std.fs.cwd().openFile(source, .{ .mode = .read_only }) catch |err| {
        std.debug.print("Unable to open file {s}: {s}\n", .{ source, @errorName(err) });
        return 1;
    };

    if (target[target.len - 1] == '/') {
        // get filename from the source path
        const last_slash_position = std.mem.lastIndexOf(u8, source, "/") orelse unreachable;
        const filename = std.fmt.allocPrint(allocator, "{s}", .{source[last_slash_position + 1 ..]}) catch {
            std.debug.print("Out of memory\n", .{});
            return 1;
        };
        return copy_file(source, filename);
    }
    const target_file = std.fs.cwd().openFile(target, .{ .mode = .read_write }) catch |err| {
        std.debug.print("Unable to open file {s}: {s}\n", .{ target, @errorName(err) });
        return 1;
    };
    const buffer = allocator.alloc(u8, 4096) catch {
        std.debug.print("Out of memory\n", .{});
        return 1;
    };
    defer allocator.free(buffer);
    while (true) {
        const read_len = source_file.read(buffer) catch |err| {
            std.debug.print("Error reading file {s}: {s}\n", .{ source, @errorName(err) });
            return 1;
        };
        if (read_len == 0) {
            break;
        }
        const write_len = target_file.write(buffer[0..read_len]) catch |err| {
            std.debug.print("Error writing to file {s}: {s}\n", .{ target, @errorName(err) });
            return 1;
        };
        if (write_len != read_len) {
            std.debug.print("Unable to write to file {s}\n", .{target});
            return 1;
        }
    }
    return 0;
}
pub fn main() u8 {
    const options = args.parseForCurrentProcess(args_struct, allocator, .print) catch return 1;
    if (options.positionals.len < 2) {
        args.printHelp(args_struct, options.executable_name.?, std.io.getStdErr().writer()) catch return 1;
        std.debug.print("Usage: cp <source> <destination>\n", .{});
        return 1;
    }
    const sources = options.positionals[0 .. options.positionals.len - 2];
    const target = options.positionals[options.positionals.len - 1];
    // do cp for each source
    for (sources) |source| {
        const source_file_stat = std.fs.cwd().statFile(source) catch |err| {
            std.debug.print("Unable to stat file: {s}\n", .{@errorName(err)});
            return 1;
        };
        const code = switch (source_file_stat.kind) {
            .directory => copy_director(source, target),
            .file => copy_file(source, target),
            else => std.debug.panic("Unsupported file type: {s}", .{@tagName(source_file_stat.kind)}),
        };
        if (code != 0) {
            return code;
        }
    }
    std.debug.print("{s}\n", .{options.positionals});
    return 0;
}
