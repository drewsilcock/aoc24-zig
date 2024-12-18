const std = @import("std");

const Solution = struct {
    file_checksum: u32,
};

pub fn run(allocator: std.mem.Allocator) !void {
    const solution = try solve(allocator);
    std.debug.print("File checksum: {}\n", .{solution.file_checksum});
}

fn solve(allocator: std.mem.Allocator) !Solution {
    _ = allocator; // autofix
    //
}

const Block = struct {
    // If id == null, block is free.
    id: ?u8,
};

const Filesystem = struct {
    const Self = @This();

    const BlockList = std.DoublyLinkedList(Block);

    blocks: BlockList,
    first_free_block: ?*BlockList.Node,
    last_file_block: ?*BlockList.Node,
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
            const next_node = node.next;
            self.allocator.free(node);
            current_node = next_node;
        }

        self.first_free_block = null;
        self.last_file_block = null;
        self.blocks = .{};
    }

    pub fn readDiskMap(self: *Self, disk_map: []const u8) !void {
        var is_file_block = true;
        var current_block_id: u32 = 0;

        for (disk_map) |map_entry| {
            const num_blocks = try std.fmt.charToDigit(map_entry, 10);

            for (0..num_blocks) |_| {
                const node = try self.allocator.create(BlockList.Node);
                node.data.id = if (is_file_block) current_block_id else null;
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
            self.first_free_block = null;
            var current_block = free_block;
            while (current_block.next != null) {
                if (current_block.data == null) {
                    self.first_free_block = current_block;
                    break;
                }

                current_block = current_block.next;
            }

            // Find the new last file block by traversing backwards from the old one.
            self.last_file_block = null;
            current_block = file_block;
            while (current_block.prev != null) {
                if (current_block.data != null) {
                    self.last_file_block = current_block;
                    break;
                }

                current_block = current_block.prev;
            }
        }
    }

    pub fn checksum(self: Self) u32 {
        var sum: u32 = 0;
        var i = 0;
        var current_node = self.blocks.first;

        while (current_node) |node| {
            sum += i * node.data.id orelse 0;
            i += 1;
            current_node = node.next;
        }

        return sum;
    }
};

test Filesystem {
    const input_disk_map = "2333133121414131402";

    const expected_block_ids = [_]?u8{
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

    const expected_compacted_block_ids = [_]?u8{
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

    const expected_checksum = 1928;

    var filesystem = Filesystem.init(std.testing.allocator);
    defer filesystem.deinit();

    try filesystem.readDiskMap(input_disk_map);

    var current_node = filesystem.blocks.first;
    var i: u32 = 0;
    while (current_node) |node| : (i += 1) {
        const expected_id = expected_block_ids[i];
        const actual_id = node.data.id;
        std.testing.expectEqual(expected_id, actual_id);

        current_node = node.next;
    }

    try filesystem.compact();

    current_node = filesystem.blocks.first;
    i = 0;
    while (current_node) |node| : (i += 1) {
        const expected_id = expected_compacted_block_ids[i];
        const actual_id = node.data.id;
        std.testing.expectEqual(expected_id, actual_id);

        current_node = node.next;
    }

    const actual_checksum = filesystem.checksum();
    std.testing.expectEqual(expected_checksum, actual_checksum);
}
