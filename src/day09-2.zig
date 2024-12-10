const std = @import("std");
const print = std.debug.print;
const args = @import("lib/args.zig");
const files = @import("lib/files.zig");

inline fn normalize(c: u8) u8 {
    return c - '0';
}

const FSEntryType = enum {
    File,
    EmptySpace,
};

const FSEntry = struct {
    size: usize,
    typ: FSEntryType,
    // Only appicable to Files, may be best
    // expressed as a union?
    id: usize,
};

// Could use an array list, this struct seems better since the max size is known.
// Would be interesting to analyse the implications.
const FSEntryIterator = struct {
    size: usize = 0,
    ptr: usize = 0,
    items: [20000]FSEntry = undefined,

    fn add(self: *FSEntryIterator, e: FSEntry) void {
        self.items[self.size] = e;
        self.size += 1;
    }

    fn peek(self: *FSEntryIterator) ?FSEntry {
        if (self.ptr == self.size) {
            return null;
        }
        return self.items[self.ptr];
    }

    fn next(self: *FSEntryIterator) ?FSEntry {
        if (self.ptr == self.size) {
            return null;
        }
        defer self.ptr += 1;
        return self.items[self.ptr];
    }
};

fn fsEntryFromIdx(dense: []u8, relocated: [20000]bool, idx: usize) FSEntry {
    return FSEntry{
        .size = normalize(dense[idx]),
        .typ = if (relocated[idx]) .EmptySpace else if (idx % 2 == 0) .File else .EmptySpace,
        .id = idx / 2,
    };
}

pub fn main() !void {
    const input_path = args.getFirstArg();
    const input = try files.openForReading(input_path);
    defer input.close();

    var line_buf: [20000]u8 = undefined;
    const dense = try files.readLine(input, &line_buf);

    var entries_by_size: [10]FSEntryIterator = .{FSEntryIterator{}} ** 10;
    var relocated: [20000]bool = .{false} ** 20000;

    var idx: usize = dense.len - 1;
    while (idx >= 2) : (idx -= 2) {
        const entry = fsEntryFromIdx(dense, relocated, idx);
        entries_by_size[entry.size].add(entry);
    }

    var entry: FSEntry = fsEntryFromIdx(dense, relocated, 0);
    var entry_pos: usize = 0;
    var fsIdx: usize = 0;

    var checksum: u128 = 0;
    idx = 0;
    entries: while (idx < dense.len) {
        if (entry_pos >= entry.size) {
            if (idx == dense.len - 1) {
                break;
            }
            entry = fsEntryFromIdx(dense, relocated, idx + 1);
            idx += 1;
            entry_pos = 0;
            continue;
        }
        switch (entry.typ) {
            .File => {
                print("{d}", .{entry.id});
                checksum += fsIdx * entry.id;
                fsIdx += 1;
                entry_pos += 1;
            },
            .EmptySpace => {
                const remaining_slots = entry.size - entry_pos;
                var size = remaining_slots;

                var largest_id_size: usize = undefined;
                var largest_id: ?usize = null;
                while (size > 0) : (size -= 1) {
                    if (entries_by_size[size].peek()) |e| {
                        if (largest_id == null or e.id > largest_id.?) {
                            largest_id = e.id;
                            largest_id_size = e.size;
                        }
                    }
                }

                size = largest_id_size;
                if (largest_id) |id| {
                    _ = entries_by_size[size].next();
                    for (0..size) |_| {
                        print("{d}", .{id});
                        checksum += fsIdx * id;
                        fsIdx += 1;
                    }
                    relocated[id * 2] = true;
                    entry_pos += size;
                    continue :entries;
                }

                for (0..remaining_slots) |_| {
                    print(".", .{});
                }
                entry_pos += remaining_slots;
                fsIdx += remaining_slots;
            },
        }
    }
    print("\n", .{});

    print("Checksum: {any}\n", .{checksum});
}
