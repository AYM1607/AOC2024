const std = @import("std");
const print = std.debug.print;
const fmt = std.fmt;
const args = @import("lib/args.zig");
const files = @import("lib/files.zig");

const one: u128 = 1;

const LineType = enum {
    Rule,
    Separator,
    Update,
};

fn getLineType(line: []u8) LineType {
    if (line.len < 3) {
        return .Separator;
    }
    return switch (line[2]) {
        '|' => .Rule,
        ',' => .Update,
        else => unreachable,
    };
}

fn storeRule(rules: *[100]u128, rule: []u8) !void {
    if (rule.len != 5) {
        return error.InvalidRule;
    }
    const before: u8 = (10 * (rule[0] - '0')) + (rule[1] - '0');
    // It's okay to truncate, the max for this is 99.
    const after: u7 = @truncate((10 * (rule[3] - '0')) + (rule[4] - '0'));
    rules[before] |= one << after;
}

inline fn isPageSetInRule(rule: u128, page: u8) bool {
    // It's okay to truncate, the max for a page is 99.
    return (one << @truncate(page) & rule) != 0;
}

fn parseUpdate(line: []u8, update_buf: *[32]u8) ![]u8 {
    var item_count: u8 = 0;
    var ptr: u8 = 0;
    while (ptr < line.len) {
        defer item_count += 1;
        const start = ptr;
        while (ptr < line.len and line[ptr] != ',') : (ptr += 1) {}
        // Could parse by accesing the integers directly...
        update_buf[item_count] = try std.fmt.parseUnsigned(u8, line[start..ptr], 10);
        // Skip the comma.
        ptr += 1;
    }
    return update_buf[0..item_count];
}

fn isUpdateValid(update: []u8, rules: [100]u128) bool {
    var positions = [_]?usize{null} ** 100;
    for (update, 0..) |page, i| {
        positions[page] = i;
    }
    for (update, 0..) |page, i| {
        for (0..100) |pageAfter| {
            if (!isPageSetInRule(rules[page], @truncate(pageAfter)) or
                positions[pageAfter] == null or
                positions[pageAfter].? > i)
            {
                continue;
            }
            return false;
        }
    }
    return true;
}

// getFilteredRulesCount gets the number of rules for a given page
// that apply to this update.
fn getFilteredRulesCount(page: u8, update: []u8, rule: u128) u8 {
    var mask: u128 = 0;
    for (update) |p| {
        // Not necessary, a rule can't point to itself, but might as well...
        if (p == page) {
            continue;
        }
        mask |= @as(u128, 1) << @truncate(p);
    }
    return @popCount(rule & mask);
}

fn getSortedUpdate(update: []u8, rules: [100]u128, buf: *[32]u8) []u8 {
    const last_index = update.len - 1;
    for (update) |page| {
        buf[last_index - getFilteredRulesCount(page, update, rules[page])] = page;
    }
    return buf[0..update.len];
}

pub fn main() !void {
    const input_path = args.getFirstArg();
    const input = try files.openForReading(input_path);
    defer input.close();

    // The index is the "page that should go before" and each set bit on the
    // value is the "page that should go after". This is a tradeoff to use
    // less memory, and even though runtime is predictable, in practice it's
    // probably slower than using a hashmap.
    var rules: [100]u128 = [_]u128{0} ** 100;

    var line_buf: [100]u8 = undefined;
    while (files.readLine(input, &line_buf)) |line| {
        if (getLineType(line) == .Separator) {
            break;
        }
        try storeRule(&rules, line);
    } else |err| {
        print("Found end of file before finding updates: {any}\n", .{err});
        return error.NoUpdates;
    }

    var update_buf: [32]u8 = undefined;
    var sorted_update_buf: [32]u8 = undefined;
    var total: u16 = 0;
    while (files.readLine(input, &line_buf)) |line| {
        if (getLineType(line) != .Update) {
            return error.UnexpectedLine;
        }
        const update = try parseUpdate(line, &update_buf);
        if (!isUpdateValid(update, rules)) {
            // Uncomment for the part1 solution.
            // continue;
            const sorted_update = getSortedUpdate(update, rules, &sorted_update_buf);
            total += sorted_update[sorted_update.len / 2];
        } else {
            continue;
            // Uncomment for the part1 solution.
            // total += update[update.len / 2];
        }
    } else |err| {
        print("Done processing input: {any}\n", .{err});
    }
    print("Total: {d}\n", .{total});
}
