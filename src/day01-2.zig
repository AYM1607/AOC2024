const std = @import("std");
const print = std.debug.print;
const process = std.process;
const fs = std.fs;

pub fn main() !void {
    var args = process.args();
    defer args.deinit();

    // Skip the first argument since it's the name of the program.
    _ = args.skip();

    const rel_input_path: [:0]const u8 = args.next() orelse {
        print("Provide the input file path\n", .{});
        process.exit(1);
    };

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var abs_input_path_buff: [fs.max_path_bytes]u8 = undefined;
    const input_path = try fs.realpath(rel_input_path, &abs_input_path_buff);
    print("Input file path: {s}\n", .{input_path});

    const input_file = try fs.openFileAbsolute(input_path, fs.File.OpenFlags{ .mode = .read_only });
    defer input_file.close();

    var item_count: u16 = 0;
    var l_list: [1000]i32 = undefined;
    var r_list: [1000]i32 = undefined;

    const input_reader = input_file.reader();
    var line_buf: [64]u8 = undefined;
    while (try input_reader.readUntilDelimiterOrEof(&line_buf, ' ')) |first_str| {
        defer item_count += 1;
        l_list[item_count] = try std.fmt.parseInt(i32, first_str, 10);

        const second_str = try input_reader.readUntilDelimiterOrEof(&line_buf, '\n');
        r_list[item_count] = try std.fmt.parseInt(i32, std.mem.trim(u8, second_str.?, " "), 10);
    }

    var r_hash = std.AutoHashMap(i32, i32).init(allocator);
    defer r_hash.deinit();

    for (0..item_count) |i| {
        const num = r_list[i];
        try r_hash.put(num, 1 + (r_hash.get(num) orelse 0));
    }

    var similarity: i64 = 0;
    for (0..item_count) |i| {
        const num = l_list[i];
        similarity += num * (r_hash.get(num) orelse 0);
    }
    print("The answer is: {d}\n", .{similarity});
}
