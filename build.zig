const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const allocator = std.heap.page_allocator;
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});
    var utils_dir = std.fs.cwd().openDir("src/utils", .{ .iterate = true }) catch |err| {
        std.debug.print("Unable to open directory: {s}\n", .{@errorName(err)});
        return;
    };
    defer utils_dir.close();
    var dir_iter = utils_dir.iterate();

    var walker = utils_dir.walk(allocator) catch {
        std.debug.print("Out of memory\n", .{});
        return;
    };
    defer walker.deinit();
    while (dir_iter.next() catch {
        return;
    }) |entry| {
        if (entry.kind != .directory) {
            continue;
        }
        std.debug.print("Found file: {s}\n", .{entry.name});
        const root_path = std.fmt.allocPrint(allocator, "src/utils/{s}/main.zig", .{entry.name}) catch {
            std.debug.print("Out of memory\n", .{});
            return;
        };
        std.debug.print("Root path: {s}\n", .{root_path});

        const exe = b.addExecutable(.{ .name = entry.name, .root_source_file = b.path(root_path), .target = target, .optimize = optimize });
        exe.root_module.addImport("args", b.dependency("args", .{ .target = target, .optimize = optimize }).module("args"));

        b.installArtifact(exe);
    }
    return;
}
