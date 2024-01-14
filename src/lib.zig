pub const GraphemeBreak = @import("GraphemeBreak.zig");
pub const LineBreak = @import("LineBreak.zig");
pub const WordBreak = @import("WordBreak.zig");

pub const bidi = @import("bidi.zig");
pub const ucd = struct {
    pub const trieValue = @import("ucd.zig").trieValue;
};

test {
    _ = @import("bidi.zig");
    _ = @import("GraphemeBreak.zig");
    _ = @import("LineBreak.zig");
    _ = @import("ReverseUtf8Iterator.zig");
    _ = @import("WordBreak.zig");
}
