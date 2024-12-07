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

        list: std.ArrayList([]const T),
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .allocator = allocator,
                .list = std.ArrayList([]const T).init(allocator),
            };
        }

        pub fn deinit(self: Self) void {
            for (self.list.items) |line| {
                self.allocator.free(line);
            }
            self.list.deinit();
        }

        pub fn append(self: *Self, line: []const T) !void {
            const clone = try self.allocator.alloc(u8, line.len);
            std.mem.copyForwards(u8, clone, line);
            try self.list.append(clone);
        }

        pub fn numRows(self: Self) usize {
            return self.list.items.len;
        }

        pub fn getRow(self: Self, i: usize) []const T {
            return self.list.items[i];
        }

        pub fn getCell(self: Self, row_idx: usize, col_idx: usize) T {
            return self.list.items[row_idx][col_idx];
        }
    };
}

pub fn ReadByLineIterator(comptime buffer_size: usize) type {
    return struct {
        const Self = @This();
        const BufReader = std.io.BufferedReader(buffer_size, std.fs.File.Reader);

        file: std.fs.File,
        reader: std.fs.File.Reader,
        buf_reader: std.io.BufferedReader(buffer_size, std.fs.File.Reader),
        stream: ?BufReader.Reader,
        buf: [buffer_size]u8,

        pub fn next(self: *Self) !?[]u8 {
            if (self.stream == null)  {
                self.stream = self.buf_reader.reader();
            }

            return self.stream.?.readUntilDelimiterOrEof(&self.buf, '\n');
        }

        pub fn deinit(self: *Self) void {
            self.file.close();
        }
    };
}

pub fn iterLines(comptime buffer_size: usize, filename: []const u8) !ReadByLineIterator(buffer_size) {
    const file = try std.fs.cwd().openFile(filename, .{ .mode = .read_only });
    const reader = file.reader();
    const buf_reader = std.io.bufferedReaderSize(buffer_size, reader);

    return ReadByLineIterator(buffer_size) {
        .file = file,
        .reader = reader,
        .buf_reader = buf_reader,
        .stream = null,
        .buf = undefined,
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
        defer allocator.free(line);
        try matrix.append(line);
    }

    return matrix;
}
