const std = @import("std");
const print = std.debug.print;
const process = std.process;
const fmt = std.fmt;
const files = @import("lib/files.zig");
const args = @import("lib/args.zig");

fn solve(search: *[141][141]u8, size: u8) u32 {
    var total: u32 = 0;
    for (1..size - 1) |l| {
        for (1..size - 1) |c| {
            if (search[l][c] != 'A') {
                continue;
            }
            if (((search[l - 1][c - 1] == 'S' and search[l + 1][c + 1] == 'M') or
                (search[l - 1][c - 1] == 'M' and search[l + 1][c + 1] == 'S')) and
                ((search[l + 1][c - 1] == 'S' and search[l - 1][c + 1] == 'M') or
                (search[l + 1][c - 1] == 'M' and search[l - 1][c + 1] == 'S')))
            {
                total += 1;
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
    // NOTE: We need one more character than the max line length
    // Because we're reading directly to the buffer and not using the
    // result.
    var word_search: [141][141]u8 = undefined;
    for (0..input_size) |l| {
        _ = files.readLine(input, &word_search[l]) catch {};
    }
    const total = solve(&word_search, input_size);
    print("Total X-MAS: {d}\n", .{total});
}
