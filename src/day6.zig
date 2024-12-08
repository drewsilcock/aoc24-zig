const std = @import("std");
const common = @import("common.zig");

const input_fname = "inputs/day6.txt";
const buffer_size = 4096;
const grid_size = 1024;

fn ijToIndex(i: usize, j: usize, num_cols: usize) usize {
    return i * num_cols + j;
}

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
};

const PatrolGrid = struct {
    const Self = @This();

    // We use a 4096 buffer for static allocation but the actual buffer size will be
    // less.
    num_rows: usize,
    num_cols: usize,
    grid_obstacles: [grid_size * grid_size]bool,
    grid_visited: [grid_size * grid_size]bool,
    guard: Guard,

    pub fn init() Self {
        return Self{
            .num_rows = 0,
            .num_cols = 0,
            .grid_obstacles = [_]bool{false} ** (grid_size * grid_size),
            .grid_visited = [_]bool{false} ** (grid_size * grid_size),
            .guard = Guard.init(),
        };
    }

    pub fn read(self: *Self, iter_lines: *common.ReadByLineIterator(4096)) !void {
        var row_idx: u32 = 0;
        while (try iter_lines.next()) |line| {
            if (self.num_cols != undefined and line.len != self.num_cols) {
                return error.InvalidInput;
            }

            self.num_cols = line.len;

            for (line, 0..) |char, col_idx| {
                const idx = ijToIndex(row_idx, col_idx, self.num_cols);

                self.grid_visited[idx] = false;
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
    pub fn step(self: *Self) bool {
        const idx = ijToIndex(self.guard.location[0], self.guard.location[1], self.num_cols);
        self.grid_visited[idx] = true;

        var next_row = self.guard.location[0];
        var next_col = self.guard.location[1];

        switch (self.guard.direction) {
            .Up => next_row -= 1,
            .Down => next_row += 1,
            .Left => next_col -= 1,
            .Right => next_col += 1,
        }

        if (next_row < 0 or next_row >= self.num_rows or next_col < 0 or next_col >= self.num_cols) {
            self.guard.location = undefined;
            return false;
        }

        const next_idx = ijToIndex(next_row, next_col, self.num_cols);
        if (self.grid_obstacles[next_idx]) {
            self.guard.turn();
        } else {
            self.guard.location[0] = next_row;
            self.guard.location[1] = next_col;
        }

        return true;
    }

    pub fn countVisited(self: Self) u32 {
        var num_visited: u32 = 0;

        for (self.grid_visited) |visited| {
            if (visited) {
                num_visited += 1;
            }
        }

        return num_visited;
    }
};

pub fn day6() !void {
    var iter_lines = try common.iterLines(buffer_size, input_fname);
    defer iter_lines.deinit();

    var patrol_grid = PatrolGrid.init();

    try patrol_grid.read(&iter_lines);

    while (patrol_grid.step()) {}

    const num_visited = patrol_grid.countVisited();
    std.debug.print("Number of visited cells: {}\n", .{num_visited});
}
