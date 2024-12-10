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

const FSPtr = struct {
    entry: FSEntry,
    pos: usize = 0,
    idx: usize,
};

fn fsPtrFromIdx(dense: []u8, idx: usize) FSPtr {
    return FSPtr{
        .idx = idx,
        .pos = 0,
        .entry = FSEntry{
            .size = normalize(dense[idx]),
            .typ = if (idx % 2 == 0) .File else .EmptySpace,
            .id = idx / 2,
        },
    };
}

pub fn main() !void {
    const input_path = args.getFirstArg();
    const input = try files.openForReading(input_path);
    defer input.close();

    var line_buf: [20000]u8 = undefined;
    const dense = try files.readLine(input, &line_buf);
    var left = fsPtrFromIdx(dense, 0);
    var right = fsPtrFromIdx(dense, dense.len - 1);
    right.pos = right.entry.size;

    var checksum: u128 = 0;
    var fsIdx: usize = 0;
    while (true) {
        if (left.idx > right.idx) {
            break;
        }
        // Make sure that whatever we removed from right (if any)
        // is honored.
        if (left.idx == right.idx) {
            left.entry.size = right.pos;
        }

        if (left.pos >= left.entry.size) {
            left = fsPtrFromIdx(dense, left.idx + 1);
            continue;
        }
        if (right.pos == 0) {
            right = fsPtrFromIdx(dense, right.idx - 2);
            right.pos = right.entry.size;
            continue;
        }
        switch (left.entry.typ) {
            .File => {
                print("{d}", .{left.entry.id});
                checksum += fsIdx * left.entry.id;
                fsIdx += 1;
                left.pos += 1;
            },
            .EmptySpace => {
                print("{d}", .{right.entry.id});
                checksum += fsIdx * right.entry.id;
                left.pos += 1;
                right.pos -= 1;
                fsIdx += 1;
            },
        }
    }
    print("\n", .{});

    print("Checksum: {any}\n", .{checksum});
}
