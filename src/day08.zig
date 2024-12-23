const std = @import("std");
const print = std.debug.print;
const args = @import("lib/args.zig");
const files = @import("lib/files.zig");

const Pos = struct {
    x: isize,
    y: isize,
};

fn normalizeCharacter(c: u8) u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'a'...'z' => c - 'a' + 10,
        'A'...'Z' => c - 'A' + 37,
        else => unreachable,
    };
}

fn getAntinodePos(a: Pos, b: Pos, size: usize) ?Pos {
    var res_x = a.x;
    var res_y = a.y;
    res_x += a.x - b.x;
    res_y += a.y - b.y;
    if (res_x < 0 or
        res_x >= size or
        res_y < 0 or
        res_y >= size)
    {
        return null;
    }
    return Pos{
        .x = res_x,
        .y = res_y,
    };
}

// returns true if the position being set hadn't been set before.
fn setAntinode(antinodes: *[50][50]bool, pos: Pos) bool {
    const x: usize = @bitCast(pos.x);
    const y: usize = @bitCast(pos.y);
    if (antinodes[y][x]) {
        return false;
    }
    antinodes[y][x] = true;
    return true;
}

pub fn main() !void {
    const input_path = args.getFirstArg();
    const input = try files.openForReading(input_path);
    defer input.close();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var antinodes: [50][50]bool = .{.{false} ** 50} ** 50;
    var positions: [64]std.ArrayList(Pos) = undefined;
    for (0..64) |i| {
        positions[i] = std.ArrayList(Pos).init(allocator);
    }

    var line_buf: [51]u8 = undefined;
    var input_size: usize = 0;
    while (files.readLine(input, &line_buf)) |line| {
        defer input_size += 1;
        for (line, 0..) |c, x| {
            if (c == '.') {
                continue;
            }
            try positions[normalizeCharacter(c)].append(Pos{ .x = @bitCast(x), .y = @bitCast(input_size) });
        }
    } else |err| {
        print("done reading input with error: {any}\n", .{err});
    }
    var unique_antinodes: usize = 0;
    for (0..64) |c| {
        for (0..positions[c].items.len) |pos_i| {
            for (pos_i + 1..positions[c].items.len) |mirror_pos_i| {
                const pos = positions[c].items[pos_i];
                const pos_mirror = positions[c].items[mirror_pos_i];
                if (getAntinodePos(pos, pos_mirror, input_size)) |anti_pos| {
                    if (setAntinode(&antinodes, anti_pos)) {
                        unique_antinodes += 1;
                    }
                }
                if (getAntinodePos(pos_mirror, pos, input_size)) |anti_pos| {
                    if (setAntinode(&antinodes, anti_pos)) {
                        unique_antinodes += 1;
                    }
                }
            }
        }
    }
    print("Unique antinodes: {d}\n", .{unique_antinodes});
}
