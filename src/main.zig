const c = @import("constants.zig");
const std = @import("std");
const Exporter = @import("Exporter.zig");
const ConfigContext = @import("ConfigContext.zig");
const utils = @import("utils.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    var argsIterator = try std.process.ArgIterator.initWithAllocator(allocator);
    defer argsIterator.deinit();

    _ = argsIterator.skip();

    while (argsIterator.next()) |n| {
        if (std.mem.eql(u8, n, "--export")) {
            const name = argsIterator.next(); // name

            if (name) |na| {
                try export_config(&allocator, na);
            }
            else {
                std.log.err("Please input a name after '--export'.", .{});
            }
        }
        else if (std.mem.eql(u8, n, "--import")) {
            const path = argsIterator.next();

            if (path) |p| {
                try import(&allocator, p);
            }
            else {
                std.log.err("Please input a file path after '--import'.", .{});
            }
        }
    }
}


fn import(allocator: *std.mem.Allocator, filepath: []const u8) !void {
    const compressed_file = std.fs.cwd().openFile(filepath, .{}) catch |err| {
        if (err == std.fs.File.OpenError.FileNotFound) {
            std.log.err("Specified file path: {s} not found.", .{filepath});
            return;
        } else {
            return err;
        }
    };

    std.log.info("Decompressing '{s}'", .{filepath});

    defer compressed_file.close();

    var arr = std.ArrayList(u8).init(allocator.*);
    defer arr.deinit();

    const file_name_buffer = try allocator.alloc(u8, std.fs.max_path_bytes);
    const link_name_buffer = try allocator.alloc(u8, std.fs.max_path_bytes);

    defer allocator.free(file_name_buffer);
    defer allocator.free(link_name_buffer);

    var decompressor = std.compress.gzip.decompressor(compressed_file.reader());

    var iter = std.tar.iterator(decompressor.reader(), .{
        .file_name_buffer = file_name_buffer,
        .link_name_buffer = link_name_buffer
    });


    while (try iter.next()) |i| {
        const len = i.name.len - 8;
        const buff = try allocator.alloc(u8, len);
        defer allocator.free(buff);

        _ = std.mem.replace(u8, i.name, c.saves_dir ++ "/", "", buff);

        std.log.info("'{s}'", .{buff});

        const home = try utils.get_home_path();
        var splitter = std.mem.splitSequence(u8, buff, "/");

        var extendable_path = try allocator.alloc(u8, home.len);
        defer allocator.free(extendable_path);
        @memcpy(extendable_path, home);

        while (splitter.next()) |s| {
            if (splitter.index == null) {
                continue;
            }

            const extended = try std.fs.path.join(allocator.*, &.{
                extendable_path, s
            });

            std.fs.makeDirAbsolute(extended) catch |err| {
                if (err != std.fs.Dir.MakeError.PathAlreadyExists) {
                    return err;
                }
            };

            allocator.free(extendable_path);
            extendable_path.ptr = extended.ptr;
            extendable_path.len = extended.len;
        }

        const home_path = try std.fs.path.join(allocator.*, &.{
            home,
            buff
        });
        defer allocator.free(home_path);

        switch (i.kind) {
            .file => {
                const file = try std.fs.createFileAbsolute(home_path, .{});
                defer file.close();

                try i.writeAll(file);
            },
            .sym_link => {
                while (true) {
                    std.fs.cwd().symLink(i.link_name, home_path, .{}) catch |err| {
                        if (err == error.PathAlreadyExists) {
                            try std.fs.deleteFileAbsolute(home_path);
                            continue;
                        } else {
                            return err;
                        }
                    };
                    break;
                }

            },
            else => {}
        }
    }

    std.log.info("Finished!", .{});
}

fn export_config(allocator: *std.mem.Allocator, filename: []const u8) !void {
    var exporter = Exporter{ .allocator = allocator };
    var context = ConfigContext.init(allocator);
    defer context.deinit();

    try exporter.read_configs(&context);

    try context.save();

    const saves = try std.fs.cwd().openDir(c.saves_dir, .{ .iterate = true });

    std.log.info("Compressing all saved files into '{s}.tar.gz'. This may take a while.", .{filename});

    var iter = try saves.walk(allocator.*);
    defer iter.deinit();

    var buf = std.ArrayList(u8).init(allocator.*);
    defer buf.deinit();

    var writer = std.tar.writer(buf.writer());

    while (try iter.next()) |entry| {
        if (entry.kind == std.fs.Dir.Entry.Kind.directory) {
            continue;
        }

        const filepath = try std.fs.path.resolve(allocator.*, &.{
            c.saves_dir,
            entry.path
        });

        defer allocator.free(filepath);

        switch (entry.kind) {
            std.fs.Dir.Entry.Kind.file => {
                const file = std.fs.cwd().openFile(filepath, .{}) catch |err| {
                    if (err == error.FileNotFound) {
                        std.log.err("This specific file: {s} cannot be found?", .{filepath});
                        continue;
                    } else {
                        return err;
                    }
                };

                const end_pos = try file.getEndPos();
                try file.seekTo(0);
                try writer.writeFileStream(filepath, end_pos, file.reader(), .{});
            },
            std.fs.Dir.Entry.Kind.sym_link => {
                var buff: [4096]u8 = undefined;
                const link_name = try std.fs.cwd().readLink(filepath, &buff);
                try writer.writeLink(filepath, link_name, .{});
            },
            else => {}
        }
    }

    try writer.finish();

    const tar_file = try utils.concat(allocator, filename, ".tar.gz");    
    defer allocator.free(tar_file);

    var tar = try std.fs.cwd().createFile(tar_file, .{ .read = true });
    defer tar.close();

    var compressor = try std.compress.gzip.compressor(tar.writer(), .{});
    _ = try compressor.write(buf.items);
    try compressor.finish();

    std.log.info("Cleaning up...", .{});

    try std.fs.cwd().deleteTree(c.saves_dir);

    std.log.info("Finished!", .{});
}