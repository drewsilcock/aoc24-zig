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

        // If data contains [A: [B, C, D]], then page B, C and D must all be printed
        // before A.
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

        pub fn contains(self: Self, key: T, value: T) bool {
            const values = self.data.get(key) orelse return false;
            return std.sort.binarySearch(
                T,
                value,
                values.items,
                {},
                compare(T),
            ) != null;
        }

        pub fn lessThan(self: Self, a: T, b: T) bool {
            if (self.contains(b, a)) {
                // If there is a rule saying A must come before B, then A is less than
                // B.
                return true;
            }

            return false;
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

    var valid_update_sum: u32 = 0;
    var revalidated_update_sum: u32 = 0;

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

                const gop = try order_map.data.getOrPut(after);
                if (!gop.found_existing) {
                    gop.value_ptr.* = std.ArrayList(u32).init(allocator);
                }

                try gop.value_ptr.*.append(before);
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
                    valid_update_sum += mid_page;
                    continue;
                }

                std.mem.sort(u32, current_update.items, order_map, OrderMap(u32).lessThan);

                if (!isUpdateValid(order_map, current_update.items)) {
                    std.debug.print("Invalid update: {any}\n", .{current_update.items});
                    return error.InvalidUpdate;
                }

                const mid_page = current_update.items[current_update.items.len / 2];
                revalidated_update_sum += mid_page;
            },
        }
    }

    std.debug.print("Sum of mid pages: {}\n", .{valid_update_sum});
    std.debug.print("Sum of revalidated mid pages: {}\n", .{revalidated_update_sum});
}

fn sortOrderMap(order_map: OrderMap(u32)) void {
    var iter = order_map.data.valueIterator();
    while (iter.next()) |value| {
        std.mem.sort(u32, value.items, {}, std.sort.asc(u32));
    }
}

fn compare(comptime T: type) fn (void, T, T) std.math.Order {
    return struct {
        pub fn inner(_: void, a: T, b: T) std.math.Order {
            if (a < b) {
                return std.math.Order.lt;
            } else if (a > b) {
                return std.math.Order.gt;
            } else {
                return std.math.Order.eq;
            }
        }
    }.inner;
}

fn revalidateUpdate(order_map: OrderMap(u32), update: []u32) !void {
    for (update, 0..) |current_page, i| {
        for (i + 1..update.len) |j| {
            const future_page = update[j];

            const has_before_rule = order_map.contains(current_page, future_page);

            if (has_before_rule != null) {
                // The future page should actually come before the current page, so swap
                // them.
                update[i] = future_page;
                update[j] = current_page;
            }
        }
    }
}

fn isUpdateValid(order_map: OrderMap(u32), update: []u32) bool {
    // For each element in the update array, check all the future elements to see
    // whether there are any rules stating that the future element must be printed
    // before the current. If such a violation is found, the update is invalid.
    for (update, 0..) |current_page, i| {
        for (i + 1..update.len) |j| {
            const future_page = update[j];
            const has_before_rule = order_map.contains(current_page, future_page);

            // There is a rule saying that the current must be printed before the
            // previous page, and so the update is not valid.
            if (has_before_rule) {
                return false;
            }
        }
    }

    return true;
}
