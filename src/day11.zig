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

    for (0..25) |i| {
        std.debug.print("On blink {} count = {}\n", .{ i, stones.count() });
        try stones.blink();
    }

    const num_stones_25 = stones.count();

    // TODO: This grinds to a half after ~35 blinks, how can we optimize this to last 75
    // blinks?

    for (25..75) |i| {
        std.debug.print("On blink {} count = {}\n", .{ i, stones.count() });
        try stones.blink();
    }

    const num_stones_75 = stones.count();

    return Solution{
        .num_stones_25 = num_stones_25,
        .num_stones_75 = num_stones_75,
    };
}

const Stones = struct {
    const Self = @This();

    const StoneList = std.SinglyLinkedList(u64);
    const StoneNode = StoneList.Node;

    // Ok this time we maybe really do need a linked list, so that we can split stones
    // in two. We don't need a doubly linked list because we never need to traverse
    // backwards and when we split a stone, we can always keep the original stone as the
    // new left stone and just insert the new stone to the right of the original stone.
    data: std.SinglyLinkedList(u64),
    num_stones: usize,
    allocator: std.mem.Allocator,

    /// Memoised hashmap to store result of evolving a particular number in attempt to
    /// speed up.
    memoised: std.AutoHashMap(u64, u64),

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .data = std.SinglyLinkedList(u64){},
            .num_stones = 0,
            .memoised = std.AutoHashMap(u64, u64).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        var current_node = self.data.first;
        while (current_node) |node| {
            current_node = node.next;
            self.allocator.destroy(node);
        }

        self.memoised.deinit();
    }

    pub fn read(self: *Self, input: []const u8) !void {
        const trimmed = std.mem.trimRight(u8, input, "\n");
        var iter = std.mem.tokenizeScalar(u8, trimmed, ' ');

        while (iter.next()) |token| {
            const stone = std.fmt.parseInt(u64, token, 10) catch |err| {
                std.debug.print("Error parsing stone {any}: {any}\n", .{ token, err });
                return err;
            };
            const new_node = try self.allocator.create(StoneNode);
            new_node.* = .{ .data = stone };

            self.data.prepend(new_node);
            self.num_stones += 1;
        }
    }

    pub fn blink(self: *Self) !void {
        var fmt_buffer: [64]u8 = undefined;

        var current_node = self.data.first;
        while (current_node) |node| {
            const stone = node.data;

            //const memoised_gop = try self.memoised.getOrPut(stone);
            //if (memoised_gop.found_existing) {
            //    // TODO GAH WE NEED TO SPLIT THE NODES BLAH
            //    //node.data = memoised_result;
            //    current_node = node.next;
            //    continue;
            //}

            // Rule 1: if stone == 0, set it to 1.
            if (stone == 0) {
                node.data = 1;

                current_node = node.next;
                continue;
            }

            // Rule 2: if stone has even n# digits, split it in two stones.
            const stone_str = try std.fmt.bufPrint(&fmt_buffer, "{}", .{stone});
            if (stone_str.len % 2 == 0) {
                const half_len = stone_str.len / 2;
                const left_stone_str = stone_str[0..half_len];
                const right_stone_str = stone_str[half_len..];

                const left_stone = try std.fmt.parseInt(u64, left_stone_str, 10);
                const right_stone = try std.fmt.parseInt(u64, right_stone_str, 10);

                // List is stored in reverse order, so we insert the left stone after
                // the original stone and set the original stone to the right stone.
                const new_node = try self.allocator.create(StoneNode);
                new_node.* = .{ .data = left_stone, .next = node.next };

                node.data = right_stone;
                node.next = new_node;

                self.num_stones += 1;

                // We don't want to process the new node in this iteration.
                current_node = new_node.next;
                continue;
            }

            // Rule 3: multiply stone by 2024.
            node.data *= 2024;

            current_node = node.next;
        }
    }

    pub fn count(self: Self) usize {
        return self.num_stones;
    }
};

test Stones {
    const input = "125 17";

    const expected_stones_after_blinks = [7][]const u64{
        &[_]u64{ 125, 17 },
        &[_]u64{ 253000, 1, 7 },
        &[_]u64{ 253, 0, 2024, 14168 },
        &[_]u64{ 512072, 1, 20, 24, 28676032 },
        &[_]u64{ 512, 72, 2024, 2, 0, 2, 4, 2867, 6032 },
        &[_]u64{ 1036288, 7, 2, 20, 24, 4048, 1, 4048, 8096, 28, 67, 60, 32 },
        &[_]u64{ 2097446912, 14168, 4048, 2, 0, 2, 4, 40, 48, 2024, 40, 48, 80, 96, 2, 8, 6, 7, 6, 0, 3, 2 },
    };

    var stones = Stones.init(std.testing.allocator);
    defer stones.deinit();

    try stones.read(input);

    for (0..expected_stones_after_blinks.len) |i| {
        const expected_stones = expected_stones_after_blinks[i];
        const expected_num_stones = expected_stones.len;

        const actual_num_stones = stones.count();
        try std.testing.expectEqual(expected_num_stones, actual_num_stones);

        // Stones are stored in reverse order.
        var current_node = stones.data.first;
        var j = expected_stones.len;
        while (j != 0) {
            j -= 1;
            try std.testing.expectEqual(expected_stones[j], current_node.?.data);
            current_node = current_node.?.next;
        }

        try stones.blink();
    }
}

test solve {
    const expected_solution = Solution{
        .num_stones_25 = 220722,
        .num_stones_75 = 0,
    };

    const actual_solution = try solve(std.testing.allocator);
    try std.testing.expectEqual(expected_solution, actual_solution);
}
