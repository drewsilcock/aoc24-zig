const std = @import("std");
const common = @import("common.zig");

const input_fname = "inputs/day9.txt";

const Solution = struct {
    compact_checksum: u64,
    defrag_compact_checksum: u64,
};

pub fn run(allocator: std.mem.Allocator) !void {
    const solution = try solve(allocator);
    std.debug.print("Compacted filesystem checksum: {}\n", .{solution.compact_checksum});
    std.debug.print("Defragmentation compacted filesystem checksum: {}\n", .{solution.defrag_compact_checksum});
}

fn solve(allocator: std.mem.Allocator) !Solution {
    const input = try common.readFile(input_fname, allocator);
    defer allocator.free(input);

    var filesystem = Filesystem.init(allocator);
    defer filesystem.deinit();

    try filesystem.readDiskMap(input);
    try filesystem.compact();

    const compact_checksum = filesystem.checksum();

    var defrag_fs = Filesystem.init(allocator);
    defer defrag_fs.deinit();

    try defrag_fs.readDiskMap(input);
    try defrag_fs.defragCompact();

    const defrag_compact_checksum = defrag_fs.checksum();

    return Solution{
        .compact_checksum = compact_checksum,
        .defrag_compact_checksum = defrag_compact_checksum,
    };
}

const Filesystem = struct {
    const Self = @This();

    const Block = ?u32; // null means free
    const BlockList = std.ArrayList(Block);
    const File = struct {
        id: u32,
        start_idx: u32,
        size: u8,
    };
    const FileList = std.ArrayList(File);

    blocks: BlockList,
    num_blocks: i32 = 0,
    files: FileList, // Not used by compact, only defragCompact
    allocator: std.mem.Allocator,

    // I originally tried keeping track of free spaces here, but the overhead of
    // re-calculating the free space map after each defragmentation step was too high.

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .blocks = BlockList.init(allocator),
            .num_blocks = 0,
            .files = FileList.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.blocks.deinit();
        self.files.deinit();
        self.num_blocks = 0;
    }

    pub fn readDiskMap(self: *Self, disk_map: []const u8) !void {
        var is_file_block = true;
        var current_block_id: u32 = 0;

        // Block index is different to iteration index because a single disk map entry
        // represents multiple blocks.
        var block_idx: u32 = 0;

        for (disk_map) |map_entry| {
            if (map_entry == '\n') {
                break;
            }

            const num_blocks = try std.fmt.charToDigit(map_entry, 10);

            if (num_blocks != 0) {
                const block_id = if (is_file_block) current_block_id else null;

                try self.blocks.appendNTimes(block_id, num_blocks);

                if (is_file_block) {
                    try self.files.append(.{
                        .id = current_block_id,
                        .start_idx = block_idx,
                        .size = num_blocks,
                    });

                    current_block_id += 1;
                }
            }

            block_idx += num_blocks;
            is_file_block = !is_file_block;
        }

        self.num_blocks = @intCast(self.blocks.items.len);
    }

    /// Compact blocks into left-most free spaces.
    ///
    /// This will invalidate the start indices in the `self.files` list.
    pub fn compact(self: *Self) !void {
        var left_index: i32 = -1;
        var right_index: i32 = self.num_blocks;

        while (true) {
            while (true) {
                left_index += 1;

                if (left_index >= right_index) {
                    // We've gone past the rightmost file block so there's no
                    // opportunity for more compaction.
                    return;
                }

                if (left_index == self.num_blocks) {
                    // No more free blocks left in the filesystem.
                    return;
                }

                if (self.blocks.items[@intCast(left_index)] == null) {
                    // We've found the next leftmost free block.
                    break;
                }
            }

            while (true) {
                right_index -= 1;

                if (right_index == -1) {
                    // No more files blocks left to compact.
                    return;
                }

                if (right_index <= left_index) {
                    // We've gone past the leftmost free block so there's no
                    // opportunity for more compaction.
                    return;
                }

                if (self.blocks.items[@intCast(right_index)] != null) {
                    // We've found the next rightmost file block.
                    break;
                }
            }

            // Swap the left and right blocks around.
            const li: u32 = @intCast(left_index);
            const ri: u32 = @intCast(right_index);
            self.blocks.items[li] = self.blocks.items[ri];
            self.blocks.items[ri] = null;
        }
    }

    /// Rearrange the blocks so that all file blocks are contiguous.
    pub fn defragCompact(self: *Self) !void {
        // Keep track of where we found the earliest free block for a specific size –
        // there's no point looking to the left of that when we're looking for the size
        // up.
        var earliest_free_block: [10]u32 = [_]u32{0} ** 10;

        var i = self.files.items.len;
        while (i > 0) {
            i -= 1;

            const file = self.files.items[i];

            const free_space_idx = self.freeSpaceForSize(file.size, earliest_free_block[file.size]) orelse continue;
            earliest_free_block[file.size] = free_space_idx;

            if (free_space_idx > file.start_idx) {
                // We can move the file to the left.
                continue;
            }

            for (free_space_idx..free_space_idx + file.size) |j| {
                self.blocks.items[j] = file.id;
            }

            for (file.start_idx..file.start_idx + file.size) |j| {
                self.blocks.items[j] = null;
            }

            self.files.items[i].start_idx = free_space_idx;
        }
    }

    fn freeSpaceForSize(self: Self, size: u32, from_idx: u32) ?u32 {
        var start_idx: u32 = from_idx;

        // First find the next free block start from `from_idx`.
        while (true) {
            if (start_idx == self.num_blocks) {
                return null;
            }

            if (self.blocks.items[start_idx] == null) {
                const free_space_size = self.entrySizeAtBlock(start_idx);
                if (free_space_size >= size) {
                    break;
                }

                // We can skip forward to the end of this free space block.
                start_idx += free_space_size;
            } else {
                start_idx += 1;
            }
        }

        return start_idx;
    }

    fn entrySizeAtBlock(self: Self, block_idx: u32) u32 {
        var i = block_idx;
        var size: u32 = 0;
        const block_id = self.blocks.items[block_idx];

        while (i < self.num_blocks) {
            if (self.blocks.items[i] != block_id) {
                break;
            }

            size += 1;
            i += 1;
        }

        return size;
    }

    pub fn checksum(self: Self) u64 {
        var sum: u64 = 0;

        for (self.blocks.items, 0..) |block_id, i| {
            sum += i * (block_id orelse 0);
        }

        return sum;
    }

    pub fn print(self: Self) void {
        std.debug.print("Blocks:\n", .{});

        std.debug.print("|", .{});
        for (self.blocks.items) |block_id| {
            if (block_id == null) {
                std.debug.print(".", .{});
            } else {
                std.debug.print("{}", .{block_id.?});
            }

            std.debug.print("|", .{});
        }
        std.debug.print("\n", .{});

        std.debug.print("Files:\n", .{});
        for (self.files.items) |file| {
            std.debug.print("\t{}: {} ({})\n", .{ file.id, file.start_idx, file.size });
        }
    }
};

test Filesystem {
    const input_disk_map = "2333133121414131402";

    const expected_block_ids = [_]?u32{
        0,    0,    null, null,
        null, 1,    1,    1,
        null, null, null, 2,
        null, null, null, 3,
        3,    3,    null, 4,
        4,    null, 5,    5,
        5,    5,    null, 6,
        6,    6,    6,    null,
        7,    7,    7,    null,
        8,    8,    8,    8,
        9,    9,
    };

    const expected_files = [_]Filesystem.File{
        .{ .id = 0, .start_idx = 0, .size = 2 },
        .{ .id = 1, .start_idx = 5, .size = 3 },
        .{ .id = 2, .start_idx = 11, .size = 1 },
        .{ .id = 3, .start_idx = 15, .size = 3 },
        .{ .id = 4, .start_idx = 19, .size = 2 },
        .{ .id = 5, .start_idx = 22, .size = 4 },
        .{ .id = 6, .start_idx = 27, .size = 4 },
        .{ .id = 7, .start_idx = 32, .size = 3 },
        .{ .id = 8, .start_idx = 36, .size = 4 },
        .{ .id = 9, .start_idx = 40, .size = 2 },
    };

    const expected_compacted_block_ids = [_]?u32{
        0,    0,    9,    9,
        8,    1,    1,    1,
        8,    8,    8,    2,
        7,    7,    7,    3,
        3,    3,    6,    4,
        4,    6,    5,    5,
        5,    5,    6,    6,
        null, null, null, null,
        null, null, null, null,
        null, null, null, null,
        null, null,
    };

    const expected_defrag_compacted_block_ids = [_]?u32{
        0,    0,    9,    9,
        2,    1,    1,    1,
        7,    7,    7,    null,
        4,    4,    null, 3,
        3,    3,    null, null,
        null, null, 5,    5,
        5,    5,    null, 6,
        6,    6,    6,    null,
        null, null, null, null,
        8,    8,    8,    8,
        null, null,
    };

    const expected_checksum = 1928;

    var filesystem = Filesystem.init(std.testing.allocator);
    defer filesystem.deinit();

    try filesystem.readDiskMap(input_disk_map);
    try std.testing.expectEqualSlices(?u32, &expected_block_ids, filesystem.blocks.items);
    try std.testing.expectEqualSlices(Filesystem.File, &expected_files, filesystem.files.items);

    try filesystem.compact();
    try std.testing.expectEqualSlices(?u32, &expected_compacted_block_ids, filesystem.blocks.items);

    const actual_checksum = filesystem.checksum();
    try std.testing.expectEqual(expected_checksum, actual_checksum);

    var defrag_fs = Filesystem.init(std.testing.allocator);
    defer defrag_fs.deinit();

    try defrag_fs.readDiskMap(input_disk_map);
    try defrag_fs.defragCompact();
    try std.testing.expectEqualSlices(?u32, &expected_defrag_compacted_block_ids, defrag_fs.blocks.items);
}

test solve {
    const solution = try solve(std.testing.allocator);
    const expected_solution = Solution{
        .compact_checksum = 6430446922192,
        .defrag_compact_checksum = 6460170593016,
    };

    try std.testing.expectEqual(expected_solution, solution);
}
