const std = @import("std");
const common = @import("common.zig");
const Set = @import("set.zig").Set;

const input_fname = "inputs/day7.txt";

const Solution = struct {
    calibration_result: u64,
    concat_calibration_result: u64,
};

const CalibrationEquation = struct {
    const Self = @This();
    const ArrayList = std.ArrayList(u64);

    total: u64,
    values: ArrayList,
    remaining_values: ArrayList,
    running_totals: ArrayList,
    running_totals_temp: ArrayList,
    concat_buffer: [64]u8,

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .total = 0,
            .values = ArrayList.init(allocator),
            .remaining_values = ArrayList.init(allocator),
            .running_totals = ArrayList.init(allocator),
            .running_totals_temp = ArrayList.init(allocator),
            .concat_buffer = undefined,
        };
    }

    pub fn clearRetainingCapacity(self: *Self) void {
        self.total = 0;
        self.values.clearRetainingCapacity();
        self.remaining_values.clearRetainingCapacity();
        self.running_totals.clearRetainingCapacity();
        self.running_totals_temp.clearRetainingCapacity();
    }

    pub fn deinit(self: Self) void {
        self.values.deinit();
        self.remaining_values.deinit();
        self.running_totals.deinit();
        self.running_totals_temp.deinit();
    }

    pub fn read(self: *Self, line: []const u8) !void {
        var answer_values_iter = std.mem.tokenizeAny(u8, line, ": ");

        if (answer_values_iter.next()) |total_str| {
            self.total = try std.fmt.parseInt(u64, total_str, 10);
        } else {
            return error.InvalidInput;
        }

        while (answer_values_iter.next()) |value_str| {
            const value = try std.fmt.parseInt(u64, value_str, 10);
            try self.values.append(value);
        }

        std.debug.assert(self.values.items.len > 0);
    }

    pub fn has_solution(self: *Self, enable_concat: bool) !bool {
        if (self.values.items.len == 0) {
            return false;
        }

        if (self.values.items.len == 1) {
            return self.values.items[0] == self.total;
        }

        self.running_totals.clearRetainingCapacity();
        self.remaining_values.clearRetainingCapacity();

        //  Go through each pair of items in `values` and try each combination of
        //  operators to see if the total is exactly reached.

        // Each possible operator applied between two numbers will produce N valid
        // running totals – you don't "use up" operators. Currently N = 2 (addition,
        // multiplication). When you combine a running total with the next remaining
        // value, you remove the original running total and add two new ones.

        try self.remaining_values.appendSlice(self.values.items[1..]);
        try self.running_totals.append(self.values.items[0]);

        for (self.remaining_values.items) |value| {
            self.running_totals_temp.clearRetainingCapacity();

            for (self.running_totals.items) |running_total| {
                // We only have operators that increase values or stay the same, so
                // ignore running totals already > total.
                if (running_total > self.total) {
                    continue;
                }

                try self.running_totals_temp.append(running_total + value);
                try self.running_totals_temp.append(running_total * value);

                if (enable_concat) {
                    const concat_str = try std.fmt.bufPrint(&self.concat_buffer, "{}{}", .{ running_total, value });
                    const concatenated = try std.fmt.parseInt(u64, concat_str, 10);
                    try self.running_totals_temp.append(concatenated);
                }
            }

            std.mem.swap(ArrayList, &self.running_totals, &self.running_totals_temp);
        }

        for (self.running_totals.items) |running_total| {
            if (running_total == self.total) {
                return true;
            }
        }

        return false;
    }
};

pub fn run(allocator: std.mem.Allocator) !void {
    const solution = try solve(allocator);

    std.debug.print("Calibration result: {}\n", .{solution.calibration_result});
    std.debug.print("Concatenated calibration result: {}\n", .{solution.concat_calibration_result});
}

pub fn solve(allocator: std.mem.Allocator) !Solution {
    const input = try common.readFile(input_fname, allocator);
    defer allocator.free(input);

    var iter_lines = std.mem.tokenizeScalar(u8, input, '\n');

    var equation = CalibrationEquation.init(allocator);
    defer equation.deinit();

    var calibration_result: u64 = 0;
    var concat_calibration_result: u64 = 0;

    while (iter_lines.next()) |line| {
        try equation.read(line);

        if (try equation.has_solution(false)) {
            calibration_result += equation.total;
        }

        if (try equation.has_solution(true)) {
            concat_calibration_result += equation.total;
        }

        equation.clearRetainingCapacity();
    }

    return .{
        .calibration_result = calibration_result,
        .concat_calibration_result = concat_calibration_result,
    };
}

test "solve known simple test case" {
    const input =
        \\190: 10 19
        \\3267: 81 40 27
        \\83: 17 5
        \\156: 15 6
        \\7290: 6 8 6 15
        \\161011: 16 10 13
        \\192: 17 8 14
        \\21037: 9 7 18 13
        \\292: 11 6 16 20
    ;

    const expected_has_solutions = [_]bool{
        true,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        true,
    };

    const expected_has_solutions_concat = [_]bool{
        true,
        true,
        false,
        true,
        true,
        false,
        true,
        false,
        true,
    };

    var actual_has_solutions = [_]bool{false} ** expected_has_solutions.len;
    var actual_has_solutions_concat = [_]bool{false} ** expected_has_solutions_concat.len;

    var equation = CalibrationEquation.init(std.testing.allocator);
    defer equation.deinit();

    var lines = std.mem.tokenizeScalar(u8, input, '\n');

    var i: u32 = 0;
    while (lines.next()) |line| : (i += 1) {
        equation.clearRetainingCapacity();
        try equation.read(line);
        actual_has_solutions[i] = try equation.has_solution(false);
        actual_has_solutions_concat[i] = try equation.has_solution(true);
    }

    try std.testing.expectEqualSlices(bool, &expected_has_solutions, &actual_has_solutions);
    try std.testing.expectEqualSlices(bool, &expected_has_solutions_concat, &actual_has_solutions_concat);
}

test "CalibrationEquation.read" {
    const lines = [_][]const u8{
        "190: 10 19",
        "3267: 81 40 27",
        "83: 17 5",
        "156: 15 6",
        "7290: 6 8 6 15",
        "161011: 16 10 13",
        "192: 17 8 14",
        "21037: 9 7 18 13",
        "292: 11 6 16 20",
    };

    const expected_totals = [_]u64{ 190, 3267, 83, 156, 7290, 161011, 192, 21037, 292 };
    const expected_values = [_][]const u64{
        &[_]u64{ 10, 19 },
        &[_]u64{ 81, 40, 27 },
        &[_]u64{ 17, 5 },
        &[_]u64{ 15, 6 },
        &[_]u64{ 6, 8, 6, 15 },
        &[_]u64{ 16, 10, 13 },
        &[_]u64{ 17, 8, 14 },
        &[_]u64{ 9, 7, 18, 13 },
        &[_]u64{ 11, 6, 16, 20 },
    };

    var equation = CalibrationEquation.init(std.testing.allocator);
    defer equation.deinit();

    for (lines, 0..) |line, i| {
        equation.clearRetainingCapacity();
        try equation.read(line);

        try std.testing.expectEqual(expected_totals[i], equation.total);
        try std.testing.expectEqualSlices(u64, expected_values[i], equation.values.items);
    }
}
