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

    std.fs.cwd().makeDir("src/ucd_test") catch |e| {
        if (e != error.PathAlreadyExists) {
            return e;
        }
    };
    try copyFile(allocator, "BidiTest.txt", "ucd_test/BidiTest.txt");
    try copyFile(allocator, "BidiCharacterTest.txt", "ucd_test/BidiCharacterTest.txt");
    try copyFile(allocator, "auxiliary/GraphemeBreakTest.txt", "ucd_test/GraphemeBreakTest.txt");
    try copyFile(allocator, "auxiliary/WordBreakTest.txt", "ucd_test/WordBreakTest.txt");
    try copyFile(allocator, "auxiliary/LineBreakTest.txt", "ucd_test/LineBreakTest.txt");

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    try buf.appendSlice(
        \\const std = @import("std");
        \\
        \\
    );

    {
        var bytes = try downloadFile(allocator, "UnicodeData.txt");
        defer allocator.free(bytes);

        var data = try UnicodeData.parse(allocator, bytes);
        defer data.deinit();

        try writeCategoryTrie(allocator, &buf, data, "gen_cat", "GeneralCategory");
        try writeCategoryTrie(allocator, &buf, data, "bidi_cat", "BidiCategory");
        try writeBidiBrackets(allocator, &buf, data);
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

        try writePropertyTrie(allocator, &buf, "extracted/DerivedBidiClass.txt", "DerivedBidiProperty", derived_bidi_extra);
    }

    {
        var emoji_property = try loadProperty(allocator, "emoji/emoji-data.txt", &.{"Extended_Pictographic"});
        defer emoji_property.deinit();

        try writePropertyTrie(allocator, &buf, "auxiliary/GraphemeBreakProperty.txt", "GraphemeBreakProperty", emoji_property);
        try writePropertyTrie(allocator, &buf, "auxiliary/WordBreakProperty.txt", "WordBreakProperty", emoji_property);
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

        try writePropertyTrie(allocator, &buf, "LineBreak.txt", "LineBreakProperty", line_break_property_extra);
    }

    try writePropertyTrie(allocator, &buf, "EastAsianWidth.txt", "EastAsianWidthProperty", null);
    try writePropertyTrie(allocator, &buf, "Scripts.txt", "ScriptProperty", null);

    try buf.appendSlice(
        \\fn trieGetUtf8(comptime Trie: type, cs: []const u8) !Trie {
        \\    const c = try std.unicode.utf8Decode(cs);
        \\    return trieGetUtf32(Trie, c);
        \\}
        \\
        \\fn trieGetUtf8AssumeValid(comptime Trie: type, cs: []const u8) Trie {
        \\    const c = std.unicode.utf8Decode(cs) catch unreachable;
        \\    return trieGetUtf32(Trie, c);
        \\}
        \\
        \\fn trieGetUtf32(comptime Trie: type, c: u32) Trie {
        \\    const FAST_SHIFT = 6;
        \\    const FAST_DATA_BLOCK_LEN = 1 << FAST_SHIFT;
        \\    const FAST_DATA_MASK = FAST_DATA_BLOCK_LEN - 1;
        \\    const SHIFT_3 = 4;
        \\    const SHIFT_2 = 5 + SHIFT_3;
        \\    const SHIFT_1 = 5 + SHIFT_2;
        \\    const SHIFT_1_2 = SHIFT_1 - SHIFT_2;
        \\    const SHIFT_2_3 = SHIFT_2 - SHIFT_3;
        \\    const SMALL_DATA_BLOCK_LEN = 1 << SHIFT_3;
        \\    const SMALL_DATA_MASK = SMALL_DATA_BLOCK_LEN - 1;
        \\    const INDEX_2_BLOCK_LEN = 1 << SHIFT_1_2;
        \\    const INDEX_2_MASK = INDEX_2_BLOCK_LEN - 1;
        \\    const INDEX_3_BLOCK_LEN = 1 << SHIFT_2_3;
        \\    const INDEX_3_MASK = INDEX_3_BLOCK_LEN - 1;
        \\    const BMP_INDEX_LEN = 0x10000 >> FAST_SHIFT;
        \\    const OMITTED_BMP_INDEX_1_LEN = 0x10000 >> SHIFT_1;
        \\    const ERROR_VALUE_NEG_DATA_OFFSET = 1;
        \\    const HIGH_VALUE_NEG_DATA_OFFSET = 2;
        \\
        \\    if (c <= 0xFFFF) {
        \\        return @enumFromInt(Trie.data[Trie.index[c >> FAST_SHIFT] + (c & FAST_DATA_MASK)]);
        \\    }
        \\    if (c > 0x10FFFF) {
        \\        return @enumFromInt(Trie.data[Trie.data.len - ERROR_VALUE_NEG_DATA_OFFSET]);
        \\    }
        \\    if (c >= Trie.high_start) {
        \\        return @enumFromInt(Trie.data[Trie.data.len - HIGH_VALUE_NEG_DATA_OFFSET]);
        \\    }
        \\
        \\    const idx1: u32 = (c >> SHIFT_1) + (BMP_INDEX_LEN - OMITTED_BMP_INDEX_1_LEN);
        \\    var idx3_block: u32 = Trie.index[Trie.index[idx1] + ((c >> SHIFT_2) & INDEX_2_MASK)];
        \\    var idx3: u32 = (c >> SHIFT_3) & INDEX_3_MASK;
        \\    var data_block: u32 = undefined;
        \\    if ((idx3_block & 0x8000) == 0) {
        \\        data_block = Trie.index[idx3_block + idx3];
        \\    } else {
        \\        idx3_block = (idx3_block & 0x7FFF) + (idx3 & ~@as(u32, 7)) + (idx3 >> 3);
        \\        idx3 &= 7;
        \\        data_block = @as(u32, @intCast(Trie.index[idx3_block] << @intCast((2 + (2 * idx3))))) & 0x30000;
        \\        data_block |= Trie.index[idx3_block + idx3];
        \\    }
        \\    return @enumFromInt(Trie.data[data_block + (c & SMALL_DATA_MASK)]);
        \\}
    );

    try outputFile("ucd.zig", buf.items);
}

fn writeCategoryTrie(
    allocator: std.mem.Allocator,
    buf: *std.ArrayList(u8),
    data: UnicodeData,
    comptime category: []const u8,
    comptime trie_name: []const u8,
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

    try writeTrie(buf, trie_name, trie, cats.keys());
}

fn writeBidiBrackets(allocator: std.mem.Allocator, buf: *std.ArrayList(u8), data: UnicodeData) !void {
    const bytes = try downloadFile(allocator, "BidiBrackets.txt");
    defer allocator.free(bytes);

    const brackets = try BidiBrackets.parse(allocator, bytes);
    defer brackets.deinit();

    try buf.appendSlice(
        \\pub const BidiBracket = struct {
        \\    pair: u32,
        \\    dir: Dir,
        \\    mapping: ?u32,
        \\
        \\    pub const Dir = enum {
        \\        open,
        \\        close,
        \\    };
        \\
        \\    pub fn getUtf8(cs: []const u8) !?BidiBracket {
        \\        const c = try std.unicode.utf8Decode(cs);
        \\        return getUtf32(c);
        \\    }
        \\
        \\    pub fn getUtf8AssumeValid(cs: []const u8) ?BidiBracket {
        \\        const c = std.unicode.utf8Decode(cs) catch unreachable;
        \\        return getUtf32(c);
        \\    }
        \\
        \\    pub fn getUtf32(c: u32) ?BidiBracket {
        \\        return switch (c) {
        \\
    );

    for (brackets.entries.items) |entry| {
        try std.fmt.format(buf.writer(),
            \\            0x{X} => BidiBracket{{
            \\                .pair = 0x{X},
            \\                .dir = .{s},
            \\                .mapping = 
        , .{ entry.left, entry.right, @tagName(entry.dir) });

        if (data.mappings.get(entry.left)) |mapping| {
            try std.fmt.format(buf.writer(), "0x{X},\n", .{mapping});
        } else {
            try buf.appendSlice("null,\n");
        }
        try buf.appendSlice("            },\n");
    }

    try buf.appendSlice(
        \\            else => null,
        \\        };
        \\    }
        \\};
        \\
        \\
    );
}

fn writePropertyTrie(
    allocator: std.mem.Allocator,
    buf: *std.ArrayList(u8),
    comptime ucd_path: []const u8,
    comptime trie_name: []const u8,
    extend: ?Property,
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

    try writeTrie(buf, trie_name, trie, property.entries.keys());
}

fn writeTrie(buf: *std.ArrayList(u8), name: []const u8, trie: TrieBuilder.Trie, values: []const []const u8) !void {
    try std.fmt.format(buf.writer(), "pub const {s} = enum {{\n", .{name});

    for (values) |v| {
        try std.fmt.format(buf.writer(), "    {s},\n", .{v});
    }
    try std.fmt.format(buf.writer(),
        \\    None,
        \\    Error,
        \\
        \\    const high_start = 0x{X};
        \\
        \\    const index = [_]u16{{
        \\
    , .{trie.high_start});

    try writeArrayElems(buf, 2, "0x{X}", trie.index);

    try buf.appendSlice(
        \\
        \\    };
        \\
        \\    const data = [_]u8{
        \\
    );

    try writeArrayElems(buf, 2, "{d}", trie.data);

    try std.fmt.format(buf.writer(),
        \\
        \\    }};
        \\
        \\    pub inline fn getUtf8(c: []const u8) !{s} {{
        \\        return trieGetUtf8({s}, c);
        \\    }}
        \\
        \\    pub inline fn getUtf8AssumeValid(c: []const u8) {s} {{
        \\        return trieGetUtf8AssumeValid({s}, c);
        \\    }}
        \\
        \\    pub inline fn getUtf32(c: u32) {s} {{
        \\        return trieGetUtf32({s}, c);
        \\    }}
        \\}};
        \\
        \\
    , .{ name, name, name, name, name, name });
}

fn writeArrayElems(buf: *std.ArrayList(u8), indent: usize, comptime fmt: []const u8, elems: anytype) !void {
    var width: usize = 0;
    for (elems) |e| {
        const size = std.fmt.count(fmt, .{e});
        if (width == 0) {
            try writeIndent(buf, indent);
            width = 4 * indent;
        } else if (width + size + 2 > 120) {
            try buf.append('\n');
            try writeIndent(buf, indent);
            width = 4 * indent;
        } else {
            try buf.append(' ');
            width += 1;
        }

        try std.fmt.format(buf.writer(), fmt, .{e});
        try buf.append(',');
        width += size + 1;
    }
}

fn writeIndent(buf: *std.ArrayList(u8), indent: usize) !void {
    for (0..indent) |_| {
        try buf.appendSlice("    ");
    }
}

fn loadProperty(allocator: std.mem.Allocator, comptime ucd_path: []const u8, filters: []const []const u8) !Property {
    const bytes = try downloadFile(allocator, ucd_path);
    defer allocator.free(bytes);

    var property = Property.init(allocator);
    try property.parse(bytes, filters);

    return property;
}

fn copyFile(allocator: std.mem.Allocator, comptime ucd_path: []const u8, comptime sub_path: []const u8) !void {
    const file_bytes = try downloadFile(allocator, ucd_path);
    defer allocator.free(file_bytes);

    try outputFile(sub_path, file_bytes);
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

fn outputFile(comptime sub_path: []const u8, bytes: []const u8) !void {
    const cwd = std.fs.cwd();

    const file = try cwd.createFile("src/" ++ sub_path, .{ .truncate = true });
    defer file.close();

    try file.writeAll(bytes);
}
