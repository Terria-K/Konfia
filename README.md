# Konfia
Easily transfer your KDE configs and themes with Konfia!

>[!CAUTION]
> This project is still on alpha, and there is still a possibility to break your configs. Do it in a throwaway user first
> before doing this in your main user.

Konfia saves KDE related configs and as well as themes and icons, this will create a `.tar.gz` file that you can import
on another machine and it will extract all files in the proper directories.

>[!NOTE]
> Konfia only save configs and themes from your home directory, it will not save the from `/usr` directory.

**Usage:**
## For importing your configs and themes.
```bash
$ konfia --import "<path/to/tar.gz>"
```

## For exporting your configs and themes.
```bash
$ konfia --export
```
This will directly look up the necessary files and directories to save. To see which files are being saved, look at:
[constants.zig](/src/constants.zig)

# Compiling
To compile the project, you need `zig` installed to your system. If you have `zig`, just run `zig build -Doptimize=ReleaseFast` to compile the program.

Then the program will be output in `zig-out/bin` directory.

