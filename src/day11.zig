const std = @import("std");
const print = std.debug.print;

const ResType = enum {
    Single,
    Pair,
};

const Res = union(ResType) {
    Single: u128,
    Pair: std.meta.Tuple(&.{ u128, u128 }),
};

fn blink(stone: u128) Res {
    if (stone == 0) {
        return Res{ .Single = 1 };
    }
    // return (a * std.math.pow(u64, 10, std.math.log10(b) + 1)) + b;
    const digits = std.math.log10(stone) + 1;
    if (digits % 2 == 0) {
        const left = stone / std.math.pow(u128, 10, digits / 2);
        const right = stone - (left * std.math.pow(u128, 10, digits / 2));
        return Res{ .Pair = .{ left, right } };
    }
    return Res{ .Single = stone * 2024 };
}

fn stonesAfterBlinks(stone: u128, blinks: u8, cache: *[76]std.AutoHashMap(u128, u128)) !u128 {
    if (blinks == 0) {
        return 1;
    }
    if (cache[blinks].get(stone)) |s| {
        return s;
    }
    const res = switch (blink(stone)) {
        ResType.Single => |s| try stonesAfterBlinks(s, blinks - 1, cache),
        ResType.Pair => |p| try stonesAfterBlinks(p[0], blinks - 1, cache) + try stonesAfterBlinks(p[1], blinks - 1, cache),
    };
    try cache[blinks].put(stone, res);
    return res;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const stones: [8]u128 = .{ 64554, 35, 906, 6, 6960985, 5755, 975820, 0 };
    // const stones: [2]u128 = .{ 125, 17 };
    var cache: [76]std.AutoHashMap(u128, u128) = undefined;
    for (0..76) |i| {
        cache[i] = std.AutoHashMap(u128, u128).init(allocator);
    }

    var total: u128 = 0;
    for (0..stones.len) |si| {
        total += try stonesAfterBlinks(stones[si], 75, &cache);
    }
    print("Stones after 75 blinks: {d}\n", .{total});
}
