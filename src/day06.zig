const std = @import("std");
const fmt = std.fmt;
const print = std.debug.print;
const args = @import("lib/args.zig");
const files = @import("lib/files.zig");

const Tile = enum {
    Unvisited,
    Visited,
    Obstacle,
};

const Direction = enum(u2) {
    Up,
    Right,
    Down,
    Left,
};

const Guard = struct {
    direction: Direction = .Up,
    x: usize,
    y: usize,

    fn rotate(self: *Guard) void {
        self.direction = @enumFromInt(@addWithOverflow(1, @intFromEnum(self.direction))[0]);
    }

    fn walk(self: *Guard, map: *[130][130]Tile, size: usize) ?bool {
        var new_x = self.x;
        var new_y = self.y;
        switch (self.direction) {
            .Up => {
                if (self.y == 0) {
                    return null;
                }
                new_y -= 1;
            },
            .Right => {
                if (self.x == size - 1) {
                    return null;
                }
                new_x += 1;
            },
            .Down => {
                if (self.y == size - 1) {
                    return null;
                }
                new_y += 1;
            },
            .Left => {
                if (self.x == 0) {
                    return null;
                }
                new_x -= 1;
            },
        }

        switch (map[new_y][new_x]) {
            .Unvisited => {
                self.x = new_x;
                self.y = new_y;
                map[new_y][new_x] = .Visited;
                return true;
            },
            .Visited => {
                self.x = new_x;
                self.y = new_y;
                return false;
            },
            .Obstacle => {
                // This will overflow the stack if the guard is surrounded
                // by obstacles, should not happen for the inputs we have.
                self.rotate();
                return self.walk(map, size);
            },
        }
        unreachable;
    }
};

fn printMap(map: [130][130]Tile, size: usize) void {
    for (0..size) |y| {
        for (0..size) |x| {
            const print_char: u8 = switch (map[y][x]) {
                .Visited => 'X',
                .Unvisited => '.',
                .Obstacle => '#',
            };
            print("{c}", .{print_char});
        }
        print("\n", .{});
    }
}

// walkMap walks the guard along the map until they exit, and returns
// the number of unique, unvisited tiles they walked along.
fn walkMap(map: *[130][130]Tile, size: usize, guard: *Guard) usize {
    var unique_visited_tiles: usize = 0;
    while (guard.walk(map, size)) |new_tile| {
        if (new_tile) {
            unique_visited_tiles += 1;
        }
    }
    return unique_visited_tiles;
}

pub fn main() !void {
    const input_path = args.getFirstArg();
    const input = try files.openForReading(input_path);

    var map: [130][130]Tile = .{.{.Unvisited} ** 130} ** 130;
    var map_size: usize = undefined;

    var line_buf: [131]u8 = undefined;
    var guard = Guard{
        .x = undefined,
        .y = undefined,
    };
    var y: usize = 0;
    var visited_tiles: usize = 0;
    while (files.readLine(input, &line_buf)) |line| {
        defer y += 1;
        map_size = line.len;
        for (line, 0..) |tile, x| {
            if (tile == '^') {
                guard.x = x;
                guard.y = y;
                map[y][x] = .Visited;
                visited_tiles += 1;
            } else if (tile == '#') {
                map[y][x] = .Obstacle;
            }
        }
    } else |err| {
        print("Done reading input with error: {any}\n", .{err});
    }

    visited_tiles += walkMap(&map, map_size, &guard);
    printMap(map, map_size);
    print("Visited tiles: {d}\n", .{visited_tiles});
}
