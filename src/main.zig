const std = @import("std");
const day1 = @import("day1.zig");
const day2 = @import("day2.zig");
const day3 = @import("day3.zig");
const day4 = @import("day4.zig");
const day5 = @import("day5.zig");

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
        1 => try day1.day1(allocator),
        2 => try day2.day2(allocator),
        3 => try day3.day3(allocator),
        4 => try day4.day4(allocator),
        5 => try day5.day5(allocator),
        else => return error.InvalidArguments,
    }
}

fn usage() void {
    std.debug.print("Usage: program <challenge n#>\n", .{});
    std.process.exit(1);
}
