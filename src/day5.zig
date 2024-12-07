const std = @import("std");
const common = @import("common.zig");

const input_fname = "inputs/day5.txt";

const ParseMode = enum {
    PageOrderingRules,
    Updates,
};

fn OrderMap(comptime T: type) type {
    return struct {
    const Self = @This();
    
    data: std.AutoHashMap(T, std.ArrayList(T)),

    pub fn init(allocator: std.mem.Allocator) !Self {
        return Self{
            .data = std.AutoHashMap(T, std.ArrayList(T)).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.data.valueIterator();
        while (iter.next()) |value| {
            value.deinit();
        }
        self.data.deinit();
    }
    };
}

pub fn day5(allocator: std.mem.Allocator) !void {
    var iter_lines = try common.iterLines(4096, input_fname);
    defer iter_lines.deinit();

    var mode = ParseMode.PageOrderingRules;

    // If order_map[0] = [1, 2, 3], then page 0 must be printed before pages 1, 2, and 3.
    var order_map = try OrderMap(u32).init(allocator);
    defer order_map.deinit();

    var valid_update_midpages = std.ArrayList(u32).init(allocator);
    defer valid_update_midpages.deinit();

    var current_update = std.ArrayList(u32).init(allocator);
    defer current_update.deinit();

    while (try iter_lines.next()) |line| {
        switch (mode) {
            .PageOrderingRules => {
                if (line.len == 0) {
                    // Sort the map values in ascending order so that we can do binary
                    // search on them later.
                    sortOrderMap(order_map);

                    mode = ParseMode.Updates;
                    continue;
                }

                var parts = std.mem.splitScalar(u8, line, '|');

                const before_str = parts.next() orelse return error.ParseError;
                const after_str = parts.next() orelse return error.ParseError;

                const before = try std.fmt.parseInt(u32, before_str, 10);
                const after = try std.fmt.parseInt(u32, after_str, 10);

                const gop = try order_map.data.getOrPut(before);
                if (!gop.found_existing) {
                    gop.value_ptr.* = std.ArrayList(u32).init(allocator);
                }

                try gop.value_ptr.*.append(after);
            },
            .Updates => {
                current_update.clearRetainingCapacity();

                var parts = std.mem.splitScalar(u8, line, ',');
                while (parts.next()) |item| {
                    const page = try std.fmt.parseInt(u32, item, 10);
                    try current_update.append(page);
                }

                if (isUpdateValid(order_map, current_update.items)) {
                    const mid_page = current_update.items[current_update.items.len / 2];
                    try valid_update_midpages.append(mid_page);
                }
            },
        }
    }

    var mid_pages_sum: u32 = 0;
    for (valid_update_midpages.items) |mid_page| {
        mid_pages_sum += mid_page;
    }

    std.debug.print("Sum of mid pages: {}\n", .{mid_pages_sum});
}

fn sortOrderMap(order_map: OrderMap(u32)) void {
    var iter = order_map.data.valueIterator();
    while (iter.next()) |value| {
        std.mem.sort(u32, value.items, {}, std.sort.asc(u32));
    }
}

fn compareU32(_: void, a: u32, b: u32) std.math.Order {
    if (a < b) {
        return std.math.Order.lt;
    } else if (a > b) {
        return std.math.Order.gt;
    } else {
        return std.math.Order.eq;
    }
}

fn isUpdateValid(
    order_map: OrderMap(u32),
    update: []u32,
) bool {
    // For each element in the update array, check all the previous elements to see
    // whether there are any rules stating that the latter must be printed before the
    // former. If such a violation is found, return false.
    for (update, 0..) |current_page, i| {
        for (0..i) |j| {
            const prev_page = update[j];
            const order_value = order_map.data.get(current_page) orelse continue;

            const has_before_rule = std.sort.binarySearch(u32, prev_page, order_value.items, {}, compareU32);

            // There is a rule saying that the current must be printed before the
            // previous page, and so the update is not valid.
            if (has_before_rule != null) {
                return false;
            }
        }
    }

    return true;
}
