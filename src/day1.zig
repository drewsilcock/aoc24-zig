const std = @import("std");

pub fn day1(allocator: std.mem.Allocator) !void {
    const input_fname = "inputs/day1.txt";
    const input_file = try std.fs.cwd().openFile(
        input_fname,
        .{ .mode = .read_only },
    );
    defer input_file.close();

    var buf_reader = std.io.bufferedReader(input_file.reader());
    var in_stream = buf_reader.reader();

    var total_distance: u32 = 0;

    var left_list = std.ArrayList(u32).init(allocator);
    defer left_list.deinit();
    var right_list = std.ArrayList(u32).init(allocator);
    defer right_list.deinit();

    while (true) {
        const line = in_stream.readUntilDelimiterAlloc(allocator, '\n', 1024) catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };
        defer allocator.free(line);

        // Split the line by spaces
        var parts = std.mem.splitSequence(u8, line, "   ");

        const left_num_str = parts.next() orelse return error.ParseError;
        const right_num_str = parts.next() orelse return error.ParseError;

        if (parts.next() != null) {
            return error.ParseError;
        }

        const left_num = try std.fmt.parseInt(u32, left_num_str, 10);
        const right_num = try std.fmt.parseInt(u32, right_num_str, 10);

        try left_list.append(left_num);
        try right_list.append(right_num);
    }

    if (left_list.items.len != right_list.items.len) {
        return error.InvalidArguments;
    }

    std.mem.sort(u32, left_list.items, {}, comptime std.sort.asc(u32));
    std.mem.sort(u32, right_list.items, {}, comptime std.sort.asc(u32));

    for (left_list.items, right_list.items) |left, right| {
        total_distance += if (left > right) left - right else right - left;
    }

    try std.io.getStdOut().writer().print("{}\n", .{total_distance});
}
