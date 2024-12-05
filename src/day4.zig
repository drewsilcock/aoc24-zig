const std = @import("std");
const common = @import("common.zig");

const input_fname = "inputs/day4.txt";
const xmas = "XMAS";

pub fn day4(allocator: std.mem.Allocator) !void {
    const lines = try common.readFileLines(input_fname, allocator);
    defer lines.deinit();

    const count = countXmases(lines);
    std.debug.print("Number of XMASes: {}\n", .{count});
}

fn countXmases(lines: common.MatrixList(u8)) u32 {
    var count: u32 = 0;
    for (0..lines.numRows()) | line_idx| {
        const line = lines.getRow(line_idx);
        for (0..line.len) |char_idx| {
            count += tryParseXmases(lines, line_idx, char_idx);
        }
    }
    return count;
}

/// Using (i, j) as starting point, try trying to spell out "XMAS" in any direction
/// (horizontally, vertically or diagonally), front or backwards.
///
/// i = line
fn tryParseXmases(lines: common.MatrixList(u8), line_idx: usize, char_idx: usize) u8 {
    if (lines.getCell(line_idx, char_idx) != 'X') {
        // Early exit if the starting character is not 'X'.
        return 0;
    }

    var num_xmases: u8 = 0;
    num_xmases += trySpellXmas(lines, line_idx, char_idx, Direction.Up);
    num_xmases += trySpellXmas(lines, line_idx, char_idx, Direction.Down);
    num_xmases += trySpellXmas(lines, line_idx, char_idx, Direction.Left);
    num_xmases += trySpellXmas(lines, line_idx, char_idx, Direction.Right);
    num_xmases += trySpellXmas(lines, line_idx, char_idx, Direction.UpLeft);
    num_xmases += trySpellXmas(lines, line_idx, char_idx, Direction.UpRight);
    num_xmases += trySpellXmas(lines, line_idx, char_idx, Direction.DownLeft);
    num_xmases += trySpellXmas(lines, line_idx, char_idx, Direction.DownRight);
    return num_xmases;
}

const Direction = enum {
    Up,
    Down,
    Left,
    Right,
    UpLeft,
    UpRight,
    DownLeft,
    DownRight,
};

fn trySpellXmas(lines: common.MatrixList(u8), start_line_idx: usize, start_char_idx: usize, direction: Direction) u8 {
    var expected_xmas_idx: u32 = 0;
    var line_idx = start_line_idx;
    var char_idx = start_char_idx;

    const num_lines = lines.numRows();

    while (true) {
        const num_chars = lines.getRow(line_idx).len;

        const char = lines.getCell(line_idx, char_idx);
        const expected_char = xmas[expected_xmas_idx];

        if (char != expected_char) {
            return 0;
        }

        if (expected_xmas_idx == xmas.len - 1) {
            return 1;
        }

        expected_xmas_idx += 1;

        switch (direction) {
            .Up => {
                if (line_idx == 0) {
                    return 0;
                }

                line_idx -= 1;
            },
            .Down => {
                if (line_idx == num_lines - 1) {
                    return 0;
                }

                line_idx += 1;
            },
            .Left => {
                if (char_idx == 0) {
                    return 0;
                }

                char_idx -= 1;
            },
            .Right => {
                if (char_idx == num_chars - 1) {
                    return 0;
                }

                char_idx += 1;
            },
            .UpLeft => {
                if (line_idx == 0 or char_idx == 0) {
                    return 0;
                }

                line_idx -= 1;
                char_idx -= 1;
            },
            .UpRight => {
                if (line_idx == 0 or char_idx == num_chars - 1) {
                    return 0;
                }

                line_idx -= 1;
                char_idx += 1;
            },
            .DownLeft => {
                if (line_idx == num_lines - 1 or char_idx == 0) {
                    return 0;
                }

                line_idx += 1;
                char_idx -= 1;
            },
            .DownRight => {
                if (line_idx == num_lines - 1 or char_idx == num_chars - 1) {
                    return 0;
                }

                line_idx += 1;
                char_idx += 1;
            },
        }
    }
}

test "countXmases" {
    const lines = [_][]const u8{
        "MMMSXXMASM",
        "MSAMXMSMSA",
        "AMXSXMAAMM",
        "MSAMASMSMX",
        "XMASAMXAMM",
        "XXAMMXXAMA",
        "SMSMSASXSS",
        "SAXAMASAAA",
        "MAMMMXMMMM",
        "MXMXAXMASX",
    };

    const expected = 18;

    const actual = countXmases(lines[0..]);
    try std.testing.expectEqual(expected, actual);
}
