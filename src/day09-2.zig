const std = @import("std");
const print = std.debug.print;
const args = @import("lib/args.zig");
const files = @import("lib/files.zig");

inline fn normalize(c: u8) u8 {
    return c - '0';
}

const EntryType = enum {
    File,
    EmptyRegion,
};

const File = struct {
    id: usize,
    idx: usize,
    size: usize,
    relocated: bool = false,
};

const EmptyRegion = struct {
    idx: usize,
    size: usize,
    insertions: [10]File = undefined,
    insertions_pos: usize = 0,
    insertions_size: usize = 0,

    fn actualSize(self: *EmptyRegion) usize {
        return self.size - self.insertions_size;
    }

    fn addToInsertions(self: *EmptyRegion, f: File) void {
        self.insertions[self.insertions_pos] = f;
        self.insertions_pos += 1;
        self.insertions_size += f.size;
    }
};

const Entry = union(EntryType) {
    File: File,
    EmptyRegion: EmptyRegion,
};

const EntryIterator = struct {
    pos: usize = 0,
    entries: std.ArrayList(Entry),

    // peek gets the entry at pos without
    // moving it.
    fn peek(self: *EntryIterator) ?Entry {
        if (self.pos >= self.entries.items.len) {
            return null;
        }
        return self.entries.items[self.pos];
    }

    // shift gets the entry at pos and moves pos.
    fn shift(self: *EntryIterator) !void {
        if (self.pos >= self.entries.items.len) {
            return error.ShiftedEmptyIterator;
        }
        self.pos += 1;
    }

    // add an entry where it's supposed to go, depending on its index.
    fn addOrdered(self: *EntryIterator, e: Entry) !void {
        if (e == EntryType.File) {
            return error.CannotIterateOverFiles;
        }
        var idx: usize = self.pos;
        while (e.EmptyRegion.idx > self.entries.items[idx].EmptyRegion.idx) : (idx += 1) {}
        try self.entries.insert(idx, e);
    }
};

fn entryFromIdx(dense: []u8, idx: usize) Entry {
    if (idx % 2 == 0) {
        return Entry{ .File = File{
            .id = idx / 2,
            .idx = idx,
            .size = normalize(dense[idx]),
        } };
    }
    return Entry{ .EmptyRegion = EmptyRegion{
        .idx = idx,
        .size = normalize(dense[idx]),
    } };
}

pub fn main() !void {
    const input_path = args.getFirstArg();
    const input = try files.openForReading(input_path);
    defer input.close();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var line_buf: [20000]u8 = undefined;
    const dense = try files.readLine(input, &line_buf);

    // Only empty spaces will be stored here.
    var entries_by_size: [10]EntryIterator = undefined;
    for (0..10) |i| {
        entries_by_size[i].pos = 0;
        entries_by_size[i].entries = try std.ArrayList(Entry).initCapacity(allocator, 20000);
    }

    var fs: [20000]Entry = undefined;
    for (0..dense.len) |i| {
        const entry = entryFromIdx(dense, i);
        fs[i] = entry;
        if (entry == EntryType.EmptyRegion) {
            try entries_by_size[entry.EmptyRegion.size].entries.append(entry);
        }
    }

    // Try to move files to the left.
    var i: usize = dense.len + 1;
    while (i > 0) {
        i -= 2;
        const entry = fs[i];

        // Try to find a spot that fits it.
        var min_idx: usize = 20000;
        var chosen_slot: ?EmptyRegion = null;
        for (entry.File.size..10) |s| {
            if (entries_by_size[s].peek()) |cs| {
                if (chosen_slot == null or cs.EmptyRegion.idx < min_idx) {
                    chosen_slot = cs.EmptyRegion;
                    min_idx = cs.EmptyRegion.idx;
                }
            }
        }
        if (chosen_slot == null or chosen_slot.?.idx > entry.File.idx) {
            continue;
        }

        try entries_by_size[chosen_slot.?.actualSize()].shift();
        // If there's a spot, mark it as relocated.
        fs[i].File.relocated = true;
        // Add the file to the insertions.
        chosen_slot.?.addToInsertions(entry.File);
        fs[chosen_slot.?.idx] = Entry{ .EmptyRegion = chosen_slot.? };

        // if the selected empty region has slots left, update it an re-insert it.
        if (chosen_slot.?.actualSize() > 0) {
            try entries_by_size[chosen_slot.?.actualSize()].addOrdered(fs[chosen_slot.?.idx]);
        }
    }

    // Calculate checksum.
    var fsIdx: usize = 0;
    var checksum: u128 = 0;
    for (0..dense.len) |di| {
        switch (fs[di]) {
            EntryType.File => |file| {
                if (file.relocated) {
                    // for (0..file.size) |_| {
                    //     print(".", .{});
                    // }
                    fsIdx += file.size;
                    continue;
                }
                for (0..file.size) |_| {
                    // print("{d}", .{file.id});
                    checksum += fsIdx * file.id;
                    fsIdx += 1;
                }
            },
            EntryType.EmptyRegion => |empty| {
                for (0..empty.insertions_pos) |ins_i| {
                    const f = empty.insertions[ins_i];
                    for (0..f.size) |_| {
                        // print("{d}", .{f.id});
                        checksum += fsIdx * f.id;
                        fsIdx += 1;
                    }
                }
                fsIdx += empty.size - empty.insertions_size;
                // for (0..(empty.size - empty.insertions_size)) |_| {
                //     print(".", .{});
                // }
            },
        }
    }
    print("\n", .{});

    print("Checksum: {any}\n", .{checksum});
}
