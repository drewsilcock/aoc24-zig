const std = @import("std");
const common = @import("common.zig");

pub fn run(allocator: std.mem.Allocator) !void {
    const solution = try solve(allocator);
    std.debug.print("Number of stones after 25 blinks: {}\n", .{solution.num_stones_25});
    std.debug.print("Number of stones after 75 blinks: {}\n", .{solution.num_stones_75});
}

const Solution = struct {
    num_stones_25: usize,
    num_stones_75: usize,
};

fn solve(allocator: std.mem.Allocator) !Solution {
    const input = try common.readFile("inputs/day11.txt", allocator);
    defer allocator.free(input);

    var stones = Stones.init(allocator);
    defer stones.deinit();

    try stones.read(input);

    for (0..25) |_| {
        try stones.blink();
    }

    const num_stones_25 = stones.len();

    for (25..75) |_| {
        try stones.blink();
    }

    const num_stones_75 = stones.len();

    return Solution{
        .num_stones_25 = num_stones_25,
        .num_stones_75 = num_stones_75,
    };
}

const Stones = struct {
    const Self = @This();

    // The whole 'list' thing is a red herring – we only need to know the number so it
    // literally doesn't matter what order they're in. The rules only apply to single
    // stones, so just keep track of how many there are of each stone.
    data: std.AutoHashMap(u64, u64),

    // Keep another hashmap for the new stones, like a swap buffer.
    new_data: std.AutoHashMap(u64, u64),

    num_stones: u64,

    fmt_buf: [64]u8,

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .data = std.AutoHashMap(u64, u64).init(allocator),
            .new_data = std.AutoHashMap(u64, u64).init(allocator),
            .num_stones = 0,
            .fmt_buf = undefined,
        };
    }

    pub fn deinit(self: *Self) void {
        self.data.deinit();
        self.new_data.deinit();
    }

    pub fn read(self: *Self, input: []const u8) !void {
        const trimmed = std.mem.trimRight(u8, input, "\n");
        var iter = std.mem.tokenizeScalar(u8, trimmed, ' ');

        while (iter.next()) |token| {
            const stone = try std.fmt.parseInt(u64, token, 10);

            const gop = try self.data.getOrPut(stone);
            if (gop.found_existing) {
                gop.value_ptr.* += 1;
            } else {
                gop.value_ptr.* = 1;
            }

            self.num_stones += 1;
        }
    }

    /// Add stone to `self.new_data`.
    fn addStones(self: *Self, stone: u64, count: u64) !void {
        const gop = try self.new_data.getOrPut(stone);
        if (gop.found_existing) {
            gop.value_ptr.* += count;
        } else {
            gop.value_ptr.* = count;
        }
    }

    pub fn blink(self: *Self) !void {
        // We need to put the new stones in a separate hashmap because we can't modify
        // the original one. We keep a hashmap dedicated for this purpose.
        self.new_data.clearRetainingCapacity();

        var iter = self.data.iterator();

        var num_stones: u64 = 0;

        while (iter.next()) |entry| {
            const stone = entry.key_ptr.*;
            const count = entry.value_ptr.*;

            // Rule 1: if stone == 0, set it to 1.
            if (stone == 0) {
                try self.addStones(1, count);
                num_stones += count;
                continue;
            }

            // Rule 2: if stone has even n# digits, split it in two stones.
            const stone_str = try std.fmt.bufPrint(&self.fmt_buf, "{}", .{stone});
            if (stone_str.len % 2 == 0) {
                const half_len = stone_str.len / 2;
                const left_stone_str = stone_str[0..half_len];
                const right_stone_str = stone_str[half_len..];

                const left_stone = try std.fmt.parseInt(u64, left_stone_str, 10);
                const right_stone = try std.fmt.parseInt(u64, right_stone_str, 10);

                try self.addStones(left_stone, count);
                try self.addStones(right_stone, count);

                num_stones += count + count;
                continue;
            }

            // Rule 3: multiply stone by 2024.
            try self.addStones(stone * 2024, count);
            num_stones += count;
        }

        std.mem.swap(std.AutoHashMap(u64, u64), &self.data, &self.new_data);
        self.num_stones = num_stones;
    }

    pub fn print(self: Self) void {
        var iter = self.data.iterator();
        while (iter.next()) |entry| {
            const stone = entry.key_ptr.*;
            const count = entry.value_ptr.*;

            std.debug.print("{}={}, ", .{ stone, count });
        }
        std.debug.print("\n", .{});
    }

    pub fn len(self: Self) usize {
        return self.num_stones;
    }
};

test Stones {
    const input = "125 17";

    const MapEntry = struct { stone: u64, count: u64 };

    const expected_stones_after_blinks = [7][]const MapEntry{
        &[_]MapEntry{
            .{ .stone = 17, .count = 1 },
            .{ .stone = 125, .count = 1 },
        },
        &[_]MapEntry{
            .{ .stone = 1, .count = 1 },
            .{ .stone = 7, .count = 1 },
            .{ .stone = 253000, .count = 1 },
        },
        &[_]MapEntry{
            .{ .stone = 0, .count = 1 },
            .{ .stone = 253, .count = 1 },
            .{ .stone = 2024, .count = 1 },
            .{ .stone = 14168, .count = 1 },
        },
        &[_]MapEntry{
            .{ .stone = 1, .count = 1 },
            .{ .stone = 20, .count = 1 },
            .{ .stone = 24, .count = 1 },
            .{ .stone = 512072, .count = 1 },
            .{ .stone = 28676032, .count = 1 },
        },
        &[_]MapEntry{
            .{ .stone = 0, .count = 1 },
            .{ .stone = 2, .count = 2 },
            .{ .stone = 4, .count = 1 },
            .{ .stone = 72, .count = 1 },
            .{ .stone = 512, .count = 1 },
            .{ .stone = 2024, .count = 1 },
            .{ .stone = 2867, .count = 1 },
            .{ .stone = 6032, .count = 1 },
        },
        &[_]MapEntry{
            .{ .stone = 1, .count = 1 },
            .{ .stone = 2, .count = 1 },
            .{ .stone = 7, .count = 1 },
            .{ .stone = 20, .count = 1 },
            .{ .stone = 24, .count = 1 },
            .{ .stone = 28, .count = 1 },
            .{ .stone = 32, .count = 1 },
            .{ .stone = 60, .count = 1 },
            .{ .stone = 67, .count = 1 },
            .{ .stone = 4048, .count = 2 },
            .{ .stone = 8096, .count = 1 },
            .{ .stone = 1036288, .count = 1 },
        },
        &[_]MapEntry{
            .{ .stone = 0, .count = 2 },
            .{ .stone = 2, .count = 4 },
            .{ .stone = 3, .count = 1 },
            .{ .stone = 4, .count = 1 },
            .{ .stone = 6, .count = 2 },
            .{ .stone = 7, .count = 1 },
            .{ .stone = 8, .count = 1 },
            .{ .stone = 40, .count = 2 },
            .{ .stone = 48, .count = 2 },
            .{ .stone = 80, .count = 1 },
            .{ .stone = 96, .count = 1 },
            .{ .stone = 2024, .count = 1 },
            .{ .stone = 4048, .count = 1 },
            .{ .stone = 14168, .count = 1 },
            .{ .stone = 2097446912, .count = 1 },
        },
    };

    var stones = Stones.init(std.testing.allocator);
    defer stones.deinit();

    try stones.read(input);

    for (0..expected_stones_after_blinks.len) |i| {
        const expected_stones = expected_stones_after_blinks[i];

        var expected_num_stones: u64 = 0;
        for (expected_stones) |expected_entry| {
            expected_num_stones += expected_entry.count;
        }

        const actual_num_stones = stones.len();
        try std.testing.expectEqual(expected_num_stones, actual_num_stones);

        for (expected_stones) |expected_entry| {
            try std.testing.expect(stones.data.contains(expected_entry.stone));
            const actual_count = stones.data.get(expected_entry.stone).?;
            try std.testing.expectEqual(expected_entry.count, actual_count);
        }

        try stones.blink();
    }
}

test solve {
    const expected_solution = Solution{
        .num_stones_25 = 220722,
        .num_stones_75 = 261952051690787,
    };

    const actual_solution = try solve(std.testing.allocator);
    try std.testing.expectEqual(expected_solution, actual_solution);
}
