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

pub fn MatrixList(comptime T: type) type {
    return struct {
        const Self = @This();

        list: std.ArrayList([]T),
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .allocator = allocator,
                .list = std.ArrayList([]T).init(allocator),
            };
        }

        pub fn deinit(self: Self) void {
            for (self.list.items) |line| {
                self.allocator.free(line);
            }
            self.list.deinit();
        }

        pub fn append(self: *Self, line: []T) !void {
            try self.list.append(line);
        }

        pub fn numRows(self: Self) usize {
            return self.list.items.len;
        }

        pub fn getRow(self: Self, i: usize) []T {
            return self.list.items[i];
        }

        pub fn getCell(self: Self, row_idx: usize, col_idx: usize) T {
            return self.list.items[row_idx][col_idx];
        }
    };
}

pub fn readFileLines(input_fname: []const u8, allocator: std.mem.Allocator) !MatrixList(u8) {
    const input_file = try std.fs.cwd().openFile(
        input_fname,
        .{ .mode = .read_only },
    );
    defer input_file.close();

    var buf_reader = std.io.bufferedReader(input_file.reader());
    var in_stream = buf_reader.reader();

    var matrix = MatrixList(u8).init(allocator);

    while (true) {
        const line = in_stream.readUntilDelimiterAlloc(allocator, '\n', 1024) catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };
        try matrix.append(line);
    }

    return matrix;
}
