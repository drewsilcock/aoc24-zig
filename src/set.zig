const std = @import("std");

const Allocator = std.mem.Allocator;

/// Set provides a basic set data structure for storing unique elements.
///
/// The set is implemented using an auto hash map, i.e. using the standard eql and hash
/// functions. It is inspired by github.com/deckarep/ziglang-set but stripped down to
/// just what I need.
pub fn Set(comptime T: type) type {
    return struct {
        const Self = @This();
        const Map = if (T == []const u8) std.StringHashMap(void) else std.AutoHashMap(T, void);
        pub const Iterator = Map.KeyIterator;

        allocator: Allocator,
        map: Map,

        pub fn init(allocator: Allocator) Self {
            return .{
                .allocator = allocator,
                .map = Map.init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.map.deinit();
        }

        pub fn clearRetainingCapacity(self: *Self) void {
            self.map.clearRetainingCapacity();
        }

        /// Add new element to set, returning whether the element was added.
        pub fn add(self: *Self, element: T) Allocator.Error!bool {
            const prev_count = self.map.count();
            try self.map.put(element, {});
            return self.map.count() != prev_count;
        }

        pub fn remove(self: *Self, element: T) void {
            return self.map.remove(element);
        }

        pub fn contains(self: *Self, element: T) bool {
            return self.map.contains(element);
        }

        pub fn count(self: Self) usize {
            return self.map.count();
        }

        pub fn iterator(self: Self) Iterator {
            return self.map.keyIterator();
        }

        pub fn toOwnedSlice(self: Self) ![]T {
            var list = try std.ArrayList(T).initCapacity(self.allocator, self.count());

            var key_iter = self.map.keyIterator();
            while (key_iter.next()) |key| {
                try list.append(key);
            }

            return list.toOwnedSlice();
        }
    };
}
