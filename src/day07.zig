const std = @import("std");
const print = std.debug.print;
const fmt = std.fmt;
const args = @import("lib/args.zig");
const files = @import("lib/files.zig");

fn isEquationValid(operands: []u64, acc: u64, target: u64) bool {
    if (operands.len == 0) {
        return acc == target;
    }
    if (acc > target) {
        return false;
    }
    return isEquationValid(operands[1..], acc * operands[0], target) or
        isEquationValid(operands[1..], acc + operands[0], target);
}

fn concatIntegers(a: u64, b: u64) u64 {
    return (a * std.math.pow(u64, 10, std.math.log10(b) + 1)) + b;
}

fn isEquationValidPart2(operands: []u64, acc: u64, target: u64) bool {
    if (operands.len == 0) {
        return acc == target;
    }
    if (acc > target) {
        return false;
    }
    return isEquationValidPart2(operands[1..], acc * operands[0], target) or
        isEquationValidPart2(operands[1..], concatIntegers(acc, operands[0]), target) or
        isEquationValidPart2(operands[1..], acc + operands[0], target);
}

// equationValue takes an equation in string
// form and returns its calibration value
// if it can be made valid, otherwise, it
// returns null.
fn equationValue(buf: []u8) !?u64 {
    var target: u64 = undefined;
    var operands_buf: [16]u64 = undefined;
    var operands_count: usize = 0;

    var ptr: usize = 0;
    while (buf[ptr] != ':') : (ptr += 1) {}
    target = try fmt.parseUnsigned(u64, buf[0..ptr], 10);

    // Skip colon and space.
    ptr += 2;
    while (ptr < buf.len) {
        defer operands_count += 1;
        const start = ptr;
        while (ptr < buf.len and buf[ptr] != ' ') : (ptr += 1) {}
        operands_buf[operands_count] = try fmt.parseUnsigned(u64, buf[start..ptr], 10);
        ptr += 1; // Skip the space.
    }
    return if (isEquationValidPart2(operands_buf[0..operands_count], 0, target)) target else 0;
}

pub fn main() !void {
    const input_path = args.getFirstArg();
    const input = try files.openForReading(input_path);
    defer input.close();

    var calibration: u64 = 0;
    var line_buf: [64]u8 = undefined;
    while (files.readLine(input, &line_buf)) |line| {
        calibration += (try equationValue(line)) orelse 0;
    } else |err| {
        print("done reading input file with error: {any}\n", .{err});
    }

    print("Calibration value: {d}\n", .{calibration});
}
