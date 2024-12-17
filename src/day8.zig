const std = @import("std");
const common = @import("common.zig");
const Set = @import("set.zig").Set;

const input_fname = "inputs/day8.txt";

const Solution = struct {
    num_antinodes: u32,
    num_resonant_antinodes: u32,
};

const Point = struct {
    row: u32,
    col: u32,

    pub fn toIndex(self: Point, width: u32) u32 {
        return self.row * width + self.col;
    }
};

const AntennaGrid = struct {
    const Self = @This();

    const AntennaMap = std.AutoHashMap(u8, std.ArrayList(Point));

    width: u32,
    height: u32,

    // Store map from antenna frequency (represented as char) to list of indices. This
    // structure makes it easy to compare all pairs of the same antenna frequency to
    // finding antinodes.
    antennas: AntennaMap,

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .width = 0,
            .height = 0,
            .antennas = AntennaMap.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.antennas.valueIterator();
        while (iter.next()) |points| {
            points.deinit();
        }
        self.antennas.deinit();
    }

    pub fn read(self: *Self, input: []const u8) !void {
        var lines = std.mem.tokenizeScalar(u8, input, '\n');

        var row_idx: u32 = 0;

        while (lines.next()) |line| {
            if (self.width == 0) {
                self.width = @intCast(line.len);
            } else if (self.width != line.len) {
                return error.InvalidGridSize;
            }

            for (line, 0..) |cell, col_idx| {
                if (cell == '.') {
                    continue;
                }

                const gop = try self.antennas.getOrPut(cell);
                if (!gop.found_existing) {
                    gop.value_ptr.* = std.ArrayList(Point).init(self.allocator);
                }

                try gop.value_ptr.*.append(Point{ .row = row_idx, .col = @intCast(col_idx) });
            }

            row_idx += 1;
        }

        self.height = row_idx;
    }

    pub fn numAntinodes(self: Self, enable_resonant_harmonics: bool) !u32 {
        const antinodes_slice = try self.antinodes(enable_resonant_harmonics);
        defer self.allocator.free(antinodes_slice);
        return @intCast(antinodes_slice.len);
    }

    pub fn antinodes(self: Self, enable_resonant_harmonics: bool) ![]Point {
        // Easier to use u32 index type for set operations rather than custom Point type.
        var antinode_set = Set(u32).init(self.allocator);
        defer antinode_set.deinit();

        var iter = self.antennas.valueIterator();

        while (iter.next()) |points| {
            // For each antenna, loop through all other antennas of same frequency to
            // try to find the antinode going from one antenna to the other. Each pair
            // produces 2 antinodes but we don't count them if they're off the side of
            // the grid. This is O(n^2) but n is small.
            for (points.items, 0..) |anchor, i| {
                for (points.items, 0..) |target, j| {
                    if (i == j) {
                        continue;
                    }

                    const anchor_row: i32 = @intCast(anchor.row);
                    const anchor_col: i32 = @intCast(anchor.col);

                    var target_row: i32 = @intCast(target.row);
                    var target_col: i32 = @intCast(target.col);

                    var slope_row = target_row - anchor_row;
                    var slope_col = target_col - anchor_col;

                    // If harmonics are disabled, we just take one point by project from
                    // the anchor across the other side of the target.
                    if (!enable_resonant_harmonics) {
                        const antinode_row = target_row + target_row - anchor_row;
                        const antinode_col = target_col + target_col - anchor_col;

                        if (antinode_row < 0 or antinode_row >= self.height or
                            antinode_col < 0 or antinode_col >= self.width)
                        {
                            continue;
                        }

                        const point = Point{ .row = @intCast(antinode_row), .col = @intCast(antinode_col) };
                        _ = try antinode_set.add(point.toIndex(self.width));
                        continue;
                    }

                    // Resonant harmonics are enabled, so we need to find all antinodes
                    // in a straight line between and beyond the anchor and target. We
                    // will technically calculate the antinodes between the points twice
                    // but we're using a set so the duplicates will be ignored.

                    const gcd = greatestCommonDivisor(slope_row, slope_col);
                    slope_row = @divExact(slope_row, gcd);
                    slope_col = @divExact(slope_col, gcd);

                    var antinode_row = anchor_row + slope_row;
                    var antinode_col = anchor_col + slope_col;

                    while (true) {
                        if (antinode_row < 0 or antinode_row >= self.height or
                            antinode_col < 0 or antinode_col >= self.width)
                        {
                            break;
                        }

                        const antinode = Point{
                            .row = @intCast(antinode_row),
                            .col = @intCast(antinode_col),
                        };

                        _ = try antinode_set.add(antinode.toIndex(self.width));

                        target_row = antinode_row;
                        target_col = antinode_col;

                        antinode_row = target_row + slope_row;
                        antinode_col = target_col + slope_col;
                    }
                }
            }
        }

        var points = try std.ArrayList(Point).initCapacity(self.allocator, antinode_set.count());
        var set_iter = antinode_set.iterator();
        while (set_iter.next()) |antinode_idx| {
            const row = @divTrunc(antinode_idx.*, self.width);
            const col = @mod(antinode_idx.*, self.width);
            try points.append(Point{ .row = row, .col = col });
        }

        return points.toOwnedSlice();
    }

    pub fn printAntinodes(self: Self, enable_resonant_harmonics: bool) !void {
        const antinodes_slice = try self.antinodes(enable_resonant_harmonics);
        defer self.allocator.free(antinodes_slice);

        std.debug.print("Antinodes (resonant harmonics = {}):\n", .{enable_resonant_harmonics});

        var grid = try std.ArrayList(u8).initCapacity(self.allocator, self.width * self.height);
        defer grid.deinit();

        for (0..self.width * self.height) |_| {
            try grid.append('.');
        }

        for (antinodes_slice) |antinode| {
            grid.items[antinode.toIndex(self.width)] = '#';
        }

        for (0..self.width) |row_idx| {
            for (0..self.height) |col_idx| {
                const point = Point{ .row = @intCast(row_idx), .col = @intCast(col_idx) };
                const cell = grid.items[point.toIndex(self.width)];
                std.debug.print("{c}", .{cell});
            }

            std.debug.print("\n", .{});
        }

        std.debug.print("\n", .{});
    }

    pub fn print(self: Self) !void {
        var grid = try std.ArrayList(u8).initCapacity(self.allocator, self.width * self.height);
        defer grid.deinit();

        for (0..self.width * self.height) |_| {
            try grid.append('.');
        }

        var iter = self.antennas.iterator();
        while (iter.next()) |entry| {
            for (entry.value_ptr.items) |point| {
                grid.items[point.toIndex(self.width)] = entry.key_ptr.*;
            }
        }

        std.debug.print("Grid:\n");

        for (0..self.height) |row_idx| {
            for (0..self.width) |col_idx| {
                const point = Point{ .row = @intCast(row_idx), .col = @intCast(col_idx) };
                const cell = grid.items[point.toIndex(self.width)];
                std.debug.print("{c}", .{cell});
            }

            std.debug.print("\n", .{});
        }

        std.debug.print("\n", .{});
    }
};

fn greatestCommonDivisor(a: i32, b: i32) i32 {
    var temp: u32 = 0;
    var x = @abs(a);
    var y = @abs(b);

    while (y != 0) {
        temp = @mod(x, y);
        x = y;
        y = temp;
    }

    return @intCast(x);
}

pub fn run(allocator: std.mem.Allocator) !void {
    const solution = try solve(allocator);
    std.debug.print("Number of antinode locations: {}\n", .{solution.num_antinodes});
    std.debug.print("Number of resonant antinode locations: {}\n", .{solution.num_resonant_antinodes});
}

fn solve(allocator: std.mem.Allocator) !Solution {
    const input = try common.readFile(input_fname, allocator);
    defer allocator.free(input);

    var grid = AntennaGrid.init(allocator);
    defer grid.deinit();

    try grid.read(input);

    return Solution{
        .num_antinodes = try grid.numAntinodes(false),
        .num_resonant_antinodes = try grid.numAntinodes(true),
    };
}

test AntennaGrid {
    const inputs = [_][]const u8{
        \\..........
        \\..........
        \\..........
        \\....a.....
        \\........a.
        \\.....a....
        \\..........
        \\......A...
        \\..........
        \\..........
        ,
        \\............
        \\........0...
        \\.....0......
        \\.......0....
        \\....0.......
        \\......A.....
        \\............
        \\............
        \\........A...
        \\.........A..
        \\............
        \\............
    };

    const expected_widths = [_]u32{ 10, 12 };
    const expected_heights = [_]u32{ 10, 12 };
    const expected_num_antinodes = [_]u32{ 4, 14 };
    const expected_num_resonant_antinodes = [_]u32{ 8, 34 };

    var expected_antenna_maps = [_]AntennaGrid.AntennaMap{
        AntennaGrid.AntennaMap.init(std.testing.allocator),
        AntennaGrid.AntennaMap.init(std.testing.allocator),
    };
    defer for (0..expected_antenna_maps.len) |i| {
        var map = expected_antenna_maps[i];
        var iter = map.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        map.deinit();
    };

    var antenna0a = std.ArrayList(Point).init(std.testing.allocator);
    try antenna0a.appendSlice(&[_]Point{
        .{ .row = 3, .col = 4 },
        .{ .row = 4, .col = 8 },
        .{ .row = 5, .col = 5 },
    });
    try expected_antenna_maps[0].put('a', antenna0a);

    var antenna0A = std.ArrayList(Point).init(std.testing.allocator);
    try antenna0A.append(.{ .row = 7, .col = 6 });
    try expected_antenna_maps[0].put('A', antenna0A);

    var antenna10 = std.ArrayList(Point).init(std.testing.allocator);
    try antenna10.appendSlice(&[_]Point{
        .{ .row = 1, .col = 8 },
        .{ .row = 2, .col = 5 },
        .{ .row = 3, .col = 7 },
        .{ .row = 4, .col = 4 },
    });
    try expected_antenna_maps[1].put('0', antenna10);

    var antenna1A = std.ArrayList(Point).init(std.testing.allocator);
    try antenna1A.appendSlice(&[_]Point{
        .{ .row = 5, .col = 6 },
        .{ .row = 8, .col = 8 },
        .{ .row = 9, .col = 9 },
    });
    try expected_antenna_maps[1].put('A', antenna1A);

    for (inputs, 0..) |input, i| {
        var grid = AntennaGrid.init(std.testing.allocator);
        defer grid.deinit();

        try grid.read(input);

        try std.testing.expectEqual(expected_widths[i], grid.width);
        try std.testing.expectEqual(expected_heights[i], grid.height);

        const expected_antennas = expected_antenna_maps[i];
        const actual_antennas = grid.antennas;

        try std.testing.expectEqual(expected_antennas.count(), actual_antennas.count());
        var iter = actual_antennas.iterator();
        while (iter.next()) |actual_entry| {
            try std.testing.expect(actual_antennas.contains(actual_entry.key_ptr.*));
            const expected_entry = expected_antennas.get(actual_entry.key_ptr.*).?;
            try std.testing.expectEqualSlices(Point, expected_entry.items, actual_entry.value_ptr.items);
        }

        const actual_num_antinodes = grid.numAntinodes(false);
        const actual_num_resonant_antinodes = grid.numAntinodes(true);
        try std.testing.expectEqual(expected_num_antinodes[i], actual_num_antinodes);
        try std.testing.expectEqual(expected_num_resonant_antinodes[i], actual_num_resonant_antinodes);

        // Uncomment to debug issues with the grid reading and/or antinode generation.
        //try grid.print();
        //try grid.printAntinodes(false);
        //try grid.printAntinodes(true);
    }
}

test solve {
    const expected_num_antinodes = 278;
    const expected_num_resonant_antinodes = 1067;

    const solution = try solve(std.testing.allocator);

    try std.testing.expectEqual(expected_num_antinodes, solution.num_antinodes);
    try std.testing.expectEqual(expected_num_resonant_antinodes, solution.num_resonant_antinodes);
}
