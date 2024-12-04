const std = @import("std");

const input_fname = "inputs/day2.txt";

pub fn day2(allocator: std.mem.Allocator) !void {
    const input_file = try std.fs.cwd().openFile(
        input_fname,
        .{ .mode = .read_only },
    );
    defer input_file.close();

    var buf_reader = std.io.bufferedReader(input_file.reader());
    var in_stream = buf_reader.reader();

    var num_safe_reports: u32 = 0;
    var num_safe_dampened_reports: u32 = 0;

    var report = std.ArrayList(u8).init(allocator);
    defer report.deinit();

    while (true) {
        const line = in_stream.readUntilDelimiterAlloc(allocator, '\n', 1024) catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };
        defer allocator.free(line);

        // Split the line by spaces
        var parts = std.mem.splitSequence(u8, line, " ");

        // TODO: Try putting alloc outside loop to see whether Zig will automatically
        // optimise it out or not.
        while (parts.next()) |level_str| {
            try report.append(try std.fmt.parseInt(u8, level_str, 10));
        }

        std.debug.assert(report.items.len > 0);

        num_safe_reports += isReportSafe(report.items, false);
        num_safe_dampened_reports += isReportSafe(report.items, true);

        report.clearRetainingCapacity();
    }

    std.debug.print("Number of safe reports: {}\n", .{num_safe_reports});
    std.debug.print("Number of safe reports (problem dampener enabled): {}\n", .{num_safe_dampened_reports});
}

fn isReportSafe(report: []const u8, enable_problem_dampener: bool) u32 {
    return isReportSafeInternal(report, enable_problem_dampener, null);
}

fn isReportSafeInternal(report: []const u8, enable_problem_dampener: bool, skip_idx: ?usize) u32 {
    var prev: ?u8 = null;
    var is_increasing: ?bool = null;

    for (report, 0..) |level, i| {
        if (skip_idx != null and i == skip_idx.?) {
            continue;
        }

        if (prev == null) {
            prev = level;
            continue;
        }

        const prev_val = prev.?;
        const is_bigger = level > prev_val;
        const diff = if (is_bigger) level - prev_val else prev_val - level;

        // Levels must be monotonically increasing or decreasing.
        if (is_increasing == null) {
            is_increasing = is_bigger;
        }

        if (is_increasing != is_bigger or diff < 1 or diff > 3) {
            if (!enable_problem_dampener) {
                return 0;
            }

            // It's possible that removing i-2 from list will change from increasing to
            // decreasing or vice-versa.
            const start = if (i < 2) 0 else i - 2;
            for (start..i + 1) |j| {
                if (j < 0 or j >= report.len) {
                    continue;
                }

                if (isReportSafeInternal(report, false, j) == 1) {
                    return 1;
                }
            }

            return 0;
        }

        prev = level;
    }

    return 1;
}

test "is_report_safe when safe" {
    const report = [_]u8{ 1, 2, 3, 4, 5 };
    const result = isReportSafe(&report, false);
    try std.testing.expectEqual(1, result);
}

test "is_report_safe when not monotonic increasing" {
    const report = [_]u8{ 1, 2, 4, 3, 5 };
    const result = isReportSafe(&report, false);
    try std.testing.expectEqual(0, result);
}

test "is_report_safe when not monotonic decreasing" {
    const report = [_]u8{ 5, 4, 3, 4, 1 };
    const result = isReportSafe(&report, false);
    try std.testing.expectEqual(0, result);
}

test "is_report_safe with single bad level" {
    const report = [_]u8{ 1, 9, 3, 4, 5 };
    const result = isReportSafe(&report, true);
    try std.testing.expectEqual(1, result);
}

test "is_report_safe with two bad levels" {
    const report = [_]u8{ 1, 9, 3, 4, 2 };
    const result = isReportSafe(&report, true);
    try std.testing.expectEqual(0, result);
}

test "is_report_safe with bad level at first index" {
    const report = [_]u8{ 9, 1, 3, 4, 5 };
    const result = isReportSafe(&report, true);
    try std.testing.expectEqual(1, result);
}

test "is_report_safe with bad level at last index" {
    const report = [_]u8{ 1, 2, 3, 4, 1 };
    const result = isReportSafe(&report, true);
    try std.testing.expectEqual(1, result);
}

test "is_report_safe with examples" {
    const reports = [_]std.ArrayList(u8){
        try sliceToArrayList(&[_]u8{ 7, 6, 4, 2, 1 }),
        try sliceToArrayList(&[_]u8{ 1, 2, 7, 8, 9 }),
        try sliceToArrayList(&[_]u8{ 9, 7, 6, 2, 1 }),
        try sliceToArrayList(&[_]u8{ 1, 3, 2, 4, 5 }),
        try sliceToArrayList(&[_]u8{ 8, 6, 4, 4, 1 }),
        try sliceToArrayList(&[_]u8{ 1, 3, 6, 7, 9 }),
    };
    const safeties = [_]u32{ 1, 0, 0, 1, 1, 1 };

    for (reports, safeties) |report, expected| {
        const result = isReportSafe(report.items, true);
        try std.testing.expectEqual(expected, result);
    }
}

test "is_report_safe with i-2 problem dampener" {
    const reports = [_]std.ArrayList(u8){
        try sliceToArrayList(&[_]u8{ 11, 12, 15, 18, 19, 18 }),
        try sliceToArrayList(&[_]u8{ 68, 66, 67, 69, 72, 73, 76 }),
        try sliceToArrayList(&[_]u8{ 92, 93, 92, 89, 86 }),
    };

    const safeties = [_]u32{ 1, 1, 1 };

    for (reports, safeties) |report, expected| {
        const result = isReportSafe(report.items, true);
        try std.testing.expectEqual(expected, result);
    }
}

fn sliceToArrayList(slice: []const u8) !std.ArrayList(u8) {
    var list = std.ArrayList(u8).init(std.heap.page_allocator);
    try list.appendSlice(slice);
    return list;
}
