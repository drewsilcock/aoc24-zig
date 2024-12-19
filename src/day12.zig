const std = @import("std");
const common = @import("common.zig");

pub fn run(allocator: std.mem.Allocator) !void {
    const solution = try solve(allocator);
    std.debug.print("Fence price: {}\n", .{solution.fence_price});
}

const Solution = struct {
    fence_price: u32,
};

fn solve(allocator: std.mem.Allocator) !Solution {
    const input = try common.readFile("inputs/day12.txt", allocator);
    defer allocator.free(input);

    var garden = Garden.init(allocator);
    defer garden.deinit();

    try garden.read(input);

    const fence_price = try garden.fencePrice();

    return Solution{
        .fence_price = fence_price,
    };
}

const Garden = struct {
    const Self = @This();

    const Region = struct {
        area: u32,
        perimeter: u32,
        plant_type: u8,
    };

    data: std.ArrayList(u8),
    width: usize,
    height: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .data = std.ArrayList(u8).init(allocator),
            .width = 0,
            .height = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.data.deinit();
    }

    pub fn read(self: *Self, input: []const u8) !void {
        try self.data.ensureTotalCapacityPrecise(input.len - 1);

        var lines = std.mem.tokenizeScalar(u8, input, '\n');
        while (lines.next()) |line| {
            if (self.width == 0) {
                self.width = line.len;
            } else if (self.width != line.len) {
                return error.InvalidInput;
            }

            for (line) |c| {
                self.data.appendAssumeCapacity(c);
            }
        }

        self.height = self.data.items.len / self.width;
    }

    pub fn fencePrice(self: Self) !u32 {
        var regions = std.ArrayList(Region).init(self.allocator);
        defer regions.deinit();

        try self.calculateRegions(&regions);

        var fence_price: u32 = 0;
        for (regions.items) |region| {
            fence_price += region.perimeter * region.area;
        }

        return fence_price;
    }

    fn calculateRegions(self: Self, regions: *std.ArrayList(Region)) !void {
        var visited = try std.ArrayList(bool).initCapacity(self.allocator, self.data.items.len);
        defer visited.deinit();

        var tile_stack = try std.ArrayList(usize).initCapacity(self.allocator, self.data.items.len);
        defer tile_stack.deinit();

        visited.appendNTimesAssumeCapacity(false, self.data.items.len);

        for (0..self.width * self.height) |idx| {
            if (visited.items[idx]) {
                continue;
            }

            tile_stack.clearRetainingCapacity();
            try tile_stack.append(idx);

            var region = Region{
                .area = 1,
                .perimeter = 0,
                .plant_type = self.data.items[idx],
            };

            visited.items[idx] = true;

            while (tile_stack.popOrNull()) |tile_idx| {
                const i = tile_idx % self.width;
                const j = tile_idx / self.width;
                const plant = self.data.items[tile_idx];

                var neighbours = [4]?usize{ null, null, null, null };
                self.tileNeighbours(i, j, &neighbours);

                for (neighbours) |maybe_neighbour_idx| {
                    if (maybe_neighbour_idx == null) {
                        // Neighbour is off edge of grid, which points as part of the
                        // perimeter.
                        if (idx == 0) {
                            std.debug.print("[{}] {} has neighbour facing off grid which counts as perimeter + 1\n", .{ idx, tile_idx });
                        }
                        region.perimeter += 1;
                        continue;
                    }

                    const neighbour_idx = maybe_neighbour_idx.?;
                    const neighbour_plant = self.data.items[neighbour_idx];
                    if (plant == neighbour_plant) {
                        if (visited.items[neighbour_idx]) {
                            // Don't double count the area of a tile.
                            if (idx == 0) {
                                std.debug.print("[{}] Tile {} has same neighbour {} which is already visited\n", .{ idx, tile_idx, neighbour_idx });
                            }
                            continue;
                        }

                        if (idx == 0) {
                            std.debug.print("[{}] Tile {} has same neighbour {} so area + 1\n", .{ idx, tile_idx, neighbour_idx });
                        }
                        region.area += 1;
                        visited.items[neighbour_idx] = true;
                        try tile_stack.append(neighbour_idx);
                    } else {
                        if (idx == 0) {
                            std.debug.print("[{}] Tile {} has diff neighbour {} so perimeter + 1\n", .{ idx, tile_idx, neighbour_idx });
                        }
                        region.perimeter += 1;
                        // We haven't actually counted the area of the neighbouring
                        // tile, just the perimeter.
                    }
                }
            }

            std.debug.print("Region for {c} starting at idx {} has area {} and perimeter {}\n", .{ region.plant_type, idx, region.area, region.perimeter });

            try regions.append(region);
        }
    }

    fn tileNeighbours(self: Self, i: usize, j: usize, neighbours: *[4]?usize) void {
        if (i > 0) {
            neighbours[0] = self.ij(i - 1, j);
        }

        if (i < self.width - 1) {
            neighbours[1] = self.ij(i + 1, j);
        }

        if (j > 0) {
            neighbours[2] = self.ij(i, j - 1);
        }

        if (j < self.height - 1) {
            neighbours[3] = self.ij(i, j + 1);
        }
    }

    fn ij(self: Self, i: usize, j: usize) usize {
        return j * self.width + i;
    }
};

test Garden {
    const input =
        \\RRRRIICCFF
        \\RRRRIICCCF
        \\VVRRRCCFFF
        \\VVRCCCJFFF
        \\VVVVCJJCFE
        \\VVIVCCJJEE
        \\VVIIICJJEE
        \\MIIIIIJJEE
        \\MIIISIJEEE
        \\MMMISSJEEE
    ;

    const expected_regions = [_]Garden.Region{
        .{ .plant_type = 'R', .area = 12, .perimeter = 18 },
        .{ .plant_type = 'I', .area = 4, .perimeter = 8 },
        .{ .plant_type = 'C', .area = 14, .perimeter = 28 },
        .{ .plant_type = 'F', .area = 10, .perimeter = 18 },
        .{ .plant_type = 'V', .area = 13, .perimeter = 20 },
        .{ .plant_type = 'J', .area = 11, .perimeter = 20 },
        .{ .plant_type = 'C', .area = 1, .perimeter = 4 },
        .{ .plant_type = 'E', .area = 13, .perimeter = 18 },
        .{ .plant_type = 'I', .area = 14, .perimeter = 22 },
        .{ .plant_type = 'M', .area = 5, .perimeter = 12 },
        .{ .plant_type = 'S', .area = 3, .perimeter = 8 },
    };

    var garden = Garden.init(std.testing.allocator);
    defer garden.deinit();

    try garden.read(input);

    var regions = std.ArrayList(Garden.Region).init(std.testing.allocator);
    defer regions.deinit();

    try garden.calculateRegions(&regions);

    try std.testing.expectEqualSlices(Garden.Region, &expected_regions, regions.items);
}

test solve {
    const expected_solution = Solution{
        .fence_price = 1494342,
    };

    const actual_solution = try solve(std.testing.allocator);
    try std.testing.expectEqual(expected_solution, actual_solution);
}
