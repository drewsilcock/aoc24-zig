const std = @import("std");
const day1 = @import("day1.zig");
const day2 = @import("day2.zig");
const day3 = @import("day3.zig");
const day4 = @import("day4.zig");
const day5 = @import("day5.zig");
const day6 = @import("day6.zig");
const day7 = @import("day7.zig");
const day8 = @import("day8.zig");
const day9 = @import("day9.zig");
const day10 = @import("day10.zig");
const day11 = @import("day11.zig");
const day12 = @import("day12.zig");
const day13 = @import("day13.zig");
const day14 = @import("day14.zig");
const day15 = @import("day15.zig");
const day16 = @import("day16.zig");
const day17 = @import("day17.zig");
const day18 = @import("day18.zig");
const day19 = @import("day19.zig");
const day20 = @import("day20.zig");
const day21 = @import("day21.zig");
const day22 = @import("day22.zig");
const day23 = @import("day23.zig");
const day24 = @import("day24.zig");
const day25 = @import("day25.zig");

pub fn main() !void {
    var args = std.process.args();
    defer args.deinit();

    _ = args.skip();
    const challengeNumberStr = args.next() orelse return usage();
    const challengeNumber = std.fmt.parseInt(u32, challengeNumberStr, 10) catch return usage();

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    switch (challengeNumber) {
        1 => try day1.solve(allocator),
        2 => try day2.solve(allocator),
        3 => try day3.solve(allocator),
        4 => try day4.solve(allocator),
        5 => try day5.solve(allocator),
        6 => try day6.solve(),
        7 => try day7.run(allocator),
        8 => try day8.run(allocator),
        9 => try day9.run(allocator),
        10 => try day10.run(allocator),
        11 => try day11.run(allocator),
        12 => try day12.run(allocator),
        13 => try day13.run(allocator),
        14 => try day14.run(allocator),
        15 => try day15.run(allocator),
        16 => try day16.run(allocator),
        17 => try day17.run(allocator),
        18 => try day18.run(allocator),
        19 => try day19.run(allocator),
        20 => try day20.run(allocator),
        21 => try day21.run(allocator),
        22 => try day22.run(allocator),
        23 => try day23.run(allocator),
        24 => try day24.run(allocator),
        25 => try day25.run(allocator),
        else => return error.InvalidArguments,
    }
}

fn usage() void {
    std.debug.print("Usage: program <challenge n#>\n", .{});
    std.process.exit(1);
}
