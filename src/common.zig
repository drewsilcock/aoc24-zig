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

/// Provides iterator over lines.
///
/// Somewhat janky implementation of interfaces following guide from
/// https://www.openmymind.net/Zig-Interfaces/, but it seems to work. I'm sure someone
/// with more experience would do a much more elegant job.
pub fn ReadByLineIterator(comptime buffer_size: usize) type {
    return struct {
        const Self = @This();

        ptr: *anyopaque,
        buf: [buffer_size]u8,
        nextFn: *const fn (ptr: *anyopaque, *[buffer_size]u8) anyerror!?[]u8,
        closeFn: *const fn (ptr: *anyopaque) void,

        pub fn init(ptr: anytype) Self {
            const T = @TypeOf(ptr);
            const child = @typeInfo(T).Pointer.child;

            const gen = struct {
                pub fn nextFn(fn_ptr: *anyopaque, buffer: *[buffer_size]u8) anyerror!?[]u8 {
                    const self: T = @alignCast(@ptrCast(fn_ptr));
                    return child.nextFn(self, buffer);
                }

                pub fn closeFn(fn_ptr: *anyopaque) void {
                    const self: T = @alignCast(@ptrCast(fn_ptr));
                    child.closeFn(self);
                }
            };

            return .{
                .ptr = ptr,
                .buf = undefined,
                .nextFn = gen.nextFn,
                .closeFn = gen.closeFn,
            };
        }

        pub fn next(self: *Self) !?[]u8 {
            return self.nextFn(self.ptr, &self.buf);
        }

        pub fn close(self: *Self) void {
            self.closeFn(self.ptr);
        }
    };
}

fn FileReadByLineIterator(comptime buffer_size: usize) type {
    return struct {
        const Self = @This();
        const BufReader = std.io.BufferedReader(buffer_size, std.fs.File.Reader);

        file: std.fs.File,
        reader: std.fs.File.Reader,
        buf_reader: BufReader,
        stream: ?BufReader.Reader,

        pub fn init(file: std.fs.File) Self {
            const reader = file.reader();
            const buf_reader = std.io.bufferedReaderSize(buffer_size, reader);

            return Self{
                .file = file,
                .reader = reader,
                .buf_reader = buf_reader,
                .stream = null,
            };
        }

        pub fn nextFn(self: *Self, buffer: *[buffer_size]u8) !?[]u8 {
            if (self.stream == null) {
                self.stream = self.buf_reader.reader();
            }

            return self.stream.?.readUntilDelimiterOrEof(buffer, '\n');
        }

        pub fn closeFn(self: *Self) void {
            self.file.close();
        }

        pub fn iter(self: *Self) ReadByLineIterator(buffer_size) {
            return ReadByLineIterator(buffer_size).init(self);
        }
    };
}

fn MemoryReadByLineIterator(comptime buffer_size: usize) type {
    return struct {
        const Self = @This();
        const FixedBufferStreamType = std.io.FixedBufferStream([]const u8);

        input_buffer: []const u8,
        fixed_buffer: FixedBufferStreamType,
        stream: ?FixedBufferStreamType.Reader,

        pub fn init(input: []const u8) !Self {
            return Self{
                .input_buffer = input,
                .fixed_buffer = std.io.fixedBufferStream(input),
                .stream = null,
            };

            //self.input_buffer = try allocator.alloc(u8, input.len);
            //@memcpy(self.input_buffer, input);
            //self.fixed_buffer = std.io.fixedBufferStream(self.input_buffer);

            //return self;
        }

        pub fn nextFn(self: *Self, buffer: *[buffer_size]u8) !?[]u8 {
            if (self.stream == null) {
                self.stream = self.fixed_buffer.reader();
            }

            return self.stream.?.readUntilDelimiterOrEof(buffer, '\n');
        }

        pub fn closeFn(self: *Self) void {
            _ = self; // autofix
            //self.allocator.free(self.input_buffer);
        }

        pub fn iter(self: *Self) ReadByLineIterator(buffer_size) {
            return ReadByLineIterator(buffer_size).init(self);
        }
    };
}

pub fn fileIterLines(comptime buffer_size: usize, filename: []const u8) !FileReadByLineIterator(buffer_size) {
    const file = try std.fs.cwd().openFile(filename, .{ .mode = .read_only });

    //var file_iter = NewFileReadByLineIterator(buffer_size).init(file);

    //const reader = file.reader();
    //const buf_reader = std.io.bufferedReaderSize(buffer_size, reader);

    //var file_iter = FileReadByLineIterator(buffer_size){
    //    .file = file,
    //    .reader = reader,
    //    .buf_reader = buf_reader,
    //    .stream = null,
    //};

    return FileReadByLineIterator(buffer_size).init(file);
}

pub fn memoryIterLines(comptime buffer_size: usize, input: []const u8) !MemoryReadByLineIterator(buffer_size) {
    return MemoryReadByLineIterator(buffer_size).init(input);
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
