const c = @import("constants.zig");
const Exporter = @This();
const ConfigContext = @import("ConfigContext.zig");
const std = @import("std");
const utils = @import("utils.zig");

const config_files = c.default_config_files;
const folders = c.default_config_directories;

allocator: *std.mem.Allocator,


fn readFiles(
    self: *Exporter, 
    conf: *ConfigContext, 
    comptime directory: []const u8, 
    comptime filelist: anytype,
    comptime t: ConfigContext.EntryType
) !void {
    std.log.info("Collecting selected files on {s}.", .{directory});

    for (filelist) |file| {
        const path = try std.fs.path.join(self.allocator.*, &.{
            directory, file
        });

        defer self.allocator.free(path);

        try self.saveFile(directory, path);
        try conf.track(file, t);
    }
}

fn readDirectories(
    self: *Exporter,
    conf: *ConfigContext,
    comptime root_dir: []const u8,
    comptime directories: anytype,
    comptime t: ConfigContext.EntryType
) !void {
    const cwd = std.fs.cwd();
    const real_path = try std.fs.realpathAlloc(self.allocator.*, ".");
    defer self.allocator.free(real_path);

    var files = std.ArrayList([]u8).init(self.allocator.*);
    defer files.deinit();

    var symLinks = std.ArrayList([]u8).init(self.allocator.*);
    defer symLinks.deinit();

    for (directories) |c_dir| {
        const directory = try std.fs.path.join(self.allocator.*, &.{
            root_dir, c_dir
        });
        defer self.allocator.free(directory);


        std.log.info("Collecting all files from {s}.", .{directory});

        const path = try utils.home_path(self.allocator, directory);
        defer self.allocator.free(path);

        var dir = std.fs.openDirAbsolute(path, .{ .iterate = true }) catch |err| {
            if (err != std.fs.Dir.OpenError.FileNotFound) {
                return err;
            }

            continue;
        };
        defer dir.close();

        const saves_path = try std.fs.path.join(self.allocator.*, &.{
            real_path,
            c.saves_dir,
            directory
        });
        defer self.allocator.free(saves_path);

        cwd.makeDir(saves_path) catch |err| {
            if (err != std.fs.Dir.MakeError.PathAlreadyExists) {
                return err;
            }
        };

        var iter = try dir.walk(self.allocator.*);
        defer iter.deinit();

        while (try iter.next()) |entry| {
            switch (entry.kind) {
                std.fs.Dir.Entry.Kind.directory => {
                    const dir_path = try std.fs.path.join(self.allocator.*, &.{
                        saves_path,
                        entry.path
                    });
                    defer self.allocator.free(dir_path);

                    cwd.makeDir(dir_path) catch |err| {
                        if (err != std.fs.Dir.MakeError.PathAlreadyExists) {
                            return err;
                        }
                    };
                },
                std.fs.Dir.Entry.Kind.sym_link => try symLinks.append(try utils.owned(self.allocator.*, entry.path)),
                // since files are the first one to be crawled at.
                // we need to copy it after all directories are created.
                std.fs.Dir.Entry.Kind.file => try files.append(try utils.owned(self.allocator.*, entry.path)),
                else => {}
            }
        }

        for (symLinks.items) |entry| {
            defer self.allocator.free(entry);

            var buffer: [4096]u8 = undefined;

            const source_symlink = try std.fs.path.join(self.allocator.*, &.{
                path,
                entry
            });

            defer self.allocator.free(source_symlink);

            const b = try cwd.readLink(source_symlink, &buffer);

            const dest_path = try std.fs.path.join(self.allocator.*, &.{
                saves_path,
                entry
            });

            defer self.allocator.free(dest_path);

            cwd.symLink(b, dest_path, .{}) catch |err| {
                if (err != error.PathAlreadyExists) {
                    return err;
                }
            };
        }

        for (files.items) |entry| {
            defer self.allocator.free(entry);
            const source_path = try std.fs.path.join(self.allocator.*, &.{
                path,
                entry
            });

            defer self.allocator.free(source_path);


            const dest_path = try std.fs.path.join(self.allocator.*, &.{
                saves_path,
                entry
            });

            defer self.allocator.free(source_path);
            std.fs.copyFileAbsolute(source_path, dest_path, .{}) catch |err| {
                switch (err) {
                    error.FileNotFound => std.log.err("Source path: {s} does not exists or invalid.", .{source_path}),
                    else => return err
                }
            };
        }

        try conf.track(directory, t);

        files.clearRetainingCapacity();
        symLinks.clearRetainingCapacity();
    }
}

pub fn read_configs(self: *Exporter, conf: *ConfigContext) !void {
    const cwd = std.fs.cwd();

    cwd.makeDir(c.saves_dir) catch |err| {
        if (err != std.fs.Dir.MakeError.PathAlreadyExists) {
            std.log.err("Cannot create a folder '{s}'", .{c.saves_dir});
            return;
        }
    };

    cwd.makeDir(c.saves_dir ++ "/.local/") catch |err| {
        if (err != std.fs.Dir.MakeError.PathAlreadyExists) {
            std.log.err("Cannot create a folder '{s}'", .{c.saves_dir});
            return;
        }
    };

    cwd.makeDir(c.saves_dir ++ "/.local/share/") catch |err| {
        if (err != std.fs.Dir.MakeError.PathAlreadyExists) {
            std.log.err("Cannot create a folder '{s}'", .{c.saves_dir});
            return;
        }
    };

    try self.readFiles(conf, "/.config/", config_files, .config);
    try self.readDirectories(conf, "/.config/", c.default_config_directories, .config);
    try self.readDirectories(conf, "/.local/share/", c.default_share_directories, .config);
}

fn saveFile(self: *Exporter, comptime root_dir: []const u8, path: []u8) !void {
    const plasma_desktop_path_config_path = try utils.home_path(self.allocator, path);
    defer self.allocator.free(plasma_desktop_path_config_path);

    const cwd = std.fs.cwd();

    cwd.makeDir(c.saves_dir ++ root_dir) catch |err| {
        if (err != std.fs.Dir.MakeError.PathAlreadyExists) {
            std.log.err("Cannot save a file {s}.", .{path});
            return;
        }
    };

    const real_path = try std.fs.realpathAlloc(self.allocator.*, ".");
    defer self.allocator.free(real_path);

    const copy = try std.fs.path.join(self.allocator.*, &.{
        real_path,
        c.saves_dir,
        path
    });

    defer self.allocator.free(copy);
    std.fs.copyFileAbsolute(plasma_desktop_path_config_path, copy, .{}) catch |err| {
        if (err != error.FileNotFound) {
            return err;
        }
    };
}