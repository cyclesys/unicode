const std = @import("std");
const BidiBrackets = @import("BidiBrackets.zig");
const Property = @import("Property.zig");
const TrieBuilder = @import("TrieBuilder.zig");
const UnicodeData = @import("UnicodeData.zig");

// unicode version.
const version = "15.0.0";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    {
        var bytes = try downloadFile(allocator, "UnicodeData.txt");
        defer allocator.free(bytes);

        var data = try UnicodeData.parse(allocator, bytes);
        defer data.deinit();

        try genCategoryTrie(allocator, data, "gen_cat", "GeneralCategory.zig");
        try genCategoryTrie(allocator, data, "bidi_cat", "BidiCategory.zig");
        try genBidiBrackets(allocator, data);
    }

    {
        var derived_bidi_extra = Property.init(allocator);
        defer derived_bidi_extra.deinit();

        try derived_bidi_extra.add("L", .{
            .start = 0x0000,
            .end = 0x10FFFF,
        });
        try derived_bidi_extra.add("R", .{
            .start = 0x0590,
            .end = 0x05FF,
        });
        try derived_bidi_extra.add("AL", .{
            .start = 0x0600,
            .end = 0x07BF,
        });
        try derived_bidi_extra.add("R", .{
            .start = 0x07C0,
            .end = 0x085F,
        });
        try derived_bidi_extra.add("AL", .{
            .start = 0x0860,
            .end = 0x08FF,
        });
        try derived_bidi_extra.add("ET", .{
            .start = 0x20A0,
            .end = 0x20CF,
        });
        try derived_bidi_extra.add("R", .{
            .start = 0xFB1D,
            .end = 0xFB4F,
        });
        try derived_bidi_extra.add("AL", .{
            .start = 0xFB50,
            .end = 0xFDCF,
        });
        try derived_bidi_extra.add("AL", .{
            .start = 0xFDF0,
            .end = 0xFDFF,
        });
        try derived_bidi_extra.add("AL", .{
            .start = 0xFE70,
            .end = 0xFEFF,
        });
        try derived_bidi_extra.add("R", .{
            .start = 0x10800,
            .end = 0x10CFF,
        });
        try derived_bidi_extra.add("AL", .{
            .start = 0x10D00,
            .end = 0x10D3F,
        });
        try derived_bidi_extra.add("R", .{
            .start = 0x10D40,
            .end = 0x10EBF,
        });
        try derived_bidi_extra.add("AL", .{
            .start = 0x10EC0,
            .end = 0x10EFF,
        });
        try derived_bidi_extra.add("R", .{
            .start = 0x10F00,
            .end = 0x10F2F,
        });
        try derived_bidi_extra.add("AL", .{
            .start = 0x10F30,
            .end = 0x10F6F,
        });
        try derived_bidi_extra.add("R", .{
            .start = 0x10F70,
            .end = 0x10FFF,
        });
        try derived_bidi_extra.add("R", .{
            .start = 0x1E800,
            .end = 0x1EC6F,
        });
        try derived_bidi_extra.add("AL", .{
            .start = 0x1EC70,
            .end = 0x1ECBF,
        });
        try derived_bidi_extra.add("R", .{
            .start = 0x1ECC0,
            .end = 0x1ECFF,
        });
        try derived_bidi_extra.add("AL", .{
            .start = 0x1ED00,
            .end = 0x1ED4F,
        });
        try derived_bidi_extra.add("R", .{
            .start = 0x1ED50,
            .end = 0x1EDFF,
        });
        try derived_bidi_extra.add("AL", .{
            .start = 0x1EE00,
            .end = 0x1EEFF,
        });
        try derived_bidi_extra.add("R", .{
            .start = 0x1EF00,
            .end = 0x1EFFF,
        });

        try genPropertyTrie(allocator, "extracted/DerivedBidiClass.txt", "DerivedBidi.zig", &derived_bidi_extra);
    }

    try copyFile(allocator, "BidiTest.txt", null);
    try copyFile(allocator, "BidiCharacterTest.txt", null);

    {
        var emoji_property = try loadProperty(allocator, "emoji/emoji-data.txt", &.{"Extended_Pictographic"});
        defer emoji_property.deinit();

        try genPropertyTrie(allocator, "auxiliary/GraphemeBreakProperty.txt", "GraphemeBreakProperty.zig", &emoji_property);
        try genPropertyTrie(allocator, "auxiliary/WordBreakProperty.txt", "WordBreakProperty.zig", &emoji_property);
    }

    {
        var line_break_property_extra = Property.init(allocator);
        defer line_break_property_extra.deinit();

        try line_break_property_extra.add("ID", .{
            .start = 0x3400,
            .end = 0x4DBF,
        });
        try line_break_property_extra.add("ID", .{
            .start = 0x4E00,
            .end = 0x9FFF,
        });
        try line_break_property_extra.add("ID", .{
            .start = 0xF900,
            .end = 0xFAFF,
        });
        try line_break_property_extra.add("ID", .{
            .start = 0x20000,
            .end = 0x2FFFD,
        });
        try line_break_property_extra.add("ID", .{
            .start = 0x30000,
            .end = 0x3FFFD,
        });
        try line_break_property_extra.add("ID", .{
            .start = 0x1F000,
            .end = 0x1FAFF,
        });
        try line_break_property_extra.add("ID", .{
            .start = 0x1FC00,
            .end = 0x1FFFD,
        });
        try line_break_property_extra.add("PR", .{
            .start = 0x20A0,
            .end = 0x20CF,
        });

        try genPropertyTrie(allocator, "LineBreak.txt", "LineBreakProperty.zig", &line_break_property_extra);
    }

    try genPropertyTrie(allocator, "EastAsianWidth.txt", "EastAsianWidth.zig", null);
    try genPropertyTrie(allocator, "Scripts.txt", "Script.zig", null);

    try copyFile(allocator, "auxiliary/GraphemeBreakTest.txt", "GraphemeBreakTest.txt");
    try copyFile(allocator, "auxiliary/WordBreakTest.txt", "WordBreakTest.txt");
    try copyFile(allocator, "auxiliary/LineBreakTest.txt", "LineBreakTest.txt");
}

fn genCategoryTrie(
    allocator: std.mem.Allocator,
    data: UnicodeData,
    comptime category: []const u8,
    comptime file_name: []const u8,
) !void {
    const cats = &@field(data, category);
    const trie = blk: {
        var builder = try TrieBuilder.init(
            allocator,
            @intCast(cats.count()),
            @intCast(cats.count() + 1),
        );
        defer builder.deinit();

        for (data.entries.items) |entry| {
            const value = cats.getIndex(@field(entry, category)).?;
            try builder.setRange(entry.start, entry.end, @intCast(value));
        }

        break :blk try builder.build();
    };
    defer trie.deinit();

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    try writeTrie(&buf, &trie, cats.keys());
    try outputFile(file_name, buf.items);
}

fn genBidiBrackets(allocator: std.mem.Allocator, data: UnicodeData) !void {
    const bytes = try downloadFile(allocator, "BidiBrackets.txt");
    defer allocator.free(bytes);

    const brackets = try BidiBrackets.parse(allocator, bytes);
    defer brackets.deinit();

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    try buf.appendSlice(
        \\pub const Bracket = struct {
        \\    pair: u32,
        \\    type: BracketType,
        \\    mapping: ?u32,
        \\};
        \\pub const BracketType = enum {
        \\    opening,
        \\    closing,
        \\};
        \\
    );

    try buf.appendSlice(
        \\pub fn get(c: u32) ?Bracket {
        \\    return switch (c) {
        \\
    );
    for (brackets.entries.items) |entry| {
        try buf.appendSlice("        '");
        try writeUnicodeCodePoint(&buf, entry.left);
        try buf.appendSlice("' => Bracket{\n");
        try buf.appendSlice("            .pair = '");
        try writeUnicodeCodePoint(&buf, entry.right);
        try buf.appendSlice("',\n");
        try buf.appendSlice("            .type = ");
        switch (entry.kind) {
            .opening => try buf.appendSlice(".opening,\n"),
            .closing => try buf.appendSlice(".closing,\n"),
        }
        try buf.appendSlice("            .mapping = ");
        if (data.mappings.get(entry.left)) |mapping| {
            try buf.append('\'');
            try writeUnicodeCodePoint(&buf, mapping);
            try buf.append('\'');
        } else {
            try buf.appendSlice("null");
        }
        try buf.appendSlice(",\n");
        try buf.appendSlice("        },\n");
    }
    try buf.appendSlice(
        \\        else => null,
        \\    };
        \\}
    );

    try outputFile("BidiBrackets.zig", buf.items);
}

fn genPropertyTrie(
    allocator: std.mem.Allocator,
    comptime ucd_path: []const u8,
    comptime file_name: []const u8,
    extend: ?*const Property,
) !void {
    var property = Property.init(allocator);
    defer property.deinit();

    if (extend) |ext| {
        try property.extend(ext);
    }

    const bytes = try downloadFile(allocator, ucd_path);
    defer allocator.free(bytes);

    try property.parse(bytes, &.{});

    const trie = blk: {
        var builder = try TrieBuilder.init(
            allocator,
            @intCast(property.entries.count()),
            @intCast(property.entries.count() + 1),
        );
        defer builder.deinit();

        var iter = property.entries.iterator();
        var value: u32 = 0;
        while (iter.next()) |entry| : (value += 1) {
            const list: *Property.RangeList = entry.value_ptr;
            for (list.items) |range| {
                try builder.setRange(range.start, range.end, value);
            }
        }

        break :blk try builder.build();
    };
    defer trie.deinit();

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    try writeTrie(&buf, &trie, property.entries.keys());
    try outputFile(file_name, buf.items);
}

fn loadProperty(allocator: std.mem.Allocator, comptime ucd_path: []const u8, filters: []const []const u8) !Property {
    const bytes = try downloadFile(allocator, ucd_path);
    defer allocator.free(bytes);

    var property = Property.init(allocator);
    try property.parse(bytes, filters);

    return property;
}

fn writeTrie(buf: *std.ArrayList(u8), trie: *const TrieBuilder.Trie, values: []const []const u8) !void {
    var formatter = ArrayDataFormatter{ .buf = buf };

    try buf.appendSlice("pub const Value = enum {\n");
    for (values) |value| {
        try std.fmt.format(buf.writer(), "    {s},\n", .{value});
    }
    try buf.appendSlice("    Any,\n");
    try buf.appendSlice("    Error,\n");
    try buf.appendSlice("};\n");

    try buf.appendSlice("pub const index = [_]u16 {");
    for (trie.index) |val| {
        try formatter.next("0x{X}", val);
    }
    try buf.appendSlice("\n};\n");

    formatter.width = 0;
    try buf.appendSlice("pub const data = [_]Value{");
    for (trie.data) |val| {
        const value = if (val < values.len)
            values[val]
        else if (val == values.len)
            "Any"
        else
            "Error";
        try formatter.next(".{s}", value);
    }
    try buf.appendSlice("\n};\n");

    try std.fmt.format(buf.writer(), "pub const high_start = 0x{X};", .{trie.high_start});
}

const ArrayDataFormatter = struct {
    width: usize = 0,
    buf: *std.ArrayList(u8),

    fn next(self: *ArrayDataFormatter, comptime fmt: []const u8, value: anytype) !void {
        const count = std.fmt.count(fmt, .{value});
        if (self.width == 0 or self.width + count + 2 > 120) {
            try self.buf.appendSlice("\n   ");
            self.width = 3;
        }

        try self.buf.append(' ');
        self.width += 1;

        try std.fmt.format(self.buf.writer(), fmt, .{value});
        self.width += count;

        try self.buf.append(',');
        self.width += 1;
    }
};

fn writeUnicodeCodePoint(buf: *std.ArrayList(u8), code_point: u32) !void {
    try buf.appendSlice("\\u{");
    const count = std.fmt.count("{X}", .{code_point});
    if (count < 4) {
        for (0..4 - count) |_| {
            try buf.append('0');
        }
    }
    try std.fmt.format(buf.writer(), "{X}", .{code_point});
    try buf.append('}');
}

fn copyFile(allocator: std.mem.Allocator, comptime ucd_path: []const u8, comptime file_name: ?[]const u8) !void {
    const file_bytes = try downloadFile(allocator, ucd_path);
    defer allocator.free(file_bytes);

    try outputFile(file_name orelse ucd_path, file_bytes);
}

fn downloadFile(allocator: std.mem.Allocator, comptime ucd_path: []const u8) ![]const u8 {
    const url = "https://www.unicode.org/Public/" ++ version ++ "/ucd/" ++ ucd_path;
    const result = try std.ChildProcess.exec(.{
        .allocator = allocator,
        .argv = &.{ "curl", url },
        .max_output_bytes = 10 * 1024 * 1024,
    });
    allocator.free(result.stderr);

    switch (result.term) {
        .Exited => |code| {
            if (code != 0) {
                return error.DownloadError;
            }
        },
        .Signal, .Stopped, .Unknown => {
            return error.DownloadError;
        },
    }

    return result.stdout;
}

fn outputFile(comptime file_name: []const u8, bytes: []const u8) !void {
    const cwd = std.fs.cwd();

    const file = try cwd.createFile("src/ucd/" ++ file_name, .{ .truncate = true });
    defer file.close();

    try file.writeAll(bytes);
}
