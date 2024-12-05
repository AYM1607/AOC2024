const std = @import("std");
const process = std.process;
const print = std.debug.print;

pub const ArgError = error{
    MissingArguments,
};

// TODO: This erroring out would be a better API.
pub fn getFirstArg() [:0]const u8 {
    var args = process.args();
    defer args.deinit();

    // Skip the first argument since it's the name of the program.
    _ = args.skip();

    return args.next() orelse {
        print("Provide at least one input\n", .{});
        process.exit(1);
    };
}
