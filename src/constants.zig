pub const saves_dir = ".konfia";

pub const default_config_files = [_][]const u8{ 
    "auroraerc",
    "dolphinrc", 
    "gtkrc", 
    "gtkrc-2.0", 
    "kcminputrc", 
    "kdeglobals", 
    "kglobalshortcutsrc", 
    "konsolerc", 
    "kwinrc", 
    "katerc",
    "kscreenlockerrc", 
    "plasmarc", 
    "plasmashellrc" ,
    "plasma-org.kde.plasma.desktop-appletsrc", 
    "ksmserverrc",
    "krunnerrc", 
    "touchpadrc",
    "touchpadxlibinputrc",
    "yakuakerc"
};

pub const default_config_directories = [_][]const u8 {
    "gtk-2.0",
    "gtk-3.0",
    "gtk-4.0",
    "Kvantum",
    "fastfetch",
    "fish"
};

pub const default_share_directories = [_][]const u8 {
    "aurorae",
    "fonts",
    "Kvantum",
    "color-schemes",
    "fastfetch",
    "icons",
    "konsole",
    "kwin",
    "org.kde.syntax-highlighting",
    "plasma",
    "plasma-systemmonitor",
    "wallpapers",
    "yakuake"
};

pub const default_home_directories = [_][]const u8 {
    ".icons",
};


pub const config = Target {
    .path = "/.config/",
    .alias = "config"
};

pub const share = Target {
    .path = "/.local/share/",
    .alias = "local_share"
};

pub const home = Target {
    .path = "/",
    .alias = "home"
};


pub const Target = struct {
    path: []const u8,
    alias: []const u8,
};