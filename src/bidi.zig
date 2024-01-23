const std = @import("std");
const ucd = @import("ucd.zig");
const ReverseUtf8Iterator = @import("ReverseUtf8Iterator.zig");

pub const Level = u8;

pub fn stringCats(allocator: std.mem.Allocator, str: []const u8) ![]const ucd.BidiCategory {
    if (!std.unicode.utf8ValidateSlice(str)) {
        return error.InvalidUtf8;
    }

    return try stringCatsAssumeValid(allocator, str);
}

pub fn stringCatsAssumeValid(allocator: std.mem.Allocator, str: []const u8) ![]const ucd.BidiCategory {
    const cats = try allocator.alloc(ucd.BidiCategory, str.len);
    var iter = std.unicode.Utf8Iterator{ .bytes = str, .i = 0 };
    var i: usize = 0;
    while (iter.nextCodepointSlice()) |code_point| {
        cats[i] = switch (ucd.BidiCategory.getUtf8AssumeValid(code_point)) {
            .None => switch (ucd.DerivedBidiProperty.getUtf8AssumeValid(code_point)) {
                .L => .L,
                .R => .R,
                .EN => .EN,
                .ES => .ES,
                .ET => .ET,
                .AN => .AN,
                .CS => .CS,
                .B => .B,
                .S => .S,
                .WS => .WS,
                .ON => .ON,
                .BN => .BN,
                .NSM => .NSM,
                .AL => .AL,
                .LRO => .LRO,
                .RLO => .RLO,
                .LRE => .LRE,
                .RLE => .RLE,
                .PDF => .PDF,
                .LRI => .LRI,
                .RLI => .RLI,
                .FSI => .FSI,
                .PDI => .PDI,
                .None => .None,
                .Error => .Error,
            },
            else => |cat| cat,
        };
        @memset(cats[i..][1..code_point.len], .None);
        i += code_point.len;
    }
    return cats;
}

pub const ParagraphIterator = struct {
    str: []const u8,
    cats: []const ucd.BidiCategory,
    i: usize,

    pub fn init(cats: []const ucd.BidiCategory) ParagraphIterator {
        return ParagraphIterator{
            .cats = cats,
            .i = 0,
        };
    }

    pub fn hasNext(self: *ParagraphIterator) bool {
        return self.i < self.cats.len;
    }

    pub fn next(self: *ParagraphIterator) Level {
        std.debug.assert(self.hasNext());

        var isolate_count: usize = 0;
        var level: ?u8 = null;

        while (self.i < self.str.len) : (self.i += strIndexLen(self.str, self.i)) {
            const cat = self.cats[self.i];
            switch (cat) {
                .B => break,
                .LRI, .RLI, .FSI => isolate_count += 1,
                .PDI => if (isolate_count > 0) {
                    isolate_count -= 1;
                },
                .L => if (level == null and isolate_count == 0) {
                    level = 0;
                },
                .R, .AL => if (level == null and isolate_count == 0) {
                    level = 1;
                },
                else => {},
            }
        }

        return level orelse 0;
    }
};

pub fn reorder(
    allocator: std.mem.Allocator,
    str: []const u8,
    cats: []const ucd.BidiCategory,
    levels: []Level,
    paragraph_level: Level,
) ![]const usize {
    std.debug.assert(str.len > 0);
    std.debug.assert(cats.len == str.len);
    std.debug.assert(levels.len == cats.len);

    {
        var seq_start: ?usize = null;
        var i: usize = 0;
        while (i < str.len) : (i += strIndexLen(str, i)) {
            const cat = cats[i];
            if (ignoreCat(cat)) {
                continue;
            }

            switch (cat) {
                .B, .S => {
                    levels[i] = paragraph_level;
                    if (seq_start) |ss| {
                        @memset(levels[ss..i], paragraph_level);
                    }
                },
                .WS, .RLI, .LRI, .FSI, .PDI => {
                    if (seq_start == null) {
                        seq_start = i;
                    }
                },
                else => {
                    seq_start = null;
                },
            }
        }
        if (seq_start) |ss| {
            @memset(levels[ss..], paragraph_level);
        }
    }

    var min_level = levels[0];
    var max_level = min_level;
    {
        var prev_level = min_level;
        var i: usize = 0;
        while (i < str.len) : (i += strIndexLen(str, i)) {
            if (ignoreCat(cats[i])) {
                continue;
            }
            const level = levels[i];
            if (level != prev_level) {
                min_level = @min(min_level, level);
                max_level = @max(max_level, level);
                prev_level = level;
            }
        }
    }

    var order = std.ArrayList(usize).init(allocator);
    {
        var i: usize = 0;
        while (i < str.len) : (i += strIndexLen(str, i)) {
            if (ignoreCat(cats[i])) {
                continue;
            }
            try order.append(i);
        }
    }

    min_level = if (min_level % 2 == 1) min_level else min_level + 1;

    var level = max_level;
    while (level >= min_level) : (level -= 1) {
        var index: usize = 0;
        var level_start: ?usize = null;
        var i: usize = 0;
        while (i < str.len) : (i += strIndexLen(str, i)) {
            if (ignoreCat(cats[i])) {
                continue;
            }

            if (levels[i] >= level) {
                if (level_start == null) {
                    level_start = index;
                }
            } else if (level_start) |start| {
                std.mem.reverse(usize, order.items[start..index]);
                level_start = null;
            }
            index += 1;
        }
        if (level_start) |start| {
            std.mem.reverse(usize, order.items[start..]);
        }
    }

    return order.toOwnedSlice();
}

pub fn resolve(
    allocator: std.mem.Allocator,
    str: []const u8,
    str_cats: []const ucd.BidiCategory,
    paragraph_level: Level,
) ![]Level {
    std.debug.assert(str_cats.len == str.len);

    const levels = try allocator.alloc(Level, str.len);
    @memset(levels, 0);

    const cats = try allocator.alloc(ucd.BidiCategory, str.len);
    defer allocator.free(cats);
    @memset(levels, 0);

    resolveExplicitTypes(str, str_cats, levels, cats, paragraph_level);

    const sequences = try resolveSequences(allocator, str, levels, cats, paragraph_level);
    defer Sequence.deinitAll(allocator, sequences);

    resolveWeakTypes(str, str_cats, cats, sequences);
    try resolveNeutralTypes(allocator, str, str_cats, cats, sequences);

    resolveImplicitLevels(str, levels, cats, sequences);

    return levels;
}

fn resolveExplicitTypes(
    str: []const u8,
    str_cats: []const ucd.BidiCategory,
    levels: []Level,
    cats: []ucd.BidiCategory,
    paragraph_level: Level,
) void {
    var state: struct {
        levels: []Level,
        cats: []ucd.BidiCategory,
        stack: [stack_size]DirectionalStatus = undefined,
        stack_len: usize = 0,
        overflow_isolate: usize = 0,
        overflow_embedding: usize = 0,
        valid_isolate: usize = 0,

        const max_depth = 125;
        const stack_size = max_depth + 2;

        const DirectionalStatus = struct {
            level: Level,
            override: ?ucd.BidiCategory,
            isolate: bool,
        };

        fn pushEmbedding(self: *@This(), level: Level, override: ?ucd.BidiCategory, i: usize) void {
            if (level <= max_depth and self.overflow_isolate == 0 and self.overflow_embedding == 0) {
                self.push(.{
                    .level = level,
                    .override = override,
                    .isolate = false,
                });
                self.levels[i] = level;
            } else if (self.overflow_isolate == 0) {
                self.overflow_embedding += 1;
            }
        }

        fn pushRLI(self: *@This(), i: usize) void {
            self.set(i, .RLI);
            self.pushIsolate(self.nextOddLevel());
        }

        fn pushLRI(self: *@This(), i: usize) void {
            self.set(i, .LRI);
            self.pushIsolate(self.nextEvenLevel());
        }

        fn pushIsolate(self: *@This(), level: u8) void {
            if (level <= max_depth and self.overflow_isolate == 0 and self.overflow_embedding == 0) {
                self.valid_isolate += 1;
                self.push(.{
                    .level = level,
                    .override = null,
                    .isolate = true,
                });
            } else {
                self.overflow_isolate += 1;
            }
        }

        fn set(self: *@This(), i: usize, cat: ucd.BidiCategory) void {
            const last = self.lastEntry();
            self.levels[i] = last.level;
            self.cats[i] = last.override orelse cat;
        }

        inline fn push(self: *@This(), entry: DirectionalStatus) void {
            self.stack[self.stack_len] = entry;
            self.stack_len += 1;
        }

        fn pop(self: *@This()) DirectionalStatus {
            const last = self.lastEntry();
            self.stack_len -= 1;
            return last;
        }

        fn nextOddLevel(self: *const @This()) Level {
            const level = self.lastLevel() + 1;
            if (level % 2 == 0) {
                return level + 1;
            }
            return level;
        }

        fn nextEvenLevel(self: *const @This()) Level {
            const level = self.lastLevel() + 1;
            if (level % 2 == 1) {
                return level + 1;
            }
            return level;
        }

        fn lastLevel(self: *const @This()) Level {
            return self.lastEntry().level;
        }

        fn lastEntry(self: *const @This()) DirectionalStatus {
            return self.stack[self.stack_len - 1];
        }
    } = .{ .levels = levels, .cats = cats };

    state.push(.{
        .level = paragraph_level,
        .override = null,
        .isolate = false,
    });

    var i: usize = 0;
    while (i < str.len) : (i += strIndexLen(str, i)) {
        const cat = str_cats[i];
        switch (cat) {
            .RLE => {
                state.pushEmbedding(state.nextOddLevel(), null, i);
                cats[i] = .RLE;
            },
            .LRE => {
                state.pushEmbedding(state.nextEvenLevel(), null, i);
                cats[i] = .LRE;
            },
            .RLO => {
                state.pushEmbedding(state.nextOddLevel(), .R, i);
                cats[i] = .RLO;
            },
            .LRO => {
                state.pushEmbedding(state.nextEvenLevel(), .L, i);
                cats[i] = .LRO;
            },
            .PDF => {
                if (state.overflow_isolate > 0) {
                    // do nothing
                } else if (state.overflow_embedding > 0) {
                    state.overflow_embedding -= 1;
                } else {
                    const last = state.lastEntry();
                    if (!last.isolate and state.stack_len >= 2) {
                        _ = state.pop();
                    }
                }
                levels[i] = state.lastEntry().level;
                cats[i] = .PDF;
            },
            .RLI => state.pushRLI(i),
            .LRI => state.pushLRI(i),
            .FSI => {
                var isolate_count: usize = 0;

                var next_i = i;
                next_i += strIndexLen(str, next_i);

                while (next_i < str.len) : (next_i += strIndexLen(str, next_i)) {
                    const next_cat = str_cats[next_i];
                    switch (next_cat) {
                        .RLI, .LRI, .FSI => {
                            isolate_count += 1;
                        },
                        .PDI => {
                            if (isolate_count > 0) {
                                isolate_count -= 1;
                            } else {
                                state.pushLRI(i);
                                break;
                            }
                        },
                        .L => if (isolate_count == 0) {
                            state.pushLRI(i);
                            break;
                        },
                        .R, .AL => if (isolate_count == 0) {
                            state.pushRLI(i);
                            break;
                        },
                        else => continue,
                    }
                } else {
                    state.pushLRI(i);
                }
            },
            .PDI => {
                if (state.overflow_isolate > 0) {
                    state.overflow_isolate -= 1;
                } else if (state.valid_isolate > 0) {
                    state.overflow_embedding = 0;
                    while (true) {
                        const popped = state.pop();
                        if (popped.isolate) {
                            break;
                        }
                    }
                    state.valid_isolate -= 1;
                }
                state.set(i, .PDI);
            },
            .B, .BN => {
                levels[i] = paragraph_level;
                cats[i] = cat;
            },
            else => state.set(i, cat),
        }
    }
}

fn resolveSequences(
    allocator: std.mem.Allocator,
    str: []const u8,
    levels: []const Level,
    cats: []const ucd.BidiCategory,
    paragraph_level: Level,
) ![]const Sequence {
    const SequenceLevelRuns = std.ArrayList(LevelRun);

    var seqs_runs = std.ArrayList(SequenceLevelRuns).init(allocator);
    defer {
        for (seqs_runs.items) |seq_runs| {
            seq_runs.deinit();
        }
        seqs_runs.deinit();
    }

    var stack = std.ArrayList(SequenceLevelRuns).init(allocator);
    defer stack.deinit();

    var iter = LevelRunIterator{ .str = str, .levels = levels, .cats = cats };
    while (iter.next()) |run| {
        const first_cat = cats[run.first];
        const last_cat = cats[run.last];

        var seq = if (first_cat == .PDI and stack.items.len > 0)
            stack.pop()
        else
            SequenceLevelRuns.init(allocator);

        try seq.append(run);

        switch (last_cat) {
            .RLI, .LRI, .FSI => {
                try stack.append(seq);
            },
            else => {
                try seqs_runs.append(seq);
            },
        }
    }

    while (stack.popOrNull()) |seq| {
        try seqs_runs.append(seq);
    }

    var seqs = std.ArrayList(Sequence).init(allocator);
    for (seqs_runs.items) |*seq_runs| {
        const seq_level = seq_runs.items[0].level;
        const seq_first = seq_runs.items[0].first;
        const seq_last = seq_runs.getLast().last;

        const sos_level = blk: {
            var sos_level = paragraph_level;
            if (seq_first != 0) {
                var rev_iter = ReverseUtf8Iterator.init(str[0..seq_first]);
                var i = seq_first;
                while (rev_iter.next()) |code_point| {
                    i -= code_point.len;
                    if (ignoreCat(cats[i])) {
                        continue;
                    }

                    sos_level = levels[i];
                    break;
                }
            }

            break :blk @max(sos_level, levels[seq_first]);
        };
        const sos: ucd.BidiCategory = if (sos_level % 2 == 0) .L else .R;

        const eos_level = blk: {
            var eos_level: Level = paragraph_level;
            switch (cats[seq_last]) {
                .RLI, .LRI, .FSI => {
                    // if the sequence ends with an isolate initiator we leave `eos_level` same as `paragraph_level`.
                },
                else => {
                    // else compare with the next non-ignored character in the whole paragraph text.
                    var i = seq_last;
                    i += strIndexLen(str, i);

                    while (i < str.len) : (i += strIndexLen(str, i)) {
                        if (ignoreCat(cats[i])) {
                            continue;
                        }

                        eos_level = levels[i];
                        break;
                    }
                },
            }

            break :blk @max(eos_level, levels[seq_last]);
        };
        const eos: ucd.BidiCategory = if (eos_level % 2 == 0) .L else .R;

        try seqs.append(Sequence{
            .level = seq_level,
            .runs = try seq_runs.toOwnedSlice(),
            .sos = sos,
            .eos = eos,
        });
    }

    return try seqs.toOwnedSlice();
}

const LevelRunIterator = struct {
    str: []const u8,
    levels: []const Level,
    cats: []const ucd.BidiCategory,
    i: usize = 0,

    fn next(self: *LevelRunIterator) ?LevelRun {
        if (self.i >= self.str.len) {
            return null;
        }

        var first = self.i;
        while (first < self.str.len) : (first += strIndexLen(self.str, self.i)) {
            if (!ignoreCat(self.cats[first])) {
                break;
            }
        }

        if (first >= self.str.len) {
            self.i = self.str.len;
            return null;
        }

        const level: u8 = self.levels[first];

        var i = first;
        var last = i;
        while (i < self.str.len) : (i += strIndexLen(self.str, i)) {
            if (ignoreCat(self.cats[i])) {
                continue;
            }

            if (self.levels[i] != level) {
                break;
            }

            last = i;
        }

        self.i = last + strIndexLen(self.str, last);

        return LevelRun{
            .level = level,
            .first = first,
            .last = last,
        };
    }
};

fn resolveWeakTypes(
    str: []const u8,
    str_cats: []const ucd.BidiCategory,
    cats: []ucd.BidiCategory,
    sequences: []const Sequence,
) void {
    var state: struct {
        str: []const u8,
        str_cats: []const ucd.BidiCategory,
        cats: []ucd.BidiCategory,
        seq: Sequence,
        strong_type: ucd.BidiCategory,
        et_seq_start: ?Sequence.Pos = null,

        fn next(self: *@This(), cat: ucd.BidiCategory, pos: Sequence.Pos) void {
            var reset_et_seq_start = true;
            switch (cat) {
                .NSM => {
                    var p_cat: ?ucd.BidiCategory = null;
                    var p_pos = pos;
                    while (p_pos.prev(self.str, self.seq, self.cats)) |p| {
                        const c = self.str_cats[p.ii];
                        if (c != .NSM) {
                            p_cat = c;
                            break;
                        }

                        p_pos = p;
                    }
                    if (p_cat) |c| {
                        switch (c) {
                            .RLI, .LRI, .FSI, .PDI => {
                                self.cats[pos.ii] = .ON;
                            },
                            else => {
                                self.cats[pos.ii] = c;
                                self.next(c, pos);
                                // this will have been handled by the call above
                                reset_et_seq_start = false;
                            },
                        }
                    } else {
                        self.cats[pos.ii] = self.seq.sos;
                        self.strong_type = self.seq.sos;
                    }
                },
                .R, .L => {
                    self.strong_type = cat;
                },
                .AL => {
                    self.strong_type = .AL;
                    self.cats[pos.ii] = .R;
                },
                .EN => {
                    if (self.strong_type == .AL) {
                        self.cats[pos.ii] = .AN;
                        self.checkCSBetweenAN(pos);
                    } else {
                        if (pos.prev(self.str, self.seq, self.cats)) |p| {
                            const p_cat = self.str_cats[p.ii];
                            if (p_cat == .CS or p_cat == .ES) {
                                if (p.prev(self.str, self.seq, self.cats)) |pp| {
                                    if (self.treatAsEn(pp, false)) {
                                        self.cats[p.ii] = if (self.strong_type == .L) .L else .EN;
                                    }
                                }
                            }
                        }

                        if (self.et_seq_start) |ess| {
                            for (ess.ri..(pos.ri + 1)) |ri| {
                                const first = if (ri == ess.ri) ess.ii else self.seq.runs[ri].first;
                                const last = if (ri == pos.ri) pos.ii else self.seq.runs[ri].last;
                                var ii = first;
                                while (ii <= last) : (ii += strIndexLen(self.str, ii)) {
                                    if (ignoreCat(self.cats[ii])) {
                                        continue;
                                    }

                                    self.cats[ii] = if (self.strong_type == .L) .L else .EN;
                                }
                            }
                        }

                        if (self.strong_type == .L) {
                            self.cats[pos.ii] = .L;
                        }
                    }
                },
                .AN => {
                    self.checkCSBetweenAN(pos);
                },
                .ET => {
                    self.cats[pos.ii] = .ON;
                    const p = pos.prev(self.str, self.seq, self.cats);
                    if (p != null and self.treatAsEn(p.?, true)) {
                        self.cats[pos.ii] = if (self.strong_type == .L) .L else .EN;
                    } else {
                        if (self.et_seq_start == null) {
                            self.et_seq_start = pos;
                        }
                        reset_et_seq_start = false;
                    }
                },
                .ES, .CS => {
                    self.cats[pos.ii] = .ON;
                },
                else => {
                    // do nothing
                },
            }
            if (reset_et_seq_start) {
                self.et_seq_start = null;
            }
        }

        fn checkCSBetweenAN(self: @This(), pos: Sequence.Pos) void {
            if (pos.prev(self.str, self.seq, self.cats)) |p| {
                if (self.str_cats[p.ii] == .CS) {
                    if (p.prev(self.str, self.seq, self.cats)) |pp| {
                        if (self.cats[pp.ii] == .AN) {
                            self.cats[p.ii] = .AN;
                        }
                    }
                }
            }
        }

        fn treatAsEn(self: @This(), pos: Sequence.Pos, include_et: bool) bool {
            return switch (self.cats[pos.ii]) {
                .EN => if (!include_et) self.str_cats[pos.ii] != .ET else true,
                .L => switch (self.str_cats[pos.ii]) {
                    .EN, .ET => true,
                    .NSM => if (pos.prev(self.str, self.seq, self.cats)) |p| self.str_cats[p.ii] == .EN else false,
                    else => false,
                },
                else => false,
            };
        }
    } = undefined;

    for (sequences) |seq| {
        state = .{ .str = str, .str_cats = str_cats, .cats = cats, .seq = seq, .strong_type = seq.sos };
        for (seq.runs, 0..) |run, ri| {
            var ii = run.first;
            while (ii <= run.last) : (ii += strIndexLen(str, ii)) {
                const cat = cats[ii];
                if (ignoreCat(cat)) {
                    continue;
                }

                state.next(cat, Sequence.Pos{
                    .ri = ri,
                    .ii = ii,
                });
            }
        }
    }
}

fn resolveNeutralTypes(
    allocator: std.mem.Allocator,
    str: []const u8,
    str_cats: []const ucd.BidiCategory,
    cats: []ucd.BidiCategory,
    sequences: []const Sequence,
) !void {
    for (sequences) |seq| {
        const e: ucd.BidiCategory = if (seq.level % 2 == 0) .L else .R;

        const pairs = try resolveBracketPairs(allocator, str, cats, seq);
        defer allocator.free(pairs);

        outer: for (pairs) |pair| {
            var strong_type: ?ucd.BidiCategory = null;
            for (pair.open.ri..(pair.close.ri + 1)) |ri| {
                const first = if (ri == pair.open.ri) pair.open.ii else seq.runs[ri].first;
                const last = if (ri == pair.close.ri) pair.close.ii else seq.runs[ri].last;

                var ii = first;
                while (ii <= last) : (ii += strIndexLen(str, ii)) {
                    var cat = cats[ii];
                    if (ignoreCat(cat)) {
                        continue;
                    }

                    if (cat == .EN or cat == .AN) {
                        cat = .R;
                    }

                    if (cat == e) {
                        cats[pair.open.ii] = e;
                        cats[pair.close.ii] = e;
                        checkNSMAfterPairedBracket(seq, pair.open, str, str_cats, cats, e);
                        checkNSMAfterPairedBracket(seq, pair.close, str, str_cats, cats, e);
                        continue :outer;
                    }

                    if (cat == .L or cat == .R) {
                        strong_type = cat;
                    }
                }
            }

            if (strong_type == null) {
                continue;
            }

            const context: ucd.BidiCategory = ctx: {
                var ri = pair.open.ri;
                var ii = pair.open.ii;
                if (ii == 0) {
                    break :ctx seq.sos;
                }

                ii = prevStrIndex(str, ii);
                while (true) {
                    while (ii >= seq.runs[ri].first) {
                        switch (cats[ii]) {
                            .L, .R => |cat| break :ctx cat,
                            .EN, .AN => break :ctx .R,
                            else => {},
                        }

                        if (ii > 0) {
                            ii = prevStrIndex(str, ii);
                        } else {
                            break;
                        }
                    }

                    if (ri > 0) {
                        ri -= 1;
                        ii = seq.runs[ri].last;
                    } else {
                        break :ctx seq.sos;
                    }
                }
            };

            const new_cat = if (context == strong_type.?) context else e;
            cats[pair.open.ii] = new_cat;
            cats[pair.close.ii] = new_cat;
            checkNSMAfterPairedBracket(seq, pair.open, str, str_cats, cats, new_cat);
            checkNSMAfterPairedBracket(seq, pair.close, str, str_cats, cats, new_cat);
        }

        var prev_index: ?usize = null;
        var ni_seq_ctx: ?ucd.BidiCategory = null;
        var ni_seq_start: ?Sequence.Pos = null;
        for (seq.runs, 0..) |run, ri| {
            var ii = run.first;
            while (ii <= run.last) : (ii += strIndexLen(str, ii)) {
                const cat = cats[ii];
                if (ignoreCat(cat)) {
                    continue;
                }

                const prev = prev_index;
                prev_index = ii;

                switch (cat) {
                    .B, .S, .WS, .ON, .FSI, .LRI, .RLI, .PDI => {
                        cats[ii] = e;
                        if (ni_seq_start != null) {
                            continue;
                        }

                        if (prev) |p| {
                            switch (cats[p]) {
                                .L, .R => {
                                    ni_seq_ctx = cats[p];
                                },
                                .EN, .AN => {
                                    ni_seq_ctx = .R;
                                },
                                else => continue,
                            }
                        } else {
                            ni_seq_ctx = seq.sos;
                        }
                        ni_seq_start = Sequence.Pos{
                            .ri = ri,
                            .ii = ii,
                        };
                    },
                    .L, .R, .AN, .EN => {
                        if (ni_seq_start) |start| {
                            const context = if (cat == .AN or cat == .EN) .R else cat;
                            if (ni_seq_ctx.? == context) {
                                Sequence.setRange(seq, start, Sequence.Pos{ .ri = ri, .ii = prev.? }, str, cats, context);
                            }

                            ni_seq_ctx = null;
                            ni_seq_start = null;
                        }
                    },
                    else => {
                        ni_seq_ctx = null;
                        ni_seq_start = null;
                    },
                }
            }
        }

        if (ni_seq_start) |start| {
            if (ni_seq_ctx.? == seq.eos) {
                const last_ri = seq.runs.len - 1;
                const last_ii = seq.runs[last_ri].last;
                Sequence.setRange(seq, start, Sequence.Pos{ .ri = last_ri, .ii = last_ii }, str, cats, seq.eos);
            }
        }
    }
}

fn resolveBracketPairs(
    allocator: std.mem.Allocator,
    str: []const u8,
    cats: []const ucd.BidiCategory,
    seq: Sequence,
) ![]const BracketPair {
    const stack_size = 63;
    var stack: [stack_size]struct {
        bracket: ucd.BidiBracket,
        pos: Sequence.Pos,
    } = undefined;
    var stack_len: usize = 0;
    var pairs = std.ArrayList(BracketPair).init(allocator);

    outer: for (seq.runs, 0..) |run, ri| {
        var ii = run.first;
        while (ii <= run.last) : (ii += strIndexLen(str, ii)) {
            const cat = cats[ii];
            if (ignoreCat(cat)) {
                continue;
            }

            // only .ON characters can be a paired bracket
            if (cat != .ON) {
                continue;
            }

            const code_point = std.unicode.utf8Decode(str[ii..][0..strIndexLen(str, ii)]) catch unreachable;

            if (ucd.BidiBracket.getUtf32(code_point)) |bracket| {
                switch (bracket.dir) {
                    .open => {
                        if (stack_len >= stack_size) {
                            break :outer;
                        }
                        stack[stack_len] = .{
                            .bracket = bracket,
                            .pos = Sequence.Pos{
                                .ri = ri,
                                .ii = ii,
                            },
                        };
                        stack_len += 1;
                    },
                    .close => {
                        var si = stack_len;
                        while (si > 0) : (si -= 1) {
                            const entry = stack[si - 1];

                            var matches = entry.bracket.pair == code_point;
                            if (!matches) {
                                if (entry.bracket.mapping) |mapping| {
                                    if (ucd.BidiBracket.getUtf32(mapping)) |mb| {
                                        matches = mb.pair == code_point;
                                    }
                                }
                            }

                            if (matches) {
                                try pairs.append(BracketPair{
                                    .open = entry.pos,
                                    .close = Sequence.Pos{
                                        .ri = ri,
                                        .ii = ii,
                                    },
                                });
                                stack_len = si - 1;
                                break;
                            }
                        }
                    },
                }
            }
        }
    }

    std.mem.sort(
        BracketPair,
        pairs.items,
        @as(void, undefined),
        struct {
            fn lessThan(_: void, lhs: BracketPair, rhs: BracketPair) bool {
                return lhs.open.ii < rhs.open.ii;
            }
        }.lessThan,
    );

    return try pairs.toOwnedSlice();
}

const BracketPair = struct {
    open: Sequence.Pos,
    close: Sequence.Pos,
};

fn checkNSMAfterPairedBracket(
    seq: Sequence,
    pos: Sequence.Pos,
    str: []const u8,
    str_cats: []const ucd.BidiCategory,
    cats: []ucd.BidiCategory,
    cat: ucd.BidiCategory,
) void {
    var ri = pos.ri;
    var ii = pos.ii + strIndexLen(str, pos.ii);
    while (true) {
        while (ii <= seq.runs[ri].last) : (ii += strIndexLen(str, ii)) {
            const c = str_cats[ii];
            if (ignoreCat(c)) {
                continue;
            }

            switch (c) {
                .NSM => {
                    cats[ii] = cat;
                },
                else => return,
            }
        }

        ri += 1;
        if (ri < seq.runs.len) {
            ii = seq.runs[ri].first;
        } else {
            break;
        }
    }
}

fn resolveImplicitLevels(str: []const u8, levels: []Level, cats: []const ucd.BidiCategory, sequences: []const Sequence) void {
    for (sequences) |seq| {
        for (seq.runs) |run| {
            var ii = run.first;
            while (ii <= run.last) : (ii += strIndexLen(str, ii)) {
                if (seq.level % 2 == 0) {
                    switch (cats[ii]) {
                        .R => {
                            levels[ii] += 1;
                        },
                        .AN, .EN => {
                            levels[ii] += 2;
                        },
                        else => continue,
                    }
                } else {
                    switch (cats[ii]) {
                        .L, .EN, .AN => {
                            levels[ii] += 1;
                        },
                        else => continue,
                    }
                }
            }
        }
    }
}

const Sequence = struct {
    level: Level,
    runs: []const LevelRun,
    sos: ucd.BidiCategory,
    eos: ucd.BidiCategory,

    const Pos = struct {
        ri: usize,
        ii: usize,

        fn prev(self: Pos, str: []const u8, seq: Sequence, cats: []const ucd.BidiCategory) ?Pos {
            var pos = self;
            while (pos.nextPrev(str, seq)) |p| {
                if (ignoreCat(cats[p.ii])) {
                    pos = p;
                    continue;
                }

                return p;
            }
            return null;
        }

        fn nextPrev(self: Pos, str: []const u8, seq: Sequence) ?Pos {
            if (self.ii > seq.runs[self.ri].first) {
                var rev_iter = ReverseUtf8Iterator.init(str[0..self.ii]);
                // this is safe because `self.ii` > `seq.runs[self.ri].first` >= 0
                const prev_code_point = rev_iter.next().?;
                return Pos{
                    .ri = self.ri,
                    .ii = self.ii - prev_code_point.len,
                };
            }

            if (self.ri > 0) {
                const prev_ri = self.ri - 1;
                return Pos{
                    .ri = prev_ri,
                    .ii = seq.runs[prev_ri].last,
                };
            }

            return null;
        }
    };

    fn setRange(
        seq: Sequence,
        start: Sequence.Pos,
        end: Sequence.Pos,
        str: []const u8,
        cats: []ucd.BidiCategory,
        cat: ucd.BidiCategory,
    ) void {
        for (start.ri..(end.ri + 1)) |ri| {
            const first_ii = if (ri == start.ri) start.ii else seq.runs[ri].first;
            const last_ii = if (ri == end.ri) end.ii else seq.runs[ri].last;
            var ii = first_ii;
            while (ii <= last_ii) : (ii += strIndexLen(str, ii)) {
                if (ignoreCat(cats[ii])) {
                    continue;
                }
                cats[ii] = cat;
            }
        }
    }

    fn deinitAll(allocator: std.mem.Allocator, sequences: []const Sequence) void {
        for (sequences) |seq| {
            allocator.free(seq.runs);
        }
        allocator.free(sequences);
    }
};

const LevelRun = struct {
    level: Level,

    // first byte of first code point in run
    first: usize,

    // first byte of last code point in run
    last: usize,
};

inline fn ignoreCat(cat: ucd.BidiCategory) bool {
    return switch (cat) {
        .RLE, .LRE, .RLO, .LRO, .PDF, .BN => true,
        else => false,
    };
}

fn prevStrIndex(str: []const u8, i: usize) usize {
    var iter = ReverseUtf8Iterator.init(str[0..i]);
    const prev = iter.next().?;
    return i - prev.len;
}

inline fn strIndexLen(str: []const u8, i: usize) usize {
    return std.unicode.utf8ByteSequenceLength(str[i]) catch unreachable;
}

test "BidiTest" {
    const test_data = @embedFile("ucd_test/BidiTest.txt");
    const allocator = std.testing.allocator;

    var levels = std.ArrayList(?Level).init(allocator);
    defer levels.deinit();

    var order = std.ArrayList(usize).init(allocator);
    defer order.deinit();

    var str = std.ArrayList(u8).init(allocator);
    defer str.deinit();

    var line_num: usize = 1;
    var lines = std.mem.splitScalar(u8, test_data, '\n');
    while (lines.next()) |line| : (line_num += 1) {
        if (line.len == 0 or line[0] == '#') {
            continue;
        }
        errdefer {
            std.debug.print("Line: {d}\n", .{line_num});
        }

        if (line[0] == '@') {
            var info_split = std.mem.splitScalar(u8, line[1..], ':');
            const info_type = info_split.next().?;
            const info = std.mem.trim(u8, info_split.next().?, " \t");
            if (std.mem.eql(u8, info_type, "Levels")) {
                levels.clearRetainingCapacity();
                var levels_iter = std.mem.splitScalar(u8, info, ' ');
                while (levels_iter.next()) |level| {
                    if (level[0] == 'x') {
                        try levels.append(null);
                    } else {
                        try levels.append(try std.fmt.parseInt(u8, level, 10));
                    }
                }
            } else if (std.mem.eql(u8, info_type, "Reorder")) {
                order.clearRetainingCapacity();
                var reordered_iter = std.mem.splitScalar(u8, info, ' ');
                while (reordered_iter.next()) |index| {
                    if (index.len == 0) {
                        continue;
                    }
                    try order.append(try std.fmt.parseInt(Level, index, 10));
                }
            } else {
                return error.UnexpectedBidiTestInfoType;
            }
            continue;
        }

        var data_split = std.mem.splitScalar(u8, line, ';');
        const cats_data = std.mem.trim(u8, data_split.next().?, " \t");
        const paragraphs_data = std.mem.trim(u8, data_split.next().?, " \t");

        str.clearRetainingCapacity();
        var cats_iter = std.mem.splitScalar(u8, cats_data, ' ');
        while (cats_iter.next()) |cat| {
            var out: [4]u8 = undefined;
            const out_str = catStrToStr(cat, &out);
            try str.appendSlice(out_str);
        }

        const cats = stringCats(allocator, str.items) catch |e| {
            std.debug.print("\nFAILED BIDI STRING CATS\n", .{});
            return e;
        };
        defer allocator.free(cats);

        const auto: u8 = 1;
        const ltr: u8 = 2;
        const rtl: u8 = 4;
        const paragraphs = try std.fmt.parseInt(u8, paragraphs_data, 10);
        if (paragraphs & auto != 0) {
            const paragraph_level = resolveParagraphLevel(cats);
            try expectLevelsAndReorder(paragraph_level, str.items, cats, levels.items, order.items);
        }
        if (paragraphs & ltr != 0) {
            try expectLevelsAndReorder(0, str.items, cats, levels.items, order.items);
        }
        if (paragraphs & rtl != 0) {
            try expectLevelsAndReorder(1, str.items, cats, levels.items, order.items);
        }
    }
}

fn resolveParagraphLevel(cats: []const ucd.BidiCategory) Level {
    var isolate_count: usize = 0;
    for (cats) |cat| {
        switch (cat) {
            .B => {
                break;
            },
            .LRI, .RLI, .FSI => {
                isolate_count += 1;
            },
            .PDI => if (isolate_count > 0) {
                isolate_count -= 1;
            },
            .L => if (isolate_count == 0) {
                return 0;
            },
            .R, .AL => if (isolate_count == 0) {
                return 1;
            },
            else => {},
        }
    }

    return 0;
}

test "BidiCharacterTest" {
    const test_data = @embedFile("ucd_test/BidiCharacterTest.txt");
    const allocator = std.testing.allocator;

    var str = std.ArrayList(u8).init(allocator);
    defer str.deinit();

    var levels = std.ArrayList(?Level).init(allocator);
    defer levels.deinit();

    var order = std.ArrayList(usize).init(allocator);
    defer order.deinit();

    var lines = std.mem.splitScalar(u8, test_data, '\n');
    var line_num: usize = 1;
    while (lines.next()) |line| : (line_num += 1) {
        if (line.len == 0 or line[0] == '#') {
            continue;
        }
        errdefer {
            std.debug.print("Line: {d}\n", .{line_num});
        }

        var data_split = std.mem.splitScalar(u8, std.mem.trim(u8, line, " \t"), ';');

        const code_point_data = data_split.next().?;
        _ = data_split.next().?;
        const paragraph_level_data = data_split.next().?;
        const levels_data = data_split.next().?;
        const order_data = data_split.next().?;

        var code_point_iter = std.mem.splitScalar(u8, code_point_data, ' ');
        while (code_point_iter.next()) |code_point_str| {
            const code_point = try std.fmt.parseInt(u21, code_point_str, 16);

            var out_str: [4]u8 = undefined;
            const out_len = try std.unicode.utf8Encode(code_point, &out_str);

            try str.appendSlice(out_str[0..out_len]);
        }

        const cats = try stringCats(allocator, str.items);
        defer allocator.free(cats);

        const paragraph_level = try std.fmt.parseInt(Level, paragraph_level_data, 10);

        var levels_iter = std.mem.splitScalar(u8, levels_data, ' ');
        while (levels_iter.next()) |level_str| {
            if (level_str[0] == 'x') {
                try levels.append(null);
            } else {
                const level = try std.fmt.parseInt(Level, level_str, 10);
                try levels.append(level);
            }
        }

        var order_iter = std.mem.splitScalar(u8, order_data, ' ');
        while (order_iter.next()) |idx_str| {
            if (idx_str.len == 0) {
                continue;
            }
            const idx = try std.fmt.parseInt(usize, idx_str, 10);
            try order.append(idx);
        }

        try expectLevelsAndReorder(paragraph_level, str.items, cats, levels.items, order.items);

        str.clearRetainingCapacity();
        levels.clearRetainingCapacity();
        order.clearRetainingCapacity();
    }
}

fn expectLevelsAndReorder(
    paragraph_level: Level,
    str: []const u8,
    cats: []const ucd.BidiCategory,
    expected_levels: []const ?Level,
    expected_order: []const usize,
) !void {
    errdefer {
        debugPrintStrElems("Original cats", str, cats);
    }

    const actual_levels = resolve(std.testing.allocator, str, cats, paragraph_level) catch |e| {
        std.debug.print("\nFAILED BIDI RESOLVE\n", .{});
        return e;
    };
    defer std.testing.allocator.free(actual_levels);
    errdefer {
        debugPrintElems("Expected levels", expected_levels);
        debugPrintStrElems("Actual levels", str, actual_levels);
    }

    std.testing.expectEqual(str.len, actual_levels.len) catch |e| {
        std.debug.print("\nFAILED BIDI LEVELS LEN\n", .{});
        return e;
    };

    const actual_order = reorder(std.testing.allocator, str, cats, actual_levels, paragraph_level) catch |e| {
        std.debug.print("\nFAILED BIDI REORDER\n", .{});
        return e;
    };
    defer std.testing.allocator.free(actual_order);
    errdefer {
        debugPrintElems("Expected order", expected_order);
        debugPrintElems("Actual order", actual_order);
    }

    std.testing.expectEqual(expected_order.len, actual_order.len) catch |e| {
        std.debug.print("\nFAILED BIDI ORDER LEN\n", .{});
        return e;
    };

    {
        var actual_i: usize = 0;
        for (expected_levels) |expected| {
            const actual = actual_levels[actual_i];
            if (expected) |exp| {
                std.testing.expectEqual(exp, actual) catch |e| {
                    std.debug.print("\nFAILED BIDI LEVEL CASE\n", .{});
                    return e;
                };
            }
            actual_i += strIndexLen(str, actual_i);
        }

        std.testing.expectEqual(actual_levels.len, actual_i) catch |e| {
            std.debug.print("\nFAILED BIDI EXPECTED_I CASE\n", .{});
            return e;
        };
    }

    {
        for (expected_order, 0..) |expected, i| {
            const actual = actual_order[i];
            var excess: usize = 0;
            var str_i: usize = 0;
            while (str_i < actual) {
                const len = strIndexLen(str, str_i);
                excess += len - 1;
                str_i += strIndexLen(str, str_i);
            }
            std.testing.expectEqual(expected, actual - excess) catch |e| {
                std.debug.print("\nFAILED BIDI ORDER CASE\n", .{});
                return e;
            };
        }
    }
}

fn debugPrintElems(context: []const u8, elems: anytype) void {
    std.debug.print("{s}: .{{", .{context});

    for (elems, 0..) |e, i| {
        if (i > 0) {
            std.debug.print(", ", .{});
        }
        if (@typeInfo(@TypeOf(e)) == .Optional) {
            std.debug.print("{}->{?}", .{ i, e });
        } else if (@typeInfo(@TypeOf(e)) == .Enum) {
            std.debug.print("{}->{s}", .{ i, @tagName(e) });
        } else {
            std.debug.print("{}->{}", .{ i, e });
        }
    }

    std.debug.print("}}\n", .{});
}

fn debugPrintStrElems(context: []const u8, str: []const u8, elems: anytype) void {
    std.debug.print("{s}: .{{", .{context});

    var i: usize = 0;
    while (i < str.len) : (i += strIndexLen(str, i)) {
        const e = elems[i];
        const ei = calcElementI(str, i);

        if (ei > 0) {
            std.debug.print(", ", .{});
        }
        if (@typeInfo(@TypeOf(e)) == .Optional) {
            std.debug.print("{}->{?}", .{ ei, e });
        } else if (@typeInfo(@TypeOf(e)) == .Enum) {
            std.debug.print("{}->{s}", .{ ei, @tagName(e) });
        } else {
            std.debug.print("{}->{}", .{ ei, e });
        }
    }

    std.debug.print("}}\n", .{});
}

fn debugPrintSequences(str: []const u8, seqs: []const Sequence) void {
    std.debug.print("Sequences: .{{", .{});

    for (seqs, 0..) |seq, i| {
        if (i > 0) {
            std.debug.print(", ", .{});
        }

        std.debug.print("[({s},{s},{d}), ", .{ @tagName(seq.sos), @tagName(seq.eos), seq.level });
        for (seq.runs, 0..) |run, ri| {
            if (ri > 0) {
                std.debug.print(", ", .{});
            }
            const start = calcElementI(str, run.first);
            const end = calcElementI(str, run.last) + 1;
            std.debug.print("({d},{d},{d})", .{ start, end, run.level });
        }
        std.debug.print("]", .{});
    }

    std.debug.print("}}\n", .{});
}

fn debugPrintPairs(str: []const u8, pairs: []const BracketPair) void {
    std.debug.print("Bracket pairs: .{{", .{});

    for (pairs, 0..) |pair, i| {
        if (i > 0) {
            std.debug.print(", ", .{});
        }

        const open_ii = calcElementI(str, pair.open.ii);
        const close_ii = calcElementI(str, pair.close.ii);
        std.debug.print("[({d},{d}), ({d},{d})]", .{ pair.open.ri, open_ii, pair.close.ri, close_ii });
    }

    std.debug.print("}}\n", .{});
}

fn calcElementI(str: []const u8, i: usize) usize {
    var ei: usize = 0;
    var ii: usize = 0;
    while (ii < i) {
        ii += strIndexLen(str, ii);
        ei += 1;
    }
    return ei;
}

fn catStrToStr(cat_str: []const u8, out: []u8) []const u8 {
    inline for (std.meta.tags(ucd.BidiCategory)) |tag| {
        if (std.mem.eql(u8, cat_str, @tagName(tag))) {
            return catToStr(tag, out);
        }
    }
    @panic("invalid cat str");
}

fn catToStr(cat: ucd.BidiCategory, out: []u8) []const u8 {
    const code_point: u21 = switch (cat) {
        .AL => '\u{060B}',
        .AN => '\u{0605}',
        .B => '\u{000A}',
        .BN => '\u{2060}',
        .CS => '\u{2044}',
        .EN => '\u{06F9}',
        .ES => '\u{208B}',
        .ET => '\u{20CF}',
        .FSI => '\u{2068}',
        .L => '\u{02B8}',
        .LRE => '\u{202A}',
        .LRI => '\u{2066}',
        .LRO => '\u{202D}',
        .NSM => '\u{0300}',
        .ON => '\u{03F6}',
        .PDF => '\u{202C}',
        .PDI => '\u{2069}',
        .R => '\u{0590}',
        .RLE => '\u{202B}',
        .RLI => '\u{2067}',
        .RLO => '\u{202E}',
        .S => '\u{001F}',
        .WS => '\u{200A}',
        else => @panic("invalid cat"),
    };

    const len = std.unicode.utf8Encode(code_point, out) catch unreachable;
    const str = out[0..len];

    return str;
}
