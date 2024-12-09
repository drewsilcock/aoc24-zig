const std = @import("std");
const common = @import("common.zig");

const input_fname = "inputs/day6.txt";
const buffer_size = 4096;
const grid_size = 256 * 256;

const GuardDirection = enum {
    Up,
    Down,
    Left,
    Right,
};

const Cell = struct {
    has_obstacle: bool,
    visited: bool,

    pub fn init() Cell {
        return Cell{
            .has_obstacle = false,
            .visited = false,
        };
    }
};

const Guard = struct {
    const Self = @This();

    location: [2]usize,
    direction: GuardDirection,

    pub fn init() Self {
        return Self{
            .location = undefined,
            .direction = GuardDirection.Up,
        };
    }

    pub fn turn(self: *Self) void {
        self.direction = switch (self.direction) {
            GuardDirection.Up => GuardDirection.Right,
            GuardDirection.Right => GuardDirection.Down,
            GuardDirection.Down => GuardDirection.Left,
            GuardDirection.Left => GuardDirection.Up,
        };
    }

    pub fn clone(self: Self) Self {
        return Self{
            .location = [2]usize{ self.location[0], self.location[1] },
            .direction = self.direction,
        };
    }
};

const TerminationReason = enum {
    GuardLeftGrid,
    LoopDetected,
};

const PatrolGrid = struct {
    const Self = @This();

    // We use a 4096 buffer for static allocation but the actual buffer size will be
    // less.
    num_rows: usize,
    num_cols: usize,
    grid_obstacles: [grid_size]bool,
    grid_visited_up: [grid_size]bool,
    grid_visited_right: [grid_size]bool,
    grid_visited_down: [grid_size]bool,
    grid_visited_left: [grid_size]bool,
    guard: Guard,

    pub fn init() Self {
        return Self{
            .num_rows = 0,
            .num_cols = 0,
            .grid_obstacles = [_]bool{false} ** grid_size,
            .grid_visited_up = [_]bool{false} ** grid_size,
            .grid_visited_right = [_]bool{false} ** grid_size,
            .grid_visited_down = [_]bool{false} ** grid_size,
            .grid_visited_left = [_]bool{false} ** grid_size,
            .guard = Guard.init(),
        };
    }

    pub fn read(self: *Self, comptime iter_buffer_size: usize, iter_lines: *common.ReadByLineIterator(iter_buffer_size)) !void {
        var row_idx: u32 = 0;
        while (try iter_lines.next()) |line| {
            if (self.num_cols != undefined and line.len != self.num_cols) {
                return error.InvalidInput;
            }

            self.num_cols = line.len;

            for (line, 0..) |char, col_idx| {
                const idx = self.ijToIndex(row_idx, col_idx);

                self.grid_visited_up[idx] = false;
                self.grid_visited_right[idx] = false;
                self.grid_visited_down[idx] = false;
                self.grid_visited_left[idx] = false;
                self.grid_obstacles[idx] = char == '#';

                switch (char) {
                    '^' => {
                        self.guard.location[0] = row_idx;
                        self.guard.location[1] = col_idx;
                        self.guard.direction = GuardDirection.Up;
                    },
                    '>' => {
                        self.guard.location[0] = row_idx;
                        self.guard.location[1] = col_idx;
                        self.guard.direction = GuardDirection.Right;
                    },
                    'v' => {
                        self.guard.location[0] = row_idx;
                        self.guard.location[1] = col_idx;
                        self.guard.direction = GuardDirection.Down;
                    },
                    '<' => {
                        self.guard.location[0] = row_idx;
                        self.guard.location[1] = col_idx;
                        self.guard.direction = GuardDirection.Left;
                    },
                    '#', '.' => {},
                    else => return error.InvalidInput,
                }
            }

            row_idx += 1;
        }

        self.num_rows = row_idx;
    }

    /// Move the simulation forwards by one step. Returns false if the simulation is
    /// finished because the guard has left the grid area.
    pub fn step(self: *Self) ?TerminationReason {
        const idx = self.ijToIndex(self.guard.location[0], self.guard.location[1]);

        switch (self.guard.direction) {
            .Up => self.grid_visited_up[idx] = true,
            .Right => self.grid_visited_right[idx] = true,
            .Down => self.grid_visited_down[idx] = true,
            .Left => self.grid_visited_left[idx] = true,
        }

        var next_row = self.guard.location[0];
        var next_col = self.guard.location[1];

        switch (self.guard.direction) {
            .Up => {
                if (next_row == 0) {
                    return TerminationReason.GuardLeftGrid;
                }

                next_row -= 1;
            },
            .Down => {
                if (next_row >= self.num_rows - 1) {
                    return TerminationReason.GuardLeftGrid;
                }

                next_row += 1;
            },
            .Left => {
                if (next_col == 0) {
                    return TerminationReason.GuardLeftGrid;
                }

                next_col -= 1;
            },
            .Right => {
                if (next_col >= self.num_cols - 1) {
                    return TerminationReason.GuardLeftGrid;
                }

                next_col += 1;
            },
        }

        const next_idx = self.ijToIndex(next_row, next_col);
        if (self.grid_obstacles[next_idx]) {
            self.guard.turn();
        } else {
            self.guard.location[0] = next_row;
            self.guard.location[1] = next_col;
        }

        const post_idx = self.ijToIndex(self.guard.location[0], self.guard.location[1]);
        switch (self.guard.direction) {
            .Up => if (self.grid_visited_up[post_idx]) return TerminationReason.LoopDetected,
            .Right => if (self.grid_visited_right[post_idx]) return TerminationReason.LoopDetected,
            .Down => if (self.grid_visited_down[post_idx]) return TerminationReason.LoopDetected,
            .Left => if (self.grid_visited_left[post_idx]) return TerminationReason.LoopDetected,
        }

        return null;
    }

    pub fn countVisited(self: Self) u32 {
        var num_visited: u32 = 0;

        for (0..self.num_rows * self.num_cols) |i| {
            if (self.grid_visited_up[i] or self.grid_visited_right[i] or self.grid_visited_down[i] or self.grid_visited_left[i]) {
                num_visited += 1;
            }
        }

        return num_visited;
    }

    fn ijToIndex(self: Self, i: usize, j: usize) usize {
        return i * self.num_cols + j;
    }
};

pub fn day6() !void {
    var file_iter_lines = try common.fileIterLines(buffer_size, input_fname);
    var iter_lines = file_iter_lines.iter();
    defer iter_lines.close();

    var patrol_grid = PatrolGrid.init();

    try patrol_grid.read(buffer_size, &iter_lines);

    // Keep copy of obstacles and initial guard location so we don't have to re-read
    // from file.
    var initial_grid_obstacles = [_]bool{false} ** grid_size;
    @memcpy(&initial_grid_obstacles, &patrol_grid.grid_obstacles);
    const initial_guard = patrol_grid.guard.clone();

    var termination_reason: ?TerminationReason = null;
    while (termination_reason == null) {
        termination_reason = patrol_grid.step();
    }

    const num_visited = patrol_grid.countVisited();
    std.debug.print("Number of visited cells: {}\n", .{num_visited});

    // Try adding an obstacle at each visited cell excluding the initial cell, and
    // re-run the simulation to see whether it causes a loop.
    const initial_guard_idx = patrol_grid.ijToIndex(initial_guard.location[0], initial_guard.location[1]);

    var initial_grid_visited_up = [_]bool{false} ** grid_size;
    var initial_grid_visited_right = [_]bool{false} ** grid_size;
    var initial_grid_visited_down = [_]bool{false} ** grid_size;
    var initial_grid_visited_left = [_]bool{false} ** grid_size;

    @memcpy(&initial_grid_visited_up, &patrol_grid.grid_visited_up);
    @memcpy(&initial_grid_visited_right, &patrol_grid.grid_visited_right);
    @memcpy(&initial_grid_visited_down, &patrol_grid.grid_visited_down);
    @memcpy(&initial_grid_visited_left, &patrol_grid.grid_visited_left);

    var num_loops: u32 = 0;

    for (0..patrol_grid.num_rows * patrol_grid.num_cols) |i| {
        // Reset grid to initial state.
        @memcpy(&patrol_grid.grid_obstacles, &initial_grid_obstacles);
        @memset(&patrol_grid.grid_visited_up, false);
        @memset(&patrol_grid.grid_visited_right, false);
        @memset(&patrol_grid.grid_visited_down, false);
        @memset(&patrol_grid.grid_visited_left, false);
        patrol_grid.guard = initial_guard.clone();

        const cell_visited = initial_grid_visited_up[i] or initial_grid_visited_right[i] or initial_grid_visited_down[i] or initial_grid_visited_left[i];
        if (!cell_visited) {
            // If cell was never visited in the original version, placing an obstacle
            // there will never cause a loop.
            continue;
        }

        if (i == initial_guard_idx) {
            // Rules explicitly state that you cannot place an obstacle on the initial
            // guard location.
            continue;
        }

        // Try placing an obstacle at this location and see whether it causes a loop.
        patrol_grid.grid_obstacles[i] = true;

        termination_reason = null;
        while (termination_reason == null) {
            termination_reason = patrol_grid.step();
        }

        if (termination_reason == TerminationReason.LoopDetected) {
            num_loops += 1;
        }
    }

    std.debug.print("Number of obstacle-induced loops: {}\n", .{num_loops});
}

test PatrolGrid {
    const input =
        \\....#.....
        \\.........#
        \\..........
        \\..#.......
        \\.......#..
        \\..........
        \\.#..^.....
        \\........#.
        \\#.........
        \\......#...
    ;

    var memory_iter_lines = try common.memoryIterLines(input.len, input);

    var iter_lines = memory_iter_lines.iter();
    defer iter_lines.close();

    var patrol_grid = PatrolGrid.init();
    try patrol_grid.read(input.len, &iter_lines);

    const expected_num_rows = 10;
    const expected_num_cols = 10;
    const expected_guard_direction = GuardDirection.Up;
    const expected_guard_location = [2]usize{ 6, 4 };

    const expected_obstacles_full = [_]bool{
        false, false, false, false, true,  false, false, false, false, false,
        false, false, false, false, false, false, false, false, false, true,
        false, false, false, false, false, false, false, false, false, false,
        false, false, true,  false, false, false, false, false, false, false,
        false, false, false, false, false, false, false, true,  false, false,
        false, false, false, false, false, false, false, false, false, false,
        false, true,  false, false, false, false, false, false, false, false,
        false, false, false, false, false, false, false, false, true,  false,
        true,  false, false, false, false, false, false, false, false, false,
        false, false, false, false, false, false, true,  false, false, false,
    };
    var expected_obstacles = [_]bool{false} ** grid_size;
    std.mem.copyForwards(bool, &expected_obstacles, &expected_obstacles_full);

    const expected_visited_up = [_]bool{false} ** grid_size;
    const expected_visited_right = [_]bool{false} ** grid_size;
    const expected_visited_down = [_]bool{false} ** grid_size;
    const expected_visited_left = [_]bool{false} ** grid_size;

    try std.testing.expectEqual(expected_num_rows, patrol_grid.num_rows);
    try std.testing.expectEqual(expected_num_cols, patrol_grid.num_cols);
    try std.testing.expectEqual(expected_guard_direction, patrol_grid.guard.direction);
    try std.testing.expectEqualSlices(usize, &expected_guard_location, &patrol_grid.guard.location);
    try std.testing.expectEqualSlices(bool, &expected_obstacles, &patrol_grid.grid_obstacles);
    try std.testing.expectEqualSlices(bool, &expected_visited_up, &patrol_grid.grid_visited_up);
    try std.testing.expectEqualSlices(bool, &expected_visited_right, &patrol_grid.grid_visited_right);
    try std.testing.expectEqualSlices(bool, &expected_visited_down, &patrol_grid.grid_visited_down);
    try std.testing.expectEqualSlices(bool, &expected_visited_left, &patrol_grid.grid_visited_left);

    var termination_reason: ?TerminationReason = null;
    while (termination_reason == null) {
        termination_reason = patrol_grid.step();
    }

    const expected_num_visited = 41;
    try std.testing.expectEqual(expected_num_visited, patrol_grid.countVisited());
    try std.testing.expectEqual(TerminationReason.GuardLeftGrid, termination_reason);
}

test "PatrolGrid finds loop" {
    const input =
        \\....#.....
        \\.........#
        \\..........
        \\..#.......
        \\.......#..
        \\..........
        \\.#.#^.....
        \\........#.
        \\#.........
        \\......#...
    ;

    var memory_iter_lines = try common.memoryIterLines(input.len, input);

    var iter_lines = memory_iter_lines.iter();
    defer iter_lines.close();

    var patrol_grid = PatrolGrid.init();
    try patrol_grid.read(input.len, &iter_lines);

    var termination_reason: ?TerminationReason = null;
    while (termination_reason == null) {
        termination_reason = patrol_grid.step();
    }

    const expected_visited = 18;
    try std.testing.expectEqual(expected_visited, patrol_grid.countVisited());
    try std.testing.expectEqual(TerminationReason.LoopDetected, termination_reason);
}
