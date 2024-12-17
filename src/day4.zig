const std = @import("std");
const common = @import("common.zig");

const input_fname = "inputs/day4.txt";
const xmas_word = "XMAS";
const mas_word = "MAS";

pub fn solve(allocator: std.mem.Allocator) !void {
    const lines = try common.readFileLines(input_fname, allocator);
    defer lines.deinit();

    const xmas_count = countXmases(lines);
    const crossmas_count = countCrossMases(lines);

    std.debug.print("Number of XMASes: {}\n", .{xmas_count});
    std.debug.print("Number of Cross-MASes: {}\n", .{crossmas_count});
}

fn countXmases(lines: common.MatrixList(u8)) u32 {
    var count: u32 = 0;

    for (0..lines.numRows()) |line_idx| {
        const line = lines.getRow(line_idx);
        for (0..line.len) |char_idx| {
            count += countXmasesAtCell(lines, line_idx, char_idx);
        }
    }

    return count;
}

fn countCrossMases(lines: common.MatrixList(u8)) u32 {
    var count: u32 = 0;

    for (0..lines.numRows()) |line_idx| {
        const line = lines.getRow(line_idx);
        for (0..line.len) |char_idx| {
            count += countCrossMasesAtCell(lines, line_idx, char_idx);
        }
    }

    return count;
}

/// Using (i, j) as starting point, try trying to spell out "XMAS" in any direction
/// (horizontally, vertically or diagonally), front or backwards.
///
/// i = line
fn countXmasesAtCell(lines: common.MatrixList(u8), line_idx: usize, char_idx: usize) u8 {
    if (lines.getCell(line_idx, char_idx) != 'X') {
        // Early exit if the starting character is not 'X'.
        return 0;
    }

    var num_xmases: u8 = 0;
    num_xmases += @intFromBool(spellsWord(lines, xmas_word, line_idx, char_idx, Direction.Up));
    num_xmases += @intFromBool(spellsWord(lines, xmas_word, line_idx, char_idx, Direction.Down));
    num_xmases += @intFromBool(spellsWord(lines, xmas_word, line_idx, char_idx, Direction.Left));
    num_xmases += @intFromBool(spellsWord(lines, xmas_word, line_idx, char_idx, Direction.Right));
    num_xmases += @intFromBool(spellsWord(lines, xmas_word, line_idx, char_idx, Direction.UpLeft));
    num_xmases += @intFromBool(spellsWord(lines, xmas_word, line_idx, char_idx, Direction.UpRight));
    num_xmases += @intFromBool(spellsWord(lines, xmas_word, line_idx, char_idx, Direction.DownLeft));
    num_xmases += @intFromBool(spellsWord(lines, xmas_word, line_idx, char_idx, Direction.DownRight));
    return num_xmases;
}

fn countCrossMasesAtCell(lines: common.MatrixList(u8), line_idx: usize, char_idx: usize) u8 {
    if (lines.getCell(line_idx, char_idx) != 'A') {
        return 0;
    }

    // Need to have (up-right or down-left) and (down-right or up-left) to form a cross.

    // If we're on first or last row or column, we can't form a cross.
    if (line_idx == 0 or line_idx == lines.numRows() - 1 or char_idx == 0 or char_idx == lines.getRow(line_idx).len - 1) {
        return 0;
    }

    const has_diag_1 = spellsWord(lines, mas_word, line_idx + 1, char_idx - 1, Direction.UpRight) or spellsWord(lines, mas_word, line_idx - 1, char_idx + 1, Direction.DownLeft);
    const has_diag_2 = spellsWord(lines, mas_word, line_idx + 1, char_idx + 1, Direction.UpLeft) or spellsWord(lines, mas_word, line_idx - 1, char_idx - 1, Direction.DownRight);

    const has_cross = has_diag_1 and has_diag_2;

    return if (has_cross) 1 else 0;
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

fn spellsWord(lines: common.MatrixList(u8), word: []const u8, start_line_idx: usize, start_char_idx: usize, direction: Direction) bool {
    var expected_idx: u32 = 0;
    var line_idx = start_line_idx;
    var char_idx = start_char_idx;

    const num_lines = lines.numRows();

    while (true) {
        const num_chars = lines.getRow(line_idx).len;

        const char = lines.getCell(line_idx, char_idx);
        const expected_char = word[expected_idx];

        if (char != expected_char) {
            return false;
        }

        if (expected_idx == word.len - 1) {
            return true;
        }

        expected_idx += 1;

        switch (direction) {
            .Up => {
                if (line_idx == 0) {
                    return false;
                }

                line_idx -= 1;
            },
            .Down => {
                if (line_idx == num_lines - 1) {
                    return false;
                }

                line_idx += 1;
            },
            .Left => {
                if (char_idx == 0) {
                    return false;
                }

                char_idx -= 1;
            },
            .Right => {
                if (char_idx == num_chars - 1) {
                    return false;
                }

                char_idx += 1;
            },
            .UpLeft => {
                if (line_idx == 0 or char_idx == 0) {
                    return false;
                }

                line_idx -= 1;
                char_idx -= 1;
            },
            .UpRight => {
                if (line_idx == 0 or char_idx == num_chars - 1) {
                    return false;
                }

                line_idx -= 1;
                char_idx += 1;
            },
            .DownLeft => {
                if (line_idx == num_lines - 1 or char_idx == 0) {
                    return false;
                }

                line_idx += 1;
                char_idx -= 1;
            },
            .DownRight => {
                if (line_idx == num_lines - 1 or char_idx == num_chars - 1) {
                    return false;
                }

                line_idx += 1;
                char_idx += 1;
            },
        }
    }
}

test "countXmases" {
    var matrix = common.MatrixList(u8).init(std.heap.page_allocator);
    defer matrix.deinit();

    for ([_][]const u8{
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
    }) |line| {
        try matrix.append(line);
    }

    const expected = 18;

    const actual = countXmases(matrix);
    try std.testing.expectEqual(expected, actual);
}

test "countCrossMases" {
    var matrix = common.MatrixList(u8).init(std.heap.page_allocator);
    defer matrix.deinit();

    for ([_][]const u8{
        "AMASAPAPPA",
        "..A..MSMS.",
        ".M.S.MAA..",
        "..A.ASMSM.",
        ".M.S.M....",
        "..........",
        "S.S.S.S.S.",
        ".A.A.A.A..",
        "M.M.M.M.M.",
        "..........",
    }) |line| {
        try matrix.append(line);
    }

    const expected = 9;

    const actual = countCrossMases(matrix);
    try std.testing.expectEqual(expected, actual);
}
