const std = @import("std");
const print = std.debug.print;
const process = std.process;
const fmt = std.fmt;
const args = @import("lib/args.zig");
const files = @import("lib/files.zig");

const Phase = enum {
    start,
    mul,
    first,
    second,
};

const State = struct {
    prev: u8 = 0,
    phase: Phase = .start,
    num1: [3]u8 = undefined,
    num1_len: u8 = 0,
    num2: [3]u8 = undefined,
    num2_len: u8 = 0,

    // The accumulator of all mul operations we've seen.
    total: u64 = 0,

    // restart clear all fields except the running total.
    fn restart(self: *State) void {
        self.phase = .start;
        self.prev = 0;
        self.num1_len = 0;
        self.num2_len = 0;
    }

    fn processInstruction(self: *State) !void {
        const num1 = try fmt.parseUnsigned(u32, self.num1[0..self.num1_len], 10);
        const num2 = try fmt.parseUnsigned(u32, self.num2[0..self.num2_len], 10);

        self.total += num1 * num2;
        self.restart();
    }

    fn advance(self: *State, next: u8) !void {
        defer self.prev = next;

        switch (self.phase) {
            .start => {
                if (next == 'm') {
                    self.phase = .mul;
                }
            },
            .mul => {
                switch (self.prev) {
                    'm' => {
                        if (next != 'u') {
                            self.restart();
                        }
                    },
                    'u' => {
                        if (next != 'l') {
                            self.restart();
                        }
                    },
                    'l' => {
                        if (next != '(') {
                            self.restart();
                        }
                    },
                    '(' => {
                        if (next < '0' or next > '9') {
                            self.restart();
                        } else {
                            self.num1[0] = next;
                            self.num1_len = 1;
                            self.phase = .first;
                        }
                    },
                    else => unreachable,
                }
            },
            .first => {
                if (next == ',') {
                    self.phase = .second;
                } else if (next >= '0' and next <= '9') {
                    if (self.num1_len == 3) {
                        self.restart();
                    } else {
                        self.num1[self.num1_len] = next;
                        self.num1_len += 1;
                    }
                } else {
                    self.restart();
                }
            },
            .second => {
                if (next == ')') {
                    if (self.num2_len == 0) {
                        self.restart();
                    } else {
                        try self.processInstruction();
                    }
                } else if (next >= '0' and next <= '9') {
                    if (self.num2_len == 3) {
                        self.restart();
                    } else {
                        self.num2[self.num2_len] = next;
                        self.num2_len += 1;
                    }
                } else {
                    self.restart();
                }
            },
        }
    }
};

pub fn main() !void {
    const input_path = args.getFirstArg();
    const input = try files.openForReading(input_path);
    defer input.close();

    var line_buf: [4096]u8 = undefined;
    var state = State{};
    while (files.readLine(input, &line_buf)) |line| {
        for (line) |char| {
            try state.advance(char);
        }
    } else |err| {
        print("Done parsing: {any}\n", .{err});
    }

    print("Total: {d}\n", .{state.total});
}
