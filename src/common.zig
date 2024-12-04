const std = @import("std");

pub fn readFile(input_fname: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const input_file = try std.fs.cwd().openFile(
        input_fname,
        .{ .mode = .read_only },
    );
    defer input_file.close();

    const file_size = try input_file.getEndPos();
    const buffer = try allocator.alloc(u8, file_size);

    _ = try input_file.readAll(buffer);

    return buffer;
}
