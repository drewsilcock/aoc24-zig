const std = @import("std");
const common = @import("common.zig");

const input_fname = "inputs/day3.txt";

pub fn day3(allocator: std.mem.Allocator) !void {
    const corrupted_memory = try common.readFile(input_fname, allocator);
    defer allocator.free(corrupted_memory);

    var mul_total: u32 = 0;
    var mul_total_conditionals: u32 = 0;

    var muls_enabled = true;

    for (0..corrupted_memory.len) |i| {
        mul_total += try tryParseMul(corrupted_memory, i, allocator);

        if (muls_enabled) {
            // Try parse for muls or don't()s
            if (std.mem.startsWith(u8, corrupted_memory[i..], "don't()")) {
                muls_enabled = false;
            } else {
                mul_total_conditionals += try tryParseMul(corrupted_memory, i, allocator);
            }
        } else {
            // Try parse for dos
            if (std.mem.startsWith(u8, corrupted_memory[i..], "do()")) {
                muls_enabled = true;
            }
        }
    }

    std.debug.print("Total mul: {}\n", .{mul_total});
    std.debug.print("Total mul w/ conditionals: {}\n", .{mul_total_conditionals});
}

const ParseStatusExpectingChar = enum {
    FirstNumber,
    FirstNumberOrComma,
    SecondNumber,
    SecondNumberOrEndBracket,
    SuccessfullyParsed,
};

fn tryParseMul(buffer: []const u8, start_idx: usize, allocator: std.mem.Allocator) !u32 {
    // Could use Boyer-Moore (i.e. bad char table) here but there's no point because
    // the substring is so short.
    if (!std.mem.startsWith(u8, buffer[start_idx..],  "mul(")) {
        return 0;
    }

    var status = ParseStatusExpectingChar.FirstNumber;

    var first_number_str = std.ArrayList(u8).init(allocator);
    defer first_number_str.deinit();

    var second_number_str = std.ArrayList(u8).init(allocator);
    defer second_number_str.deinit();

    var i = start_idx + 4;
    while (i < buffer.len) {
        switch (status) {
            .FirstNumber => {
                if (!isValidDigit(buffer[i])) {
                    return 0;
                }
                try first_number_str.append(buffer[i]);
                status = ParseStatusExpectingChar.FirstNumberOrComma;
            },
            .FirstNumberOrComma => {
                if (buffer[i] == ',') {
                    status = ParseStatusExpectingChar.SecondNumber;
                } else if (!isValidDigit(buffer[i])) {
                    return 0;
                } else {
                    try first_number_str.append(buffer[i]);
                }
            },
            .SecondNumber => {
                if (!isValidDigit(buffer[i])) {
                    return 0;
                }
                try second_number_str.append(buffer[i]);
                status = ParseStatusExpectingChar.SecondNumberOrEndBracket;
            },
            .SecondNumberOrEndBracket => {
                if (buffer[i] == ')') {
                    status = ParseStatusExpectingChar.SuccessfullyParsed;
                    break;
                } else if (!isValidDigit(buffer[i])) {
                    return 0;
                } else {
                    try second_number_str.append(buffer[i]);
                }
            },
            .SuccessfullyParsed => {
                break;
            },
        }
        i += 1;
    }

    if (status != ParseStatusExpectingChar.SuccessfullyParsed) {
        return 0;
    }

    // If these parses fail, we implemented the above logic incorrectly and so should
    // return error, not 0.
    const first_number = try std.fmt.parseInt(u32, first_number_str.items, 10);
    const second_number = try std.fmt.parseInt(u32, second_number_str.items, 10);

    return first_number * second_number;
}

fn isValidDigit(digit: u8) bool {
    return digit >= '0' and digit <= '9';
}

test "tryParseMul valid" {
    const inputs = [_][]const u8{
        "mul(1,2)",
        "mul(2,3)",
        "mul(3,4)",
        "mul(193,41)",
        "mul(193928,1)",
        "mul(0,0)",
        "mul(3,0)",
        "mul(1,1)",
        "mul(99,999)",
    };

    const expected_values = [_]u32{
        1 * 2,
        2 * 3,
        3 * 4,
        193 * 41,
        193928 * 1,
        0 * 0,
        3 * 0,
        1 * 1,
        99 * 999,
    };

    for (inputs, expected_values) |input, expected| {
        const result = try tryParseMul(input, 0, std.heap.page_allocator);
        try std.testing.expectEqual(expected, result);
    }
}

test "tryParseMul invalid" {
    const inputs = [_][]const u8 {
        "add(1,2)",
        "mol(1,2)",
        "mul(1,2]",
        "mul(1,2",
        "mul[1,2)",
        "mul1,2)",
        "mul(1,)",
        "mul(1,1.2)",
        "mul(1,1x2)",
        "mul(12)",
        "mul(1;2)",
        "mul(1, 2)",
        "mul (1, 2)",
        "mul ( 1, 2 )",
        "mul(1,2 )",
        "mul(1.2,2)",
        "mul(1,2.2)",
    };
    const expected = 0;

    for (inputs) |input| {
        const result = try tryParseMul(input, 0, std.heap.page_allocator);
        try std.testing.expectEqual(expected, result);
    }
}
