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
    // Initial placement on canvas (in virtual coords).
    init_x: f32 = 0,
    init_y: f32 = 0,
    placed: bool = false,
};

var open_files: [max_open_files]OpenFile = undefined;
var open_file_count: usize = 0;
var active_file_idx: ?usize = null;

const win_w: f32 = 480;
const win_h: f32 = 380;
const win_gap: f32 = 24;

fn openFileByPath(path: []const u8) void {
    // Don't open duplicates — focus existing instead.
    for (open_files[0..open_file_count], 0..) |*f, i| {
        if (std.mem.eql(u8, f.path[0..f.path_len], path)) {
            active_file_idx = i;
            return;
        }
    }
    if (open_file_count >= max_open_files) return;

    var of = &open_files[open_file_count];
    of.* = .{};
    @memcpy(of.path[0..path.len], path);
    of.path_len = path.len;

    const basename = std.fs.path.basename(path);
    @memcpy(of.title[0..basename.len], basename);
    of.title_len = basename.len;
    of.open = true;
    of.placed = false;

    // Compute non-overlapping grid position.
    const n = open_file_count;
    const cols: usize = @max(1, @as(usize, @intFromFloat(@ceil(@sqrt(@as(f32, @floatFromInt(n + 1)))))));
    const row: f32 = @floatFromInt(n / cols);
    const col: f32 = @floatFromInt(n % cols);
    of.init_x = 20 + col * (win_w + win_gap);
    of.init_y = 20 + row * (win_h + win_gap);

    active_file_idx = open_file_count;
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
        .title = "Monolith",
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

var split_ratio: f32 = 0.18;
var sidebar_visible: bool = true;

fn guiFrame() bool {
    // Outer vertical layout: menu bar | main area | status bar.
    {
        var outer = dvui.box(@src(), .{}, .{ .expand = .both });
        defer outer.deinit();

        drawMenuBar();
        drawMainArea();
        drawStatusBar();
    }

    // Floating editor windows are drawn as dvui floating windows.
    drawFloatingEditors();

    return checkQuit();
}

// ---------------------------------------------------------------------------
// Menu bar
// ---------------------------------------------------------------------------

fn drawMenuBar() void {
    var bar = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .horizontal,
        .padding = .{ .x = 8, .y = 4, .w = 8, .h = 4 },
        .background = true,
        .style = .window,
        .border = .{ .x = 0, .y = 0, .w = 0, .h = 1 },
    });
    defer bar.deinit();

    // Brand.
    dvui.labelNoFmt(@src(), "Monolith", .{}, .{
        .font = .theme(.heading),
        .padding = .{ .x = 0, .y = 0, .w = 16, .h = 0 },
    });

    // Menus.
    var m = dvui.menu(@src(), .horizontal, .{});
    defer m.deinit();

    if (dvui.menuItemLabel(@src(), "File", .{ .submenu = true }, .{})) |r| {
        var fw = dvui.floatingMenu(@src(), .{ .from = r }, .{});
        defer fw.deinit();

        if (dvui.menuItemLabel(@src(), "New Window", .{}, .{ .expand = .horizontal }) != null) {
            fw.close();
        }
        if (dvui.menuItemLabel(@src(), "Close All", .{}, .{ .expand = .horizontal }) != null) {
            closeAllFiles();
            fw.close();
        }
        if (dvui.menuItemLabel(@src(), "Quit", .{}, .{ .expand = .horizontal }) != null) {
            fw.close();
        }
    }

    if (dvui.menuItemLabel(@src(), "Edit", .{ .submenu = true }, .{})) |r| {
        var fw = dvui.floatingMenu(@src(), .{ .from = r }, .{});
        defer fw.deinit();

        if (dvui.menuItemLabel(@src(), "Rearrange Windows", .{}, .{ .expand = .horizontal }) != null) {
            rearrangeWindows();
            fw.close();
        }
        if (dvui.menuItemLabel(@src(), "Toggle Explorer", .{}, .{ .expand = .horizontal }) != null) {
            sidebar_visible = !sidebar_visible;
            fw.close();
        }
    }

    if (dvui.menuItemLabel(@src(), "View", .{ .submenu = true }, .{})) |r| {
        var fw = dvui.floatingMenu(@src(), .{ .from = r }, .{});
        defer fw.deinit();

        _ = dvui.checkbox(@src(), &sidebar_visible, "Show Explorer", .{});
    }
}

fn closeAllFiles() void {
    for (open_files[0..open_file_count]) |*f| {
        f.open = false;
    }
}

fn rearrangeWindows() void {
    const n = open_file_count;
    if (n == 0) return;
    const cols: usize = @max(1, @as(usize, @intFromFloat(@ceil(@sqrt(@as(f32, @floatFromInt(n)))))));
    for (0..n) |i| {
        var of = &open_files[i];
        if (!of.open) continue;
        const row: f32 = @floatFromInt(i / cols);
        const col: f32 = @floatFromInt(i % cols);
        of.init_x = 20 + col * (win_w + win_gap);
        of.init_y = 20 + row * (win_h + win_gap);
        // Force dvui to reposition the floating window on next frame
        of.placed = false;
    }
}

// ---------------------------------------------------------------------------
// Main area: sidebar + canvas
// ---------------------------------------------------------------------------

fn drawMainArea() void {
    if (sidebar_visible) {
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
            drawCanvas();
        }

        paned_widget.deinit();
    } else {
        drawCanvas();
    }
}

// ---------------------------------------------------------------------------
// Canvas background (right pane)
// ---------------------------------------------------------------------------

fn drawCanvas() void {
    var canvas = dvui.box(@src(), .{}, .{
        .expand = .both,
        .background = true,
        .style = .content,
    });
    defer canvas.deinit();

    if (open_file_count == 0) {
        dvui.labelNoFmt(@src(), "Open a file from the explorer to start editing.", .{}, .{
            .expand = .both,
            .gravity_x = 0.5,
            .gravity_y = 0.5,
        });
    }
}

// ---------------------------------------------------------------------------
// Floating editor windows
// ---------------------------------------------------------------------------

fn drawFloatingEditors() void {
    for (0..open_file_count) |idx| {
        var of = &open_files[idx];
        if (!of.open) continue;

        const title = of.title[0..of.title_len];
        const is_active = (active_file_idx != null and active_file_idx.? == idx);

        // Use Options.rect for initial position on first frame.
        const init_rect: ?dvui.Rect = if (!of.placed) .{ .x = of.init_x, .y = of.init_y, .w = win_w, .h = win_h } else null;
        if (!of.placed) of.placed = true;

        var fw = dvui.floatingWindow(@src(), .{
            .open_flag = &of.open,
        }, .{
            .id_extra = idx,
            .rect = init_rect,
            .min_size_content = .{ .w = 200, .h = 150 },
            .border = if (is_active) .all(2) else .all(1),
            .color_border = if (is_active) dvui.themeGet().focus else null,
        });
        defer fw.deinit();

        // Window header with drag area.
        fw.dragAreaSet(dvui.windowHeader(title, "", &of.open));

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

    // Compact closed files.
    compactOpenFiles();
}

// ---------------------------------------------------------------------------
// Status bar
// ---------------------------------------------------------------------------

fn drawStatusBar() void {
    var bar = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .horizontal,
        .padding = .{ .x = 8, .y = 2, .w = 8, .h = 2 },
        .background = true,
        .style = .window,
        .border = .{ .x = 0, .y = 1, .w = 0, .h = 0 },
    });
    defer bar.deinit();

    // Left side.
    {
        var buf: [64]u8 = undefined;
        const info = std.fmt.bufPrint(&buf, "{d} file(s) open", .{open_file_count}) catch "?";
        dvui.labelNoFmt(@src(), info, .{}, .{
            .expand = .horizontal,
        });
    }

    // Right side.
    dvui.labelNoFmt(@src(), "Spatial Mode", .{}, .{});
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

        dvui.labelNoFmt(@src(), "PROJECT EXPLORER", .{}, .{ .font = .theme(.heading) });
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
    if (depth > 8) return;

    var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch return;
    defer dir.close();

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

    std.mem.sort(Entry, entries[0..count], {}, struct {
        fn lessThan(_: void, a: Entry, b: Entry) bool {
            if (a.is_dir and !b.is_dir) return true;
            if (!a.is_dir and b.is_dir) return false;
            return std.mem.order(u8, a.getName(), b.getName()) == .lt;
        }
    }.lessThan);

    for (entries[0..count]) |*entry| {
        var path_buf: [4096]u8 = undefined;
        const full_path = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ dir_path, entry.getName() }) catch continue;

        if (entry.is_dir) {
            var branch = tree_widget.branch(@src(), .{
                .expanded = false,
            }, .{ .id_extra = std.hash.Wyhash.hash(0, entry.getName()) });

            dvui.labelNoFmt(@src(), entry.getName(), .{}, .{});

            if (branch.expander(@src(), .{ .indent = 16 }, .{})) {
                renderDirBranch(tree_widget, full_path, root, depth + 1);
            }

            branch.deinit();
        } else {
            // Highlight files that are open.
            const is_open = blk: {
                for (open_files[0..open_file_count]) |*f| {
                    if (std.mem.eql(u8, f.path[0..f.path_len], full_path) and f.open) break :blk true;
                }
                break :blk false;
            };

            if (dvui.button(@src(), entry.getName(), .{}, .{
                .id_extra = std.hash.Wyhash.hash(0, entry.getName()),
                .border = .{},
                .corner_radius = .{},
                .background = is_open,
                .padding = .{ .x = 20, .y = 2, .w = 2, .h = 2 },
                .expand = .horizontal,
            })) {
                openFileByPath(full_path);
            }
        }
    }
}

// ---------------------------------------------------------------------------
// File I/O
// ---------------------------------------------------------------------------

fn isLikelyTextFile(path: []const u8) bool {
    const text_exts = [_][]const u8{
        ".zig",  ".zon",  ".txt",   ".md",   ".json", ".toml",      ".yaml",         ".yml",
        ".xml",  ".html", ".css",   ".js",   ".ts",   ".c",         ".h",            ".cpp",
        ".hpp",  ".py",   ".rs",    ".go",   ".sh",   ".bash",      ".zsh",          ".fish",
        ".conf", ".cfg",  ".ini",   ".log",  ".csv",  ".gitignore", ".editorconfig", ".lock",
        ".mod",  ".sum",  ".cmake", ".make", ".mk",   "Makefile",
    };
    const ext = std.fs.path.extension(path);
    if (ext.len == 0) {
        const base = std.fs.path.basename(path);
        for (text_exts) |te| {
            if (std.mem.eql(u8, base, te)) return true;
        }
        return false;
    }
    for (text_exts) |te| {
        if (std.mem.eql(u8, ext, te)) return true;
    }
    return false;
}

const max_file_load_size = 512 * 1024;

fn loadFileIntoEntry(te: *dvui.TextEntryWidget, of: *OpenFile) void {
    const path = of.path[0..of.path_len];

    if (!isLikelyTextFile(path)) {
        te.textSet("[Binary file - not displayed]", false);
        return;
    }

    const file = std.fs.cwd().openFile(path, .{}) catch {
        te.textSet("[Could not open file]", false);
        return;
    };
    defer file.close();

    const stat = file.stat() catch {
        te.textSet("[Could not stat file]", false);
        return;
    };

    if (stat.size > max_file_load_size) {
        te.textSet("[File too large to display]", false);
        return;
    }

    const buf = gpa.alloc(u8, @intCast(stat.size)) catch {
        te.textSet("[Out of memory]", false);
        return;
    };
    defer gpa.free(buf);

    const bytes_read = file.readAll(buf) catch {
        te.textSet("[Read error]", false);
        return;
    };

    var non_text: usize = 0;
    const check_len = @min(bytes_read, 8192);
    for (buf[0..check_len]) |b| {
        if (b == 0 or (b < 0x09 and b != 0x07)) non_text += 1;
    }
    if (check_len > 0 and non_text * 10 > check_len) {
        te.textSet("[Binary file - not displayed]", false);
        return;
    }

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
                // Fix active index if it was moved.
                if (active_file_idx != null and active_file_idx.? == read_idx) {
                    active_file_idx = write_idx;
                }
            }
            write_idx += 1;
        } else {
            if (active_file_idx != null and active_file_idx.? == read_idx) {
                active_file_idx = null;
            }
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
