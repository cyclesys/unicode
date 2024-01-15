const std = @import("std");
const ReverseUtf8Iterator = @import("ReverseUtf8Iterator.zig");

pub fn testBreakIterator(comptime name: []const u8, initFn: anytype) !void {
    const test_data = @embedFile("ucd_test/" ++ name);
    const allocator = std.testing.allocator;

    var chars = std.ArrayList(u32).init(allocator);
    defer chars.deinit();

    var breaks = std.ArrayList(u32).init(allocator);
    defer breaks.deinit();

    var lines = std.mem.splitScalar(u8, test_data, '\n');
    var line_num: usize = 1;
    while (lines.next()) |line| : (line_num += 1) {
        if (line.len == 0 or line[0] == '#') {
            continue;
        }

        var iter = std.unicode.Utf8Iterator{ .bytes = line, .i = 0 };
        var unit_start: usize = 0;
        var code_point_start: ?usize = null;
        var code_point: ?u32 = null;
        while (iter.nextCodepointSlice()) |slice| : (unit_start += slice.len) {
            const unit = try std.unicode.utf8Decode(slice);
            switch (unit) {
                '÷' => {
                    if (code_point) |cp| {
                        try breaks.append(cp);
                        code_point = null;
                    }
                },
                '×' => {
                    code_point = null;
                },
                ' ' => {
                    if (code_point_start) |start| {
                        const c = try std.fmt.parseInt(u21, line[start..unit_start], 16);
                        try chars.append(c);

                        code_point = c;
                        code_point_start = null;
                    }
                },
                '0'...'9', 'A'...'F' => {
                    if (code_point_start == null) {
                        if (code_point != null) {
                            @panic("unconsumed code point");
                        }
                        code_point_start = unit_start;
                    }
                },
                '#' => {
                    break;
                },
                else => {
                    // ignore everything else
                },
            }
        }

        expectBreaks(chars.items, breaks.items, initFn) catch |e| {
            std.debug.print("Line: {}\n", .{line_num});
            return e;
        };

        chars.clearRetainingCapacity();
        breaks.clearRetainingCapacity();
    }
}

fn expectBreaks(chars: []const u32, breaks: []const u32, initFn: anytype) !void {
    var iter = initFn(chars);
    for (breaks) |expected| {
        const index = if (iter.next()) |i| i else return error.ExpectedMoreBreaks;
        const actual = chars[index];
        std.testing.expectEqual(expected, actual) catch {
            return error.ExpectedBreakEqual;
        };
    }
    std.testing.expectEqual(@as(?usize, null), iter.next()) catch {
        return error.ExpectedNoMoreBreaks;
    };
}
