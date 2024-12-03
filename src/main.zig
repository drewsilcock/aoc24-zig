const std = @import("std");
const day1 = @import("day1.zig");

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

    const challengeFunc = switch (challengeNumber) {
        1 => day1.day1,
        else => return error.InvalidArguments,
    };

    try challengeFunc(allocator);
}

fn usage() void {
    std.debug.print("Usage: program <challenge n#>\n", .{});
    std.process.exit(1);
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
