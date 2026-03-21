const std = @import("std");
const dvui = @import("dvui");
const SDLBackend = @import("sdl3gpu-backend");
const c = SDLBackend.c;

var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = gpa_instance.allocator();

const vsync = true;
const min_refresh_fps: f32 = 30.0;

// ---------------------------------------------------------------------------
// Editor state
// ---------------------------------------------------------------------------

const max_open_files = 16;

const OpenFile = struct {
    path: [4096]u8 = undefined,
    path_len: usize = 0,
    title: [256]u8 = undefined,
    title_len: usize = 0,
    open: bool = true,
    rect: dvui.Rect = .{},
    rect_set: bool = false,
};

var open_files: [max_open_files]OpenFile = undefined;
var open_file_count: usize = 0;

fn openFileByPath(path: []const u8) void {
    // Don't open duplicates.
    for (open_files[0..open_file_count]) |*f| {
        if (std.mem.eql(u8, f.path[0..f.path_len], path)) return;
    }
    if (open_file_count >= max_open_files) return;

    var of = &open_files[open_file_count];
    of.* = .{};
    @memcpy(of.path[0..path.len], path);
    of.path_len = path.len;

    // Extract basename for title.
    const basename = std.fs.path.basename(path);
    @memcpy(of.title[0..basename.len], basename);
    of.title_len = basename.len;
    of.open = true;
    of.rect_set = false;

    open_file_count += 1;
}

// ---------------------------------------------------------------------------
// Directory tree state
// ---------------------------------------------------------------------------

var tree_root_path: [4096]u8 = undefined;
var tree_root_path_len: usize = 0;

fn initTreeRoot() void {
    const cwd = std.fs.cwd().realpath(".", &tree_root_path) catch ".";
    tree_root_path_len = cwd.len;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

pub fn main() !void {
    if (@import("builtin").os.tag == .windows) {
        dvui.Backend.Common.windowsAttachConsole() catch {};
    }

    SDLBackend.enableSDLLogging();
    std.log.info("SDL version: {f}", .{SDLBackend.getSDLVersion()});

    defer if (gpa_instance.deinit() != .ok) @panic("Memory leak on exit!");

    initTreeRoot();

    var backend = try SDLBackend.initWindow(.{
        .allocator = gpa,
        .size = .{ .w = 1400.0, .h = 900.0 },
        .min_size = .{ .w = 640.0, .h = 480.0 },
        .vsync = vsync,
        .title = "znn editor",
    });
    defer backend.deinit();

    _ = c.SDL_EnableScreenSaver();

    var win = try dvui.Window.init(@src(), gpa, backend.backend(), .{
        .theme = switch (backend.preferredColorScheme() orelse .dark) {
            .light => dvui.Theme.builtin.adwaita_light,
            .dark => dvui.Theme.builtin.adwaita_dark,
        },
    });
    defer win.deinit();

    var interrupted = false;
    const max_wait: u32 = @intFromFloat(1_000_000.0 / min_refresh_fps);

    main_loop: while (true) {
        const nstime = win.beginWait(interrupted);
        try win.begin(nstime);

        const quit = try backend.addAllEvents(&win);
        const frame_ok = guiFrame();
        const keep = frame_ok and !quit;

        const end_micros = try win.end(.{});
        try backend.setCursor(win.cursorRequested());
        try backend.textInputRect(win.textInputRequested());
        try backend.renderPresent();

        if (!keep) break :main_loop;

        const wait_micros = @min(win.waitTime(end_micros), max_wait);
        interrupted = try backend.waitEventTimeout(wait_micros);
    }
}

// ---------------------------------------------------------------------------
// GUI Frame
// ---------------------------------------------------------------------------

var split_ratio: f32 = 0.2;

fn guiFrame() bool {
    {
        var paned_widget = dvui.paned(@src(), .{
            .direction = .horizontal,
            .collapsed_size = 100,
            .split_ratio = &split_ratio,
            .handle_size = 4,
        }, .{
            .expand = .both,
        });

        if (paned_widget.showFirst()) {
            drawDirectoryTree();
        }

        if (paned_widget.showSecond()) {
            drawEditorArea();
        }

        paned_widget.deinit();
    }

    return checkQuit();
}

// ---------------------------------------------------------------------------
// Directory tree (left pane)
// ---------------------------------------------------------------------------

fn drawDirectoryTree() void {
    var scroll = dvui.scrollArea(@src(), .{}, .{
        .expand = .both,
        .background = true,
        .style = .window,
    });
    defer scroll.deinit();

    {
        var header = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .horizontal,
            .padding = .{ .x = 4, .y = 4, .w = 4, .h = 4 },
        });
        defer header.deinit();

        dvui.labelNoFmt(@src(), "EXPLORER", .{}, .{ .font = .theme(.heading) });
    }

    var tree_widget = dvui.TreeWidget.tree(@src(), .{ .enable_reordering = false }, .{
        .expand = .both,
        .padding = .{ .x = 2, .y = 0, .w = 2, .h = 2 },
    });
    defer tree_widget.deinit();

    const root = tree_root_path[0..tree_root_path_len];
    renderDirBranch(tree_widget, root, root, 0);
}

fn renderDirBranch(tree_widget: *dvui.TreeWidget, dir_path: []const u8, root: []const u8, depth: u32) void {
    if (depth > 8) return; // limit recursion

    var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch return;
    defer dir.close();

    // Collect entries into a temporary list to sort them.
    const Entry = struct {
        name_buf: [256]u8 = undefined,
        name_len: usize = 0,
        is_dir: bool = false,

        fn getName(self: *const @This()) []const u8 {
            return self.name_buf[0..self.name_len];
        }
    };

    var entries: [256]Entry = undefined;
    var count: usize = 0;

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (count >= 256) break;
        if (entry.name.len == 0 or entry.name[0] == '.') continue;
        if (std.mem.eql(u8, entry.name, "zig-out")) continue;

        var e = &entries[count];
        e.* = .{};
        const n = @min(entry.name.len, 256);
        @memcpy(e.name_buf[0..n], entry.name[0..n]);
        e.name_len = n;
        e.is_dir = entry.kind == .directory;
        count += 1;
    }

    // Sort: directories first, then alphabetical.
    std.mem.sort(Entry, entries[0..count], {}, struct {
        fn lessThan(_: void, a: Entry, b: Entry) bool {
            if (a.is_dir and !b.is_dir) return true;
            if (!a.is_dir and b.is_dir) return false;
            return std.mem.order(u8, a.getName(), b.getName()) == .lt;
        }
    }.lessThan);

    for (entries[0..count]) |*entry| {
        // Build full path.
        var path_buf: [4096]u8 = undefined;
        const full_path = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ dir_path, entry.getName() }) catch continue;

        if (entry.is_dir) {
            var branch = tree_widget.branch(@src(), .{
                .expanded = false,
            }, .{ .id_extra = std.hash.Wyhash.hash(0, entry.getName()) });

            // icon + label on the branch header row
            dvui.labelNoFmt(@src(), entry.getName(), .{}, .{});

            if (branch.expander(@src(), .{ .indent = 16 }, .{})) {
                renderDirBranch(tree_widget, full_path, root, depth + 1);
            }

            branch.deinit();
        } else {
            // Leaf file item - clickable label.
            if (dvui.button(@src(), entry.getName(), .{}, .{
                .id_extra = std.hash.Wyhash.hash(0, entry.getName()),
                .border = .{},
                .corner_radius = .{},
                .background = false,
                .padding = .{ .x = 20, .y = 2, .w = 2, .h = 2 },
                .expand = .horizontal,
            })) {
                openFileByPath(full_path);
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Editor area (right pane) - tiled text editing boxes
// ---------------------------------------------------------------------------

fn drawEditorArea() void {
    var root = dvui.box(@src(), .{}, .{
        .expand = .both,
        .background = true,
    });
    defer root.deinit();

    if (open_file_count == 0) {
        dvui.labelNoFmt(@src(), "Open a file from the explorer to start editing.", .{}, .{
            .expand = .both,
            .gravity_x = 0.5,
            .gravity_y = 0.5,
        });
        return;
    }

    // Calculate tiling layout: try to fill the area with a grid.
    const n = open_file_count;
    const cols = tilingCols(n);
    const rows = (n + cols - 1) / cols;

    // Build grid of rows, each row is a horizontal box.
    var row: usize = 0;
    while (row < rows) : (row += 1) {
        var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .both,
            .id_extra = row,
        });
        defer hbox.deinit();

        var col: usize = 0;
        while (col < cols) : (col += 1) {
            const idx = row * cols + col;
            if (idx >= n) break;

            drawEditorPane(idx, col);
        }
    }

    // Remove closed files (compact the array).
    compactOpenFiles();
}

fn tilingCols(n: usize) usize {
    if (n <= 1) return 1;
    if (n <= 2) return 2;
    if (n <= 4) return 2;
    if (n <= 6) return 3;
    if (n <= 9) return 3;
    return 4;
}

fn drawEditorPane(idx: usize, col_extra: usize) void {
    var of = &open_files[idx];
    if (!of.open) return;

    const title = of.title[0..of.title_len];

    // Outer frame for this pane.
    var frame = dvui.box(@src(), .{}, .{
        .expand = .both,
        .id_extra = idx,
        .border = .{ .x = 1, .y = 1, .w = 1, .h = 1 },
        .padding = .{},
        .margin = .{ .x = 1, .y = 1, .w = 1, .h = 1 },
        .style = .window,
        .background = true,
    });
    defer frame.deinit();
    _ = col_extra;

    // Title bar.
    {
        var title_bar = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .horizontal,
            .padding = .{ .x = 6, .y = 3, .w = 6, .h = 3 },
            .background = true,
            .style = .window,
        });
        defer title_bar.deinit();

        dvui.labelNoFmt(@src(), title, .{}, .{ .font = .theme(.heading), .expand = .horizontal });

        if (dvui.button(@src(), "X", .{}, .{
            .min_size_content = .{ .w = 16, .h = 16 },
            .padding = .{ .x = 2, .y = 2, .w = 2, .h = 2 },
            .margin = .{},
        })) {
            of.open = false;
        }
    }

    // Text editing area.
    var te: dvui.TextEntryWidget = undefined;
    te.init(@src(), .{
        .multiline = true,
        .break_lines = true,
        .scroll_horizontal = false,
        .text = .{ .internal = .{ .limit = 2_000_000 } },
    }, .{
        .expand = .both,
        .font = .theme(.mono),
        .id_extra = idx,
    });

    // Load file content on first frame.
    if (dvui.firstFrame(te.data().id)) {
        loadFileIntoEntry(&te, of);
    }

    te.processEvents();
    te.draw();
    te.deinit();
}

fn loadFileIntoEntry(te: *dvui.TextEntryWidget, of: *OpenFile) void {
    const path = of.path[0..of.path_len];
    const file = std.fs.cwd().openFile(path, .{}) catch return;
    defer file.close();

    // Read up to 2MB.
    var buf: [2 * 1024 * 1024]u8 = undefined;
    const bytes_read = file.readAll(&buf) catch return;
    if (bytes_read > 0) {
        te.textSet(buf[0..bytes_read], false);
    }
}

fn compactOpenFiles() void {
    var write_idx: usize = 0;
    for (0..open_file_count) |read_idx| {
        if (open_files[read_idx].open) {
            if (write_idx != read_idx) {
                open_files[write_idx] = open_files[read_idx];
            }
            write_idx += 1;
        }
    }
    open_file_count = write_idx;
}

// ---------------------------------------------------------------------------
// Input handling
// ---------------------------------------------------------------------------

fn checkQuit() bool {
    var keep_running = true;
    for (dvui.events()) |*e| {
        switch (e.evt) {
            .window => |w| {
                if (w.action == .close) keep_running = false;
            },
            .app => |a| {
                if (a.action == .quit) keep_running = false;
            },
            else => {},
        }
    }
    return keep_running;
}
