const std = @import("std");
const ucd = @import("ucd.zig");
const ReverseUtf8Iterator = @import("ReverseUtf8Iterator.zig");

str: []const u8,
i: usize,
ris_count: usize,
context: Context,
cm_base: ?struct {
    code_point: []const u8,
    prop: ucd.LineBreakProperty,
},

const Context = enum {
    zw_sp,
    op_sp,
    qu_sp,
    clcp_sp,
    b2_sp,
    hl_hyba,
    none,
};
const Self = @This();

pub const Break = struct {
    mandatory: bool,
    i: usize,
};

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
        .context = .none,
        .cm_base = null,
    };
}

pub fn next(self: *Self) ?Break {
    if (self.i >= self.str.len) {
        return null;
    }

    var iter = std.unicode.Utf8Iterator{ .bytes = self.str, .i = self.i };

    var before_code_point = iter.nextCodepointSlice().?;
    var before = breakProp(before_code_point);
    self.context = .none;

    while (true) {
        self.i += before_code_point.len;

        const after_code_point = if (iter.nextCodepointSlice()) |next_code_point| next_code_point else {
            return Break{
                .mandatory = true,
                .i = self.i,
            };
        };
        const after = breakProp(after_code_point);

        if (before == .RI) {
            self.ris_count += 1;
        } else if (before != .CM and before != .ZWJ) {
            self.ris_count = 0;
        }

        if (self.checkPair(before, before_code_point, after, after_code_point)) |mandatory| {
            return Break{
                .mandatory = mandatory,
                .i = self.i,
            };
        }
        before_code_point = after_code_point;
        before = after;
    }
}

fn checkPair(
    self: *Self,
    before: ucd.LineBreakProperty,
    before_code_point: []const u8,
    after: ucd.LineBreakProperty,
    after_code_point: []const u8,
) ?bool {
    return switch (before) {
        .CR => switch (after) {
            .LF => null,
            else => true,
        },
        .BK, .LF, .NL => true,
        .ZW => switch (after) {
            .CR, .BK, .LF, .NL, .ZW => null,
            .SP => self.setContext(.zw_sp),
            else => false,
        },
        .ZWJ => if (self.cm_base) |base| blk: {
            self.cm_base = null;
            break :blk self.checkPair(base.prop, base.code_point, after, after_code_point);
        } else null,
        .CM => if (self.cm_base) |base| blk: {
            self.cm_base = null;
            break :blk self.checkPair(base.prop, base.code_point, after, after_code_point);
        } else self.checkPair(.AL, undefined, after, after_code_point),
        .WJ, .GL => switch (after) {
            .CM, .ZWJ => self.setCmBase(before, before_code_point),
            else => null,
        },
        .BA => switch (after) {
            .GL, .CB => false,
            else => switch (self.context) {
                .hl_hyba => null,
                else => self.defaultAfter(before, before_code_point, after),
            },
        },
        .OP => switch (after) {
            .SP => self.setContext(.op_sp),
            .CM, .ZWJ => self.setCmBase(before, before_code_point),
            else => null,
        },
        .QU => switch (after) {
            .SP => self.setContext(.qu_sp),
            .CM, .ZWJ => self.setCmBase(before, before_code_point),
            else => null,
        },
        .CL => switch (after) {
            .SP => self.setContext(.clcp_sp),
            .NS => null,
            .PR, .PO => if (self.numericBefore(before_code_point)) null else false,
            else => self.defaultAfter(before, before_code_point, after),
        },
        .CP => switch (after) {
            .SP => self.setContext(.clcp_sp),
            .NS => null,
            .PR, .PO => if (self.numericBefore(before_code_point)) null else false,
            .AL, .HL, .NU => switch (ucd.EastAsianWidthProperty.getUtf8AssumeValid(before_code_point)) {
                .F, .W, .H => self.defaultAfter(before, before_code_point, after),
                else => null,
            },
            else => self.defaultAfter(before, before_code_point, after),
        },
        .B2 => switch (after) {
            .SP => self.setContext(.b2_sp),
            .B2 => null,
            else => self.defaultAfter(before, before_code_point, after),
        },
        .SP => switch (after) {
            .SP => null,
            .BK, .CR, .LF, .NL, .ZW => self.setContext(.none),
            .WJ, .CL, .CP, .EX, .IS, .SY => if (self.context == .zw_sp) false else self.setContext(.none),
            else => switch (self.context) {
                .zw_sp => false,
                .op_sp => self.setContext(.none),
                .qu_sp => if (after == .OP) self.setContext(.none) else false,
                .b2_sp => if (after == .B2) self.setContext(.none) else false,
                .clcp_sp => if (after == .NS) self.setContext(.none) else false,
                else => switch (after) {
                    else => false,
                },
            },
        },
        .CB => switch (after) {
            .BK, .CR, .LF, .NL, .SP, .ZW, .WJ, .GL, .CL, .CP, .EX, .IS, .SY, .QU => null,
            .CM, .ZWJ => self.setCmBase(before, before_code_point),
            else => false,
        },
        .BB => switch (after) {
            .CM, .ZWJ => self.setCmBase(before, before_code_point),
            .CB => false,
            else => null,
        },
        .HL => switch (after) {
            .HY, .BA => self.setContext(.hl_hyba),
            .NU, .PR, .PO, .AL, .HL => null,
            .OP => switch (ucd.EastAsianWidthProperty.getUtf8AssumeValid(after_code_point)) {
                .F, .W, .H => self.defaultAfter(before, before_code_point, after),
                else => null,
            },
            else => self.defaultAfter(before, before_code_point, after),
        },
        .SY => switch (after) {
            .HL => null,
            .NU => if (self.numericBefore(before_code_point)) null else false,
            else => self.defaultAfter(before, before_code_point, after),
        },
        .AL => switch (after) {
            .NU, .PR, .PO, .AL, .HL => null,
            .OP => switch (ucd.EastAsianWidthProperty.getUtf8AssumeValid(after_code_point)) {
                .F, .W, .H => self.defaultAfter(before, before_code_point, after),
                else => null,
            },
            else => self.defaultAfter(before, before_code_point, after),
        },
        .NU => switch (after) {
            .AL, .HL, .PO, .PR, .NU => null,
            .OP => switch (ucd.EastAsianWidthProperty.getUtf8AssumeValid(after_code_point)) {
                .F, .W, .H => self.defaultAfter(before, before_code_point, after),
                else => null,
            },
            else => self.defaultAfter(before, before_code_point, after),
        },
        .PR => switch (after) {
            .ID, .EB, .EM, .AL, .HL, .NU, .JL, .JV, .JT, .H2, .H3 => null,
            .OP => if (self.numericAfter(after_code_point)) null else false,
            else => self.defaultAfter(before, before_code_point, after),
        },
        .ID => switch (after) {
            .PO => null,
            .EM => blk: {
                break :blk switch (ucd.GeneralCategory.getUtf8AssumeValid(before_code_point)) {
                    .None => null,
                    else => self.defaultAfter(before, before_code_point, after),
                };
            },
            else => self.defaultAfter(before, before_code_point, after),
        },
        .EB => switch (after) {
            .PO, .EM => null,
            else => self.defaultAfter(before, before_code_point, after),
        },
        .EM => switch (after) {
            .PO => null,
            else => self.defaultAfter(before, before_code_point, after),
        },
        .PO => switch (after) {
            .AL, .HL, .NU => null,
            .OP => if (self.numericAfter(after_code_point)) null else false,
            else => self.defaultAfter(before, before_code_point, after),
        },
        .HY => switch (after) {
            .NU => null,
            .GL, .CB => false,
            else => switch (self.context) {
                .hl_hyba => null,
                else => self.defaultAfter(before, before_code_point, after),
            },
        },
        .IS => switch (after) {
            .NU => if (self.numericBefore(before_code_point)) null else false,
            .AL, .HL => null,
            else => self.defaultAfter(before, before_code_point, after),
        },
        .JL => switch (after) {
            .JL, .JV, .H2, .H3, .PO => null,
            else => self.defaultAfter(before, before_code_point, after),
        },
        .JV => switch (after) {
            .JV, .JT, .PO => null,
            else => self.defaultAfter(before, before_code_point, after),
        },
        .JT => switch (after) {
            .JT, .PO => null,
            else => self.defaultAfter(before, before_code_point, after),
        },
        .H2 => switch (after) {
            .JV, .JT, .PO => null,
            else => self.defaultAfter(before, before_code_point, after),
        },
        .H3 => switch (after) {
            .JT, .PO => null,
            else => self.defaultAfter(before, before_code_point, after),
        },
        .RI => switch (after) {
            .RI => if ((self.ris_count % 2) == 0) false else null,
            else => self.defaultAfter(before, before_code_point, after),
        },
        else => self.defaultAfter(before, before_code_point, after),
    };
}

fn setCmBase(self: *Self, before: ucd.LineBreakProperty, before_code_point: []const u8) ?bool {
    self.cm_base = .{
        .code_point = before_code_point,
        .prop = before,
    };
    return null;
}

fn numericBefore(self: *Self, before_code_point: []const u8) bool {
    var iter = ReverseUtf8Iterator.init(self.str[0 .. self.i - before_code_point.len]);
    while (iter.next()) |code_point| {
        switch (breakProp(code_point)) {
            .SY, .IS => continue,
            .NU => return true,
            else => break,
        }
    }
    return false;
}

fn numericAfter(self: *Self, after_code_point: []const u8) bool {
    var iter = std.unicode.Utf8Iterator{ .bytes = self.str[self.i + after_code_point.len ..], .i = 0 };
    if (iter.nextCodepointSlice()) |code_point| {
        if (breakProp(code_point) == .NU) {
            return true;
        }
    }
    return false;
}

fn defaultAfter(self: *Self, before: ucd.LineBreakProperty, before_code_point: []const u8, after: ucd.LineBreakProperty) ?bool {
    return switch (after) {
        .BK, .CR, .LF, .NL, .SP, .ZW, .WJ, .GL, .CL, .CP, .EX, .IS, .SY, .QU, .BA, .HY, .NS, .IN => null,
        .CM, .ZWJ => blk: {
            self.cm_base = .{
                .code_point = before_code_point,
                .prop = before,
            };
            break :blk null;
        },
        else => false,
    };
}

fn setContext(self: *Self, context: Context) ?bool {
    self.context = context;
    return null;
}

fn breakProp(cs: []const u8) ucd.LineBreakProperty {
    const c = std.unicode.utf8Decode(cs) catch unreachable;
    return switch (ucd.LineBreakProperty.getUtf32(c)) {
        .AI, .SG, .XX, .None => .AL,
        .SA => switch (ucd.GeneralCategory.getUtf32(c)) {
            .Mn, .Mc => .CM,
            else => .AL,
        },
        .CJ => .NS,
        else => |v| v,
    };
}

const break_test = @import("break_test.zig");
test {
    try break_test.testBreakIterator("LineBreakTest.txt", TestIter.init);
}
const TestIter = struct {
    iter: Self,

    pub fn init(str: []const u8) TestIter {
        return TestIter{
            .iter = Self.initAssumeValid(str),
        };
    }

    pub fn next(self: *TestIter) ?usize {
        return if (self.iter.next()) |brk|
            brk.i
        else
            null;
    }
};
