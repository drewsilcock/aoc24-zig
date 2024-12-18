const std = @import("std");
const common = @import("common.zig");
const Set = @import("set.zig").Set;

const input_fname = "inputs/day10.txt";

pub fn run(allocator: std.mem.Allocator) !void {
    const solution = try solve(allocator);
    std.debug.print("Total trailhead score: {}\n", .{solution.score_sum});
}

const Solution = struct {
    score_sum: u32,
};

fn solve(allocator: std.mem.Allocator) !Solution {
    const input = try common.readFile(input_fname, allocator);
    defer allocator.free(input);

    var map = TopographicMap.init(allocator);
    defer map.deinit();

    try map.read(input);

    const score_sum = try map.totalTrailheadScore();

    return Solution{
        .score_sum = score_sum,
    };
}

const TopographicMap = struct {
    const Self = @This();

    width: u32,
    height: u32,
    data: std.ArrayList(u8),
    allocator: std.mem.Allocator,

    tile_stack: std.ArrayList(u32),
    reached_peaks: Set(u32),

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .width = 0,
            .height = 0,
            .data = std.ArrayList(u8).init(allocator),
            .allocator = allocator,
            .tile_stack = std.ArrayList(u32).init(allocator),
            .reached_peaks = Set(u32).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.data.deinit();
        self.tile_stack.deinit();
        self.reached_peaks.deinit();
    }

    pub fn read(self: *Self, input: []const u8) !void {
        try self.data.ensureTotalCapacityPrecise(input.len - 1);

        var lines = std.mem.tokenizeScalar(u8, input, '\n');

        var col_idx: u32 = 0;
        while (lines.next()) |line| {
            if (self.width == 0) {
                self.width = @intCast(line.len);
            } else if (self.width != line.len) {
                return error.InvalidInput;
            }

            for (line) |c| {
                self.data.appendAssumeCapacity(try std.fmt.charToDigit(c, 10));
            }

            col_idx += 1;
        }

        self.height = col_idx;
    }

    pub fn totalTrailheadScore(self: *Self) !u32 {
        var total_score: u32 = 0;

        for (0..self.width * self.height) |idx| {
            total_score += try self.trailheadScore(@intCast(idx));
        }

        return total_score;
    }

    pub fn trailheadScore(self: *Self, idx: u32) !u32 {
        if (self.data.items[idx] != 0) {
            // This is not a trailhead.
            return 0;
        }

        self.reached_peaks.clearRetainingCapacity();
        self.tile_stack.clearRetainingCapacity();

        try self.tile_stack.append(idx);

        while (self.tile_stack.items.len != 0) {
            const tile_idx = self.tile_stack.pop();
            const tile_height = self.data.items[tile_idx];

            if (tile_height == 9) {
                // We've reached a peak!
                _ = try self.reached_peaks.add(tile_idx);
            } else {
                // Check neighbours for next step in trail.
                var neighbour_tiles = [4]?u32{ null, null, null, null };
                self.neighbours(tile_idx, &neighbour_tiles);

                for (neighbour_tiles) |neighbour| {
                    if (neighbour) |neighbour_idx| {
                        const neighbour_height = self.data.items[neighbour_idx];

                        if (neighbour_height == tile_height + 1) {
                            try self.tile_stack.append(neighbour_idx);
                        }
                    }
                }
            }
        }

        return @intCast(self.reached_peaks.count());
    }

    fn neighbours(self: Self, idx: u32, tiles: *[4]?u32) void {
        const i, const j = self.ij(idx);

        if (i > 0) {
            tiles[0] = self.index(i - 1, j);
        }

        if (i < self.width - 1) {
            tiles[1] = self.index(i + 1, j);
        }

        if (j > 0) {
            tiles[2] = self.index(i, j - 1);
        }

        if (j < self.height - 1) {
            tiles[3] = self.index(i, j + 1);
        }
    }

    fn ij(self: Self, idx: u32) struct { u32, u32 } {
        return .{ idx % self.width, idx / self.width };
    }

    fn index(self: Self, i: u32, j: u32) u32 {
        return j * self.width + i;
    }
};

test TopographicMap {
    const input =
        \\89010123
        \\78121874
        \\87430965
        \\96549874
        \\45678903
        \\32019012
        \\01329801
        \\10456732
    ;

    const expected_score = 36;

    var map = TopographicMap.init(std.testing.allocator);
    defer map.deinit();

    try map.read(input);

    const actual_score = map.totalTrailheadScore();
    try std.testing.expectEqual(expected_score, actual_score);
}

test solve {
    const expected_solution = Solution{
        .score_sum = 550,
    };

    const actual_solution = try solve(std.testing.allocator);

    try std.testing.expectEqual(expected_solution, actual_solution);
}
