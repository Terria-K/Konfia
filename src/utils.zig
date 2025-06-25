const std = @import("std");

pub fn concat(allocator: *std.mem.Allocator, one: []const u8, two: []const u8) ![]u8 {
    const concat_buffer = try allocator.alloc(u8, one.len + two.len);

    @memcpy(concat_buffer[0..one.len], one);
    @memcpy(concat_buffer[one.len..(one.len + two.len)], two);
    return concat_buffer;
}

pub fn home_path(allocator: *std.mem.Allocator, conf: []const u8) ![]u8 {
    const home = std.posix.getenv("HOME") orelse return error.AppDataDirUnavailable;
    const combined_path = try concat(allocator, home, conf);

    return combined_path;
}

pub inline fn get_home_path() ![]const u8 {
    const home = std.posix.getenv("HOME") orelse return error.AppDataDirUnavailable;
    return home;
}

pub inline fn owned(allocator: std.mem.Allocator, str: anytype) ![]u8 {
    const owned_buffer = try allocator.alloc(u8, str.len);
    @memcpy(owned_buffer, str);
    return owned_buffer;
}