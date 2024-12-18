const std = @import("std");
const common = @import("common.zig");
const Set = @import("set.zig").Set;

const input_fname = "inputs/day10.txt";

pub fn run(allocator: std.mem.Allocator) !void {
    const solution = try solve(allocator);
    std.debug.print("Total trailhead score: {}\n", .{solution.score_sum});
    std.debug.print("Total trailhead rating: {}\n", .{solution.rating_sum});
}

const Solution = struct {
    score_sum: u32,
    rating_sum: u32,
};

fn solve(allocator: std.mem.Allocator) !Solution {
    const input = try common.readFile(input_fname, allocator);
    defer allocator.free(input);

    var map = TopographicMap.init(allocator);
    defer map.deinit();

    try map.read(input);

    const metrics = try map.totalTrailheadMetrics();

    return Solution{
        .score_sum = metrics.score,
        .rating_sum = metrics.rating,
    };
}

const TopographicMap = struct {
    const Self = @This();

    const TrailheadMetrics = struct {
        score: u32,
        rating: u32,
    };

    width: u32,
    height: u32,
    data: std.ArrayList(u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .width = 0,
            .height = 0,
            .data = std.ArrayList(u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.data.deinit();
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

    pub fn totalTrailheadMetrics(self: *Self) !TrailheadMetrics {
        // Map from peak index to number of distinct trailheads that reach it.
        // Trailhead score is number of keys in this map. Trailhead rating is sum of
        // values.
        var reached_peak_paths = std.AutoHashMap(u32, u32).init(self.allocator);
        defer reached_peak_paths.deinit();

        var tile_stack = std.ArrayList(u32).init(self.allocator);
        defer tile_stack.deinit();

        var total_score: u32 = 0;
        var total_rating: u32 = 0;

        for (0..self.width * self.height) |idx| {
            try self.trailheadPeakPaths(@intCast(idx), &reached_peak_paths, &tile_stack);

            total_score += reached_peak_paths.count();

            var values_iter = reached_peak_paths.valueIterator();
            while (values_iter.next()) |value| {
                total_rating += value.*;
            }
        }

        return .{
            .score = total_score,
            .rating = total_rating,
        };
    }

    pub fn trailheadPeakPaths(
        self: *Self,
        idx: u32,
        reached_peak_paths: *std.AutoHashMap(u32, u32),
        tile_stack: *std.ArrayList(u32),
    ) !void {
        reached_peak_paths.clearRetainingCapacity();
        tile_stack.clearRetainingCapacity();

        if (self.data.items[idx] != 0) {
            // This is not a trailhead.
            return;
        }

        try tile_stack.append(idx);

        while (tile_stack.items.len != 0) {
            const tile_idx = tile_stack.pop();
            const tile_height = self.data.items[tile_idx];

            if (tile_height == 9) {
                // We've reached a peak!
                const gop = try reached_peak_paths.getOrPut(tile_idx);
                if (!gop.found_existing) {
                    gop.value_ptr.* = 0;
                }
                gop.value_ptr.* += 1;
            } else {
                // Check neighbours for next step in trail.
                var neighbour_tiles = [4]?u32{ null, null, null, null };
                self.neighbours(tile_idx, &neighbour_tiles);

                for (neighbour_tiles) |neighbour| {
                    if (neighbour) |neighbour_idx| {
                        const neighbour_height = self.data.items[neighbour_idx];

                        if (neighbour_height == tile_height + 1) {
                            try tile_stack.append(neighbour_idx);
                        }
                    }
                }
            }
        }
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

    const expected_metrics = TopographicMap.TrailheadMetrics{
        .score = 36,
        .rating = 81,
    };

    var map = TopographicMap.init(std.testing.allocator);
    defer map.deinit();

    try map.read(input);

    const actual_metrics = map.totalTrailheadMetrics();
    try std.testing.expectEqual(expected_metrics, actual_metrics);
}

test solve {
    const expected_solution = Solution{
        .score_sum = 550,
        .rating_sum = 1255,
    };

    const actual_solution = try solve(std.testing.allocator);

    try std.testing.expectEqual(expected_solution, actual_solution);
}
