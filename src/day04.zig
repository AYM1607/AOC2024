const std = @import("std");
const print = std.debug.print;
const process = std.process;
const fmt = std.fmt;
const files = @import("lib/files.zig");
const args = @import("lib/args.zig");

const Direction = enum(u3) {
    LD, // \
    UD, // |
    RD, // /
    LR, // ->
    RL, // <-
    LU, // /
    DU, // |
    RU, // \
};

const Errors = error{
    NoPreviousCharacter,
};

const one: u8 = 1;

fn setDirection(flags: u8, dir: Direction) u8 {
    return flags | (one << @intFromEnum(dir));
}

fn hasDirection(flags: u8, dir: Direction) bool {
    return (flags & (one << @intFromEnum(dir))) != 0;
}

fn getCharFrom(dir: Direction, search: *[141][141]u8, size: u8, x: usize, y: usize) ?u8 {
    const at_x = switch (dir) {
        .LD => if (x > 0) x - 1 else return null,
        .LR => if (x > 0) x - 1 else return null,
        .LU => if (x > 0) x - 1 else return null,
        .RD => x + 1,
        .RL => x + 1,
        .RU => x + 1,
        else => x,
    };
    const at_y = switch (dir) {
        .LD => if (y > 0) y - 1 else return null,
        .UD => if (y > 0) y - 1 else return null,
        .RD => if (y > 0) y - 1 else return null,
        .LU => y + 1,
        .DU => y + 1,
        .RU => y + 1,
        else => y,
    };
    if (at_x >= size or at_y >= size) {
        return null;
    }
    return search[at_y][at_x];
}

fn prevChar(current: u8) !u8 {
    return switch (current) {
        'S' => 'A',
        'A' => 'M',
        'M' => 'X',
        else => {
            print("Found illegal char {d}\n", .{current});
            return Errors.NoPreviousCharacter;
        },
    };
}

// NOTE: would be nice to be able to pass a slice of slices, but this works.
fn solve(search: *[141][141]u8, state: *[141][141]u8, size: u8, dirs: []const Direction) !u32 {
    var total: u32 = 0;
    for (0..size) |l| {
        for (0..size) |c| {
            if (search[l][c] == 'X') {
                continue;
            }
            for (dirs) |dir| {
                if (getCharFrom(dir, search, size, c, l)) |actualPrevChar| {
                    if (getCharFrom(dir, state, size, c, l)) |prevState| {
                        if (try prevChar(search[l][c]) == actualPrevChar and (actualPrevChar == 'X' or hasDirection(prevState, dir))) {
                            state[l][c] = setDirection(state[l][c], dir);
                        }
                    }
                }
            }
            if (search[l][c] == 'S') {
                total += @popCount(state[l][c]);
            }
        }
    }
    return total;
}

// TODO: Find a nice way of abstracting this.
fn solveReverse(search: *[141][141]u8, state: *[141][141]u8, size: u8, dirs: []const Direction) !u32 {
    var total: u32 = 0;
    var l: usize = size;
    while (l > 0) {
        l -= 1;
        var c: usize = size;
        while (c > 0) {
            c -= 1;
            if (search[l][c] == 'X') {
                continue;
            }
            for (dirs) |dir| {
                if (getCharFrom(dir, search, size, c, l)) |actualPrevChar| {
                    if (getCharFrom(dir, state, size, c, l)) |prevState| {
                        if (try prevChar(search[l][c]) == actualPrevChar and ((actualPrevChar == 'X' and search[l][c] == 'M') or hasDirection(prevState, dir))) {
                            state[l][c] = setDirection(state[l][c], dir);
                        }
                    }
                }
            }
            if (search[l][c] == 'S') {
                total += @popCount(state[l][c] & 0b11110000);
            }
        }
    }
    return total;
}

pub fn main() !void {
    var margs = process.args();
    defer margs.deinit();
    _ = margs.skip();

    const input_path = margs.next() orelse {
        print("First argument should be the input file\n", .{});
        return args.ArgError.MissingArguments;
    };
    // Only read one dimension, the input is a square matrix.
    const input_size_str = margs.next() orelse {
        print("Second argument should be the input size\n", .{});
        return args.ArgError.MissingArguments;
    };
    const input_size = try fmt.parseUnsigned(u8, input_size_str, 10);
    const input = try files.openForReading(input_path);

    // 140 is the size of the max input.
    // NOTE: I could use a single matrix of u16 and store the state
    // on the MSB, this is fine though.
    var word_search: [141][141]u8 = undefined;
    var state: [141][141]u8 = undefined;
    for (0..input_size) |l| {
        _ = files.readLine(input, &word_search[l]) catch {};
        @memset(&state[l], 0);
    }
    const directions = [8]Direction{ .LD, .UD, .RD, .LR, .RL, .LU, .DU, .RU };
    var total: u32 = try solve(&word_search, &state, input_size, directions[0..4]);
    total += try solveReverse(&word_search, &state, input_size, directions[4..]);
    print("Total XMAS: {d}\n", .{total});
}
