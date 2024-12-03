const std = @import("std");
const print = std.debug.print;
const process = std.process;
const fmt = std.fmt;
const args = @import("lib/args.zig");
const files = @import("lib/files.zig");

// NOTE: These could probably be better defined, the state machine
// reads a little weird because first and second are technically
// a subset of mul.
const Phase = enum {
    start,
    mul,
    do,
    dont,
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

    // Accumulators that never get reset.
    total: u64 = 0,
    mul_enabled: bool = true,

    // restartInstruction clears instruction related fields while keeping
    // the running total and the mul_enabled state.
    fn restartInstruction(self: *State, phase: Phase) void {
        self.phase = phase;
        self.prev = 0;
        self.num1_len = 0;
        self.num2_len = 0;
    }

    fn processMul(self: *State) !void {
        defer self.restartInstruction(.start);
        if (!self.mul_enabled) {
            return;
        }

        const num1 = try fmt.parseUnsigned(u32, self.num1[0..self.num1_len], 10);
        const num2 = try fmt.parseUnsigned(u32, self.num2[0..self.num2_len], 10);
        self.total += num1 * num2;
    }

    fn advance(self: *State, next: u8) !void {
        defer self.prev = next;

        switch (self.phase) {
            .start => {
                if (next == 'm') {
                    self.phase = .mul;
                } else if (next == 'd') {
                    self.phase = .do;
                }
            },
            .mul => {
                switch (next) {
                    'u' => {
                        if (self.prev != 'm') {
                            self.restartInstruction(.start);
                        }
                    },
                    'l' => {
                        if (self.prev != 'u') {
                            self.restartInstruction(.start);
                        }
                    },
                    '(' => {
                        if (self.prev != 'l') {
                            self.restartInstruction(.start);
                        }
                    },
                    '0'...'9' => {
                        if (self.prev != '(') {
                            self.restartInstruction(.start);
                        } else {
                            self.num1[0] = next;
                            self.num1_len = 1;
                            self.phase = .first;
                        }
                    },
                    'd' => {
                        self.restartInstruction(.do);
                    },
                    else => {
                        self.restartInstruction(.start);
                    },
                }
            },
            .first => {
                switch (next) {
                    ',' => {
                        self.phase = .second;
                    },
                    '0'...'9' => {
                        if (self.num1_len == 3) {
                            self.restartInstruction(.start);
                        } else {
                            self.num1[self.num1_len] = next;
                            self.num1_len += 1;
                        }
                    },
                    'd' => {
                        self.restartInstruction(.do);
                    },
                    else => {
                        self.restartInstruction(.start);
                    },
                }
            },
            .second => {
                switch (next) {
                    ')' => {
                        if (self.num2_len == 0) {
                            self.restartInstruction(.start);
                        } else {
                            try self.processMul();
                        }
                    },
                    '0'...'9' => {
                        if (self.num2_len == 3) {
                            self.restartInstruction(.start);
                        } else {
                            self.num2[self.num2_len] = next;
                            self.num2_len += 1;
                        }
                    },
                    'd' => {
                        self.restartInstruction(.do);
                    },
                    else => {
                        self.restartInstruction(.start);
                    },
                }
            },
            .do => {
                switch (next) {
                    'o' => {
                        if (self.prev != 'd') {
                            self.restartInstruction(.start);
                        }
                    },
                    '(' => {
                        if (self.prev != 'o') {
                            self.restartInstruction(.start);
                        }
                    },
                    ')' => {
                        if (self.prev != '(') {
                            self.restartInstruction(.start);
                        } else {
                            self.mul_enabled = true;
                        }
                    },
                    'n' => {
                        self.restartInstruction(if (self.prev == 'o') .dont else .start);
                    },
                    'm' => {
                        self.restartInstruction(.mul);
                    },
                    else => {
                        self.restartInstruction(.start);
                    },
                }
            },
            .dont => {
                switch (next) {
                    '\'' => {
                        if (self.prev != 'n') {
                            self.restartInstruction(.start);
                        }
                    },
                    't' => {
                        if (self.prev != '\'') {
                            self.restartInstruction(.start);
                        }
                    },
                    '(' => {
                        if (self.prev != 't') {
                            self.restartInstruction(.start);
                        }
                    },
                    ')' => {
                        if (self.prev != '(') {
                            self.restartInstruction(.start);
                        } else {
                            self.mul_enabled = false;
                        }
                    },
                    'm' => {
                        self.restartInstruction(.mul);
                    },
                    else => {
                        self.restartInstruction(.start);
                    },
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
