const std = @import("std");

pub fn main() u8 {
    const allocator = std.heap.page_allocator;
    var args = std.process.argsWithAllocator(allocator) catch return 1;
    if (!args.skip()) {
        // skip program's name
        return 0;
    }
    while (args.next()) |arg| {
        std.debug.print("{s} ", .{arg});
    }
    std.debug.print("\n", .{});
    return 0;
}
