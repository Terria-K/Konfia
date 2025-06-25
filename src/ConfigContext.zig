const c = @import("constants.zig");
const std = @import("std");
const utils = @import("utils.zig");
const ConfigContext = @This();

allocator: *std.mem.Allocator,
share_entries: std.ArrayList([]u8),
home_entries: std.ArrayList([]u8),
config_entries: std.ArrayList([]u8),

pub fn init(allocator: *std.mem.Allocator) ConfigContext {
    return .{
        .allocator = allocator,
        .share_entries = std.ArrayList([]u8).init(allocator.*),
        .home_entries = std.ArrayList([]u8).init(allocator.*),
        .config_entries = std.ArrayList([]u8).init(allocator.*)
    };
}

pub fn save(self: *ConfigContext) !void {
    const json = JsonInterpretation {
        .share_entries = self.share_entries.items,
        .home_entries = self.home_entries.items,
        .config_entries = self.config_entries.items
    };

    const json_str = try std.json.stringifyAlloc(self.allocator.*, json, .{.whitespace = .indent_2 });
    defer self.allocator.free(json_str);

    var file = try std.fs.cwd().createFile(c.saves_dir ++ "/conf.json", .{});
    defer file.close();

    try file.writeAll(json_str);
}

pub fn deinit(self: *ConfigContext) void {
    for (self.config_entries.items) |entry| {
        self.allocator.free(entry);
    } 

    for (self.share_entries.items) |entry| {
        self.allocator.free(entry);
    }

    for (self.home_entries.items) |entry| {
        self.allocator.free(entry);
    }

    self.share_entries.deinit();
    self.home_entries.deinit();
    self.config_entries.deinit();
}

pub const EntryType = enum {
    config,
    share,
    home
};

pub fn track(self: *ConfigContext, path: anytype, comptime t: EntryType) !void {
    // we need to own the path, so we just re-allocate it
    const p = try utils.owned(self.allocator.*, path);

    switch (t) {
        .config => try self.config_entries.append(p),
        .share => try self.share_entries.append(p),
        .home => try self.home_entries.append(p),
    }
}

const JsonInterpretation = struct {
    share_entries: [][]u8,
    home_entries: [][]u8,
    config_entries: [][]u8
};