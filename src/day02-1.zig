const std = @import("std");
const print = std.debug.print;
const args = @import("lib/args.zig");
const files = @import("lib/files.zig");

fn parseReport(line: []u8, report_buf: *[16]i8) ![]i8 {
    var item_count: u8 = 0;
    var ptr: u8 = 0;
    while (ptr < line.len) {
        defer item_count += 1;
        const start = ptr;
        while (ptr < line.len and line[ptr] != ' ') : (ptr += 1) {}
        report_buf[item_count] = try std.fmt.parseInt(i8, line[start..ptr], 10);
        // Skip the space.
        ptr += 1;
    }
    return report_buf[0..item_count];
}

const Order = enum {
    desc,
    eq,
    asc,
};

fn getOrder(a: i8, b: i8) Order {
    if (a < b) {
        return Order.asc;
    } else if (a > b) {
        return Order.desc;
    }
    return Order.eq;
}

fn isReportSafeSingle(report: []i8) bool {
    if (report.len < 2) {
        return true;
    }

    const expected_order = getOrder(report[0], report[1]);
    for (1..report.len) |i| {
        const order = getOrder(report[i - 1], report[i]);
        if (order != expected_order) {
            return false;
        }
        const variance = @abs(report[i - 1] - report[i]);
        if (variance > 3 or variance < 1) {
            return false;
        }
    }
    return true;
}

fn isReportSafeWhenSkipping(level: usize, report: []i8) bool {
    if (level == 0) {
        return isReportSafeSingle(report[1..report.len]);
    }
    if (level == report.len - 1) {
        return isReportSafeSingle(report[0 .. report.len - 1]);
    }

    const second_index: u8 = if (level == 1) 2 else 1;
    const expected_order = getOrder(report[0], report[second_index]);
    for (1..report.len) |i| {
        if (i == level) {
            continue;
        }
        const prev = if (i - 1 == level) i - 2 else i - 1;
        const order = getOrder(report[prev], report[i]);
        if (order != expected_order) {
            return false;
        }
        const variance = @abs(report[prev] - report[i]);
        if (variance > 3 or variance < 1) {
            return false;
        }
    }
    return true;
}

// TODO: Make this O(n) where n is the number of levels in the report. It's currently O(n^2);
fn isReportSafe(report: []i8) bool {
    var safe_when_skipping = false;
    for (0..report.len) |i| {
        if (isReportSafeWhenSkipping(i, report)) {
            safe_when_skipping = true;
            break;
        }
    }
    return safe_when_skipping or isReportSafeSingle(report);
}

pub fn main() !void {
    const input_path = args.getFirstArg();
    const input = try files.openForReading(input_path);
    defer input.close();

    var line_buf: [32]u8 = undefined;
    var report_buf: [16]i8 = undefined;
    var safe_reports: u16 = 0;
    while (files.readLine(input, &line_buf)) |line| {
        const report = try parseReport(line, &report_buf);
        if (isReportSafe(report)) {
            print("Safe report: {any}\n", .{report});
            safe_reports += 1;
        }
    } else |err| {
        print("Done reading input: {any}\n", .{err});
    }
    print("Safe reports: {d}\n", .{safe_reports});
}
