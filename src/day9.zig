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

    filesystem.deinit();
    try filesystem.readDiskMap(input);
    try filesystem.defragCompact();

    const defrag_compact_checksum = filesystem.checksum();

    return Solution{
        .compact_checksum = compact_checksum,
        .defrag_compact_checksum = defrag_compact_checksum,
    };
}

const Block = struct {
    // If id == null, block is free.
    id: ?u32,
};

const Filesystem = struct {
    const Self = @This();

    const BlockList = std.DoublyLinkedList(Block);
    const Node = BlockList.Node;

    blocks: BlockList,
    first_free_block: ?*Node,
    last_file_block: ?*Node,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .blocks = .{},
            .first_free_block = null,
            .last_file_block = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        var current_node = self.blocks.first;

        while (current_node) |node| {
            current_node = node.next;
            self.allocator.destroy(node);
        }

        self.first_free_block = null;
        self.last_file_block = null;
        self.blocks = .{};
    }

    pub fn readDiskMap(self: *Self, disk_map: []const u8) !void {
        var is_file_block = true;
        var current_block_id: u32 = 0;

        for (disk_map) |map_entry| {
            if (map_entry == '\n') {
                break;
            }

            const num_blocks = try std.fmt.charToDigit(map_entry, 10);

            for (0..num_blocks) |_| {
                const node = try self.allocator.create(Node);
                node.* = .{
                    .data = .{
                        .id = if (is_file_block) current_block_id else null,
                    },
                };
                self.blocks.append(node);

                if (is_file_block) {
                    self.last_file_block = node;
                } else if (self.first_free_block == null) {
                    self.first_free_block = node;
                }
            }

            if (is_file_block) {
                current_block_id += 1;
            }

            is_file_block = !is_file_block;
        }
    }

    pub fn compact(self: *Self) !void {
        if (self.last_file_block == null or self.first_free_block == null) {
            // We've got nothing to rearrange or no space to rearrange it into.
            return;
        }

        while (true) {
            // Rearranging the nodes will never cause either of these to be null if they
            // were not null to start with.
            const free_block = self.first_free_block.?;
            const file_block = self.last_file_block.?;

            if (file_block.next == free_block) {
                // If the first free block is after the last file block, we're done.
                break;
            }

            // Swap the data between the two nodes.
            free_block.data.id = file_block.data.id;
            file_block.data.id = null;

            // Find the new first free block by traversing forwards from the old one.
            self.first_free_block = firstEmptyBlock(free_block);

            // Find the new last file block by traversing backwards from the old one.
            self.last_file_block = lastFileBlock(file_block);
        }
    }

    /// Rearrange the blocks so that all file blocks are contiguous.
    ///
    /// This implementation takes a fairly long time to run for the long puzzle input,
    /// most likely because I'm doing so much iterating through the linked list. To
    /// improve performance, you could keep track of the size of a block within the
    /// block (as well as the ID) and even keep track of where the free spaces are and
    /// how big they are. Due to the disk map having one char for the number of blocks,
    /// you could just have a map containing the first instance of a free space of each
    /// size.
    pub fn defragCompact(self: *Self) !void {
        if (self.last_file_block == null or self.first_free_block == null) {
            // We've got nothing to rearrange or no space to rearrange it into.
            return;
        }

        var current_block_id: u32 = self.last_file_block.?.data.id orelse 0;

        while (current_block_id != 0) {
            var maybe_file_start_block = self.blocks.last;
            while (maybe_file_start_block) |node| {
                if (node.data.id == current_block_id and
                    (node.prev == null or node.prev.?.data.id != current_block_id))
                {
                    break;
                }

                maybe_file_start_block = node.prev;
            }

            const file_start_block = maybe_file_start_block orelse {
                current_block_id -= 1;
                continue;
            };

            const file_block_size = countBlockSize(file_start_block);

            var file_last_block = file_start_block;
            for (0..file_block_size - 1) |_| {
                file_last_block = file_last_block.next.?;
            }

            // Try placing block in any free block with sufficient space. We can't start
            // from the first free block because the first free block may be after the
            // file block.
            var maybe_free_block = self.blocks.first;
            while (maybe_free_block) |maybe_free_node| {
                // If we've got back to the file block, we've tried all previous free blocks.
                if (maybe_free_node == file_start_block) {
                    break;
                }

                if (maybe_free_node.data.id != null or countBlockSize(maybe_free_node) < file_block_size) {
                    // Block is not free or not enough space to move the whole file block here.
                    maybe_free_block = maybe_free_node.next;
                    continue;
                }

                // We found a free block with enough space, so move the whole file block there.
                copyBlocks(maybe_free_node, current_block_id, file_block_size);

                // Now clear out the old file block.
                copyBlocks(file_start_block, null, file_block_size);

                // We may have invalidated first_free_block and last_free_block but we
                // don't use either of those mid-iteration so let's just update them
                // once at the end.
                break;
            }

            current_block_id -= 1;
        }

        // Reset the first free block and last file block to their correct values.
        self.first_free_block = firstEmptyBlock(self.blocks.first.?);
        self.last_file_block = lastFileBlock(self.blocks.last.?);
    }

    fn firstEmptyBlock(from_node: *Node) ?*Node {
        var current_block: ?*Node = from_node;
        while (current_block) |node| {
            if (node.data.id == null) {
                return current_block;
            }

            current_block = node.next;
        }

        return null;
    }

    fn lastFileBlock(from_node: *Node) ?*Node {
        var current_block: ?*Node = from_node;
        while (current_block) |node| {
            if (node.data.id != null) {
                return current_block;
            }

            current_block = node.prev;
        }

        return null;
    }

    fn copyBlocks(dest: *Node, src_block_id: ?u32, size: u32) void {
        var i: u32 = 0;
        var current_node: ?*Node = dest;

        while (current_node) |node| {
            if (i == size) {
                break;
            }

            node.data.id = src_block_id;
            current_node = node.next;
            i += 1;
        }
    }

    fn findFirstBlockWithId(self: Self, block_id: u32) ?*Node {
        // We traverse from end because we are rearranging from back to front, although
        // I don't think it makes masses of difference, it's just a performance thing.
        var current_node = self.last_file_block;
        while (current_node) |node| {
            const prev_node = node.prev;

            if (node.data.id == block_id and
                (prev_node == null or prev_node.?.data.id != block_id))
            {
                return node;
            }

            current_node = prev_node;
        }

        return null;
    }

    fn countBlockSize(start_node: *Node) u32 {
        const node_id = start_node.data.id;
        var current_node: ?*Node = start_node;
        var size: u32 = 0;

        while (current_node) |node| : (size += 1) {
            if (node.data.id != node_id) {
                break;
            }

            current_node = node.next;
        }

        return size;
    }

    pub fn checksum(self: Self) u64 {
        var sum: u64 = 0;
        var i: u32 = 0;
        var current_node = self.blocks.first;

        while (current_node) |node| {
            sum += i * (node.data.id orelse 0);
            i += 1;
            current_node = node.next;
        }

        return sum;
    }

    pub fn print(self: Self) void {
        std.debug.print("|", .{});

        var current_node = self.blocks.first;
        while (current_node) |node| {
            if (node.data.id == null) {
                std.debug.print(".", .{});
            } else {
                std.debug.print("{}", .{node.data.id.?});
            }

            std.debug.print("|", .{});
            current_node = node.next;
        }
        std.debug.print("\n", .{});
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

    var current_node = filesystem.blocks.first;
    var i: u32 = 0;
    while (current_node) |node| : (i += 1) {
        const expected_id = expected_block_ids[i];
        const actual_id = node.data.id;
        try std.testing.expectEqual(expected_id, actual_id);

        current_node = node.next;
    }

    try filesystem.compact();

    current_node = filesystem.blocks.first;
    i = 0;
    while (current_node) |node| : (i += 1) {
        const expected_id = expected_compacted_block_ids[i];
        const actual_id = node.data.id;
        try std.testing.expectEqual(expected_id, actual_id);

        current_node = node.next;
    }

    const actual_checksum = filesystem.checksum();
    try std.testing.expectEqual(expected_checksum, actual_checksum);

    filesystem.deinit();
    // After deinit, filesystem is empty and can be re-used.

    try filesystem.readDiskMap(input_disk_map);
    try filesystem.defragCompact();

    current_node = filesystem.blocks.first;
    i = 0;
    while (current_node) |node| : (i += 1) {
        const expected_id = expected_defrag_compacted_block_ids[i];
        const actual_id = node.data.id;
        try std.testing.expectEqual(expected_id, actual_id);

        current_node = node.next;
    }
}

test solve {
    const solution = try solve(std.testing.allocator);
    const expected_solution = Solution{
        .compact_checksum = 6430446922192,
        .defrag_compact_checksum = 6460170593016,
    };

    try std.testing.expectEqual(expected_solution, solution);
}
