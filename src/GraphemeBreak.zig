const std = @import("std");
const ucd = @import("ucd.zig");
const ReverseUtf8Iterator = @import("ReverseUtf8Iterator.zig");

str: []const u8,
i: usize,
ris_count: usize,

const Self = @This();

pub fn init(str: []const u8) !Self {
    if (!std.unicode.utf8ValidateSlice(str)) {
        return error.InvalidUtf8;
    }
    return initAssumeValid(str);
}

pub fn initAssumeValid(str: []const u8) Self {
    return Self{
        .str = str,
        .i = 0,
        .ris_count = 0,
    };
}

pub fn next(self: *Self) ?usize {
    if (self.i >= self.str.len) {
        return null;
    }

    var iter = std.unicode.Utf8Iterator{ .bytes = self.str, .i = self.i };

    var code_point = iter.nextCodepointSlice().?;
    var before = ucd.GraphemeBreakProperty.getUtf8AssumeValid(code_point);
    var prev_i = self.i;

    while (true) {
        self.i += code_point.len;

        const after = if (iter.nextCodepointSlice()) |next_code_point| blk: {
            code_point = next_code_point;
            break :blk ucd.GraphemeBreakProperty.getUtf8AssumeValid(next_code_point);
        } else {
            return self.i;
        };

        if (before == .Regional_Indicator) {
            self.ris_count += 1;
        } else {
            self.ris_count = 0;
        }

        const can_break = switch (before) {
            .CR => switch (after) {
                .LF => false,
                else => true,
            },
            .LF => true,
            .Control => true,
            .L => switch (after) {
                .L, .V, .LV, .LVT => false,
                else => defaultAfter(after),
            },
            .LV => switch (after) {
                .V, .T => false,
                else => defaultAfter(after),
            },
            .V => switch (after) {
                .V, .T => false,
                else => defaultAfter(after),
            },
            .LVT => switch (after) {
                .T => false,
                else => defaultAfter(after),
            },
            .T => switch (after) {
                .T => false,
                else => defaultAfter(after),
            },
            .Prepend => switch (after) {
                .CR, .LF, .Control => true,
                else => false,
            },
            .ZWJ => blk: {
                if (after == .Extended_Pictographic) {
                    var rev_iter = ReverseUtf8Iterator.init(self.str[0..prev_i]);
                    while (rev_iter.next()) |prev_code_point| {
                        const prev = ucd.GraphemeBreakProperty.getUtf8AssumeValid(prev_code_point);
                        switch (prev) {
                            .Extend => continue,
                            .Extended_Pictographic => break :blk false,
                            else => break,
                        }
                    }
                }
                break :blk defaultAfter(after);
            },
            .Regional_Indicator => switch (after) {
                .Regional_Indicator => (self.ris_count % 2) == 0,
                else => defaultAfter(after),
            },
            else => defaultAfter(after),
        };

        if (can_break) {
            return self.i;
        }

        before = after;
        prev_i = self.i;
    }
}

inline fn defaultAfter(after: ucd.GraphemeBreakProperty) bool {
    return switch (after) {
        .Extend, .ZWJ, .SpacingMark => false,
        else => true,
    };
}

const break_test = @import("break_test.zig");
test "GraphemeBreakTest" {
    try break_test.testBreakIterator("GraphemeBreakTest.txt", initAssumeValid);
}
