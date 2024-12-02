const std = @import("std");
const fs = std.fs;
const File = std.fs.File;

pub fn openForReading(rel_path: []const u8) !File {
    var abs_path_buff: [fs.max_path_bytes]u8 = undefined;
    const abs_path = try fs.realpath(rel_path, &abs_path_buff);
    return try fs.openFileAbsolute(abs_path, File.OpenFlags{ .mode = .read_only });
}

pub fn readLine(file: File, buf: []u8) ![]u8 {
    return try file.reader().readUntilDelimiter(buf, '\n');
}
