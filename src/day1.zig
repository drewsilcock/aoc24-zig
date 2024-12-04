const std = @import("std");
const common = @import("common.zig");

pub fn day1(allocator: std.mem.Allocator) !void {
    // Part 1 – list distance
    const left_list, const right_list = try readLists("inputs/day1.txt", allocator);
    defer allocator.free(left_list);
    defer allocator.free(right_list);

    std.mem.sort(u32, left_list, {}, comptime std.sort.asc(u32));
    std.mem.sort(u32, right_list, {}, comptime std.sort.asc(u32));

    var total_distance: u32 = 0;
    for (left_list, right_list) |left, right| {
        total_distance += if (left > right) left - right else right - left;
    }

    std.debug.print("Total distance: {}\n", .{total_distance});

    // Part 2 – similarity score
    var right_counter_map = std.AutoHashMap(u32, u32).init(allocator);
    defer right_counter_map.deinit();

    for (right_list) |right_value| {
        const result = try right_counter_map.getOrPut(right_value);
        if (result.found_existing) {
            result.value_ptr.* += 1;
        } else {
            result.value_ptr.* = 1;
        }
    }

    var similarity_score: u32 = 0;
    for (left_list) |left_value| {
        const counter = right_counter_map.get(left_value) orelse 0;
        similarity_score += counter * left_value;
    }

    std.debug.print("Similarity score: {}\n", .{similarity_score});
}

fn readLists(input_fname: []const u8, allocator: std.mem.Allocator) !struct { []u32, []u32} {
    const input_file = try std.fs.cwd().openFile(
        input_fname,
        .{ .mode = .read_only },
    );
    defer input_file.close();

    var buf_reader = std.io.bufferedReader(input_file.reader());
    var in_stream = buf_reader.reader();

    var left_list = std.ArrayList(u32).init(allocator);
    var right_list = std.ArrayList(u32).init(allocator);

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

    return .{try left_list.toOwnedSlice(), try right_list.toOwnedSlice()};
}
