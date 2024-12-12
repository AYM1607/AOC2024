const std = @import("std");
const print = std.debug.print;
const args = @import("lib/args.zig");
const files = @import("lib/files.zig");

inline fn normalize(c: u8) u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        else => unreachable,
    };
}

fn printMap(m: [60][60]u8, size: usize) void {
    for (0..size) |y| {
        for (0..size) |x| {
            print("{c}", .{m[y][x]});
        }
        print("\n", .{});
    }
}

// This approach does not take into account trails tha bifurcate.
//
// By the problem definition:
//
//   0
//   1
// 43234
// 5   5
// 6   6
// 78987
//
// The example above contains one trilhead with a score of one, but this
// implementation would considerit a a score of 2.
fn updateScores(m: [60][60]u8, s: *[60][60]u16, size: usize, y: usize, x: usize) void {
    if (m[y][x] == '0') {
        s[y][x] += 1;
        return;
    }
    const c = m[y][x];
    if (x > 0 and m[y][x - 1] == c - 1) {
        updateScores(m, s, size, y, x - 1);
    }
    if (x < size - 1 and m[y][x + 1] == c - 1) {
        updateScores(m, s, size, y, x + 1);
    }
    if (y > 0 and m[y - 1][x] == c - 1) {
        updateScores(m, s, size, y - 1, x);
    }
    if (y < size - 1 and m[y + 1][x] == c - 1) {
        updateScores(m, s, size, y + 1, x);
    }
}

pub fn main() !void {
    const input_path = args.getFirstArg();
    const input = try files.openForReading(input_path);

    var map: [60][60]u8 = undefined;
    var scores: [60][60]u16 = .{.{0} ** 60} ** 60;
    var map_size: usize = 0;
    while (files.readLine(input, &map[map_size])) |_| : (map_size += 1) {} else |err| {
        print("done reading input with error: {any}\n", .{err});
    }

    for (0..map_size) |y| {
        for (0..map_size) |x| {
            if (map[y][x] == '9') {
                updateScores(map, &scores, map_size, y, x);
            }
        }
    }

    var score: usize = 0;
    for (0..map_size) |y| {
        for (0..map_size) |x| {
            score += scores[y][x];
        }
    }
    print("Scores: {d}\n", .{score});
}
