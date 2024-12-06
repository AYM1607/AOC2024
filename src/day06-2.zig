const std = @import("std");
const fmt = std.fmt;
const print = std.debug.print;
const args = @import("lib/args.zig");
const files = @import("lib/files.zig");

// NOTE: This should be type not state lol.
// Working without LSP so will leave as-is.
const TileState = enum {
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

const one: u4 = 1;
const Tile = struct {
    state: TileState = .Unvisited,
    directions: u4 = 0,

    fn hasDirection(self: *Tile, direction: Direction) bool {
        return (self.directions & (one << @intFromEnum(direction))) != 0;
    }

    fn setDirection(self: *Tile, direction: Direction) void {
        self.directions |= one << @intFromEnum(direction);
    }
};

const Guard = struct {
    direction: Direction = .Up,
    x: usize,
    y: usize,

    fn rotate(self: *Guard) void {
        self.direction = @enumFromInt(@addWithOverflow(1, @intFromEnum(self.direction))[0]);
    }

    fn wouldWalkExit(self: *Guard, size: usize) bool {
        return switch (self.direction) {
            .Up => self.y == 0,
            .Right => self.x == size - 1,
            .Down => self.y == size - 1,
            .Left => self.x == 0,
        };
    }

    fn walk(self: *Guard, map: *[130][130]Tile, size: usize) ?bool {
        if (self.wouldWalkExit(size)) {
            return null;
        }
        var new_x = self.x;
        var new_y = self.y;
        switch (self.direction) {
            .Up => {
                new_y -= 1;
            },
            .Right => {
                new_x += 1;
            },
            .Down => {
                new_y += 1;
            },
            .Left => {
                new_x -= 1;
            },
        }

        switch (map[new_y][new_x].state) {
            .Unvisited => {
                self.x = new_x;
                self.y = new_y;
                map[new_y][new_x].state = .Visited;
                map[new_y][new_x].setDirection(self.direction);
                return false;
            },
            .Visited => {
                if (map[new_y][new_x].hasDirection(self.direction)) {
                    return true;
                }
                self.x = new_x;
                self.y = new_y;
                return false;
            },
            .Obstacle => {
                // This will overflow the stack if the guard is surrounded
                // by obstacles, should not happen for the inputs we have.
                self.rotate();
                if (map[self.y][self.x].hasDirection(self.direction)) {
                    return true;
                }
                return self.walk(map, size);
            },
        }
        unreachable;
    }
};

// walks the guard along the map until they either exit
// or a loop is found. Returns
fn mapHasLoop(map: *[130][130]Tile, size: usize, guard: *Guard) bool {
    while (guard.walk(map, size)) |hasLoop| {
        if (hasLoop) {
            return true;
        }
    }
    return false;
}

pub fn main() !void {
    const input_path = args.getFirstArg();
    const input = try files.openForReading(input_path);

    var map: [130][130]Tile = .{.{.{}} ** 130} ** 130;
    var map_size: usize = undefined;

    var line_buf: [131]u8 = undefined;
    var guard = Guard{
        .x = undefined,
        .y = undefined,
    };
    var y: usize = 0;
    var loops: usize = 0;
    while (files.readLine(input, &line_buf)) |line| {
        defer y += 1;
        map_size = line.len;
        for (line, 0..) |tile, x| {
            if (tile == '^') {
                guard.x = x;
                guard.y = y;
                map[y][x].state = .Visited;
                map[y][x].setDirection(.Up);
            } else if (tile == '#') {
                map[y][x].state = .Obstacle;
            }
        }
    } else |err| {
        print("Done reading input with error: {any}\n", .{err});
    }

    for (0..map_size) |yi| {
        for (0..map_size) |xi| {
            // Can't place obstacle on the initial guard position.
            if (yi == guard.y and xi == guard.x) {
                continue;
            }
            // Sligth optimization.
            if (map[yi][xi].state == .Obstacle) {
                continue;
            }
            var map_copy = map;
            map_copy[yi][xi].state = .Obstacle;
            var guard_copy = guard;
            loops += if (mapHasLoop(&map_copy, map_size, &guard_copy)) 1 else 0;
        }
    }

    print("Loops: {d}\n", .{loops});
}
