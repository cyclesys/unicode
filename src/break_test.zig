const std = @import("std");
const ReverseUtf8Iterator = @import("ReverseUtf8Iterator.zig");

pub fn testBreakIterator(comptime name: []const u8, initFn: anytype) !void {
    const test_data = @embedFile("ucd_test/" ++ name);
    const allocator = std.testing.allocator;

    var str = std.ArrayList(u8).init(allocator);
    defer str.deinit();

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

                        var out: [4]u8 = undefined;
                        const out_len = try std.unicode.utf8Encode(c, &out);
                        try str.appendSlice(out[0..out_len]);

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

        expectBreaks(str.items, breaks.items, initFn) catch |e| {
            std.debug.print("Line: {}\n", .{line_num});
            return e;
        };

        str.clearRetainingCapacity();
        breaks.clearRetainingCapacity();
    }
}

fn expectBreaks(str: []const u8, breaks: []const u32, initFn: anytype) !void {
    var iter = initFn(str);
    for (breaks) |expected| {
        const index = if (iter.next()) |i| i else return error.ExpectedMoreBreaks;
        var str_iter = ReverseUtf8Iterator.init(str[0..index]);
        const actual = try std.unicode.utf8Decode(str_iter.next().?);
        std.testing.expectEqual(expected, actual) catch {
            return error.ExpectedBreakEqual;
        };
    }
    std.testing.expectEqual(@as(?usize, null), iter.next()) catch {
        return error.ExpectedNoMoreBreaks;
    };
}
