const std = @import("std");
const dvui = @import("dvui");

pub const Color = dvui.Color;
pub const Font = dvui.Font;
pub const Point = dvui.Point;
pub const Rect = dvui.Rect;
pub const ScrollInfo = dvui.ScrollInfo;
pub const Size = dvui.Size;
pub const entypo = dvui.entypo;

pub const vsync = true;
pub const min_refresh_fps: f32 = 30.0;

pub const rail_width: f32 = 64.0;
pub const explorer_width: f32 = 240.0;
pub const header_height: f32 = 40.0;
pub const footer_height: f32 = 24.0;

pub const max_loaded_file_bytes: usize = 512 * 1024;
pub const max_editable_file_bytes: usize = 2 * 1024 * 1024;
pub const file_buffer_headroom: usize = 512;

pub const palette = struct {
    pub const background = Color.fromHex("#060e20");
    pub const canvas = Color.fromHex("#07132b");
    pub const surface = Color.fromHex("#08172f");
    pub const surface_low = Color.fromHex("#06122d");
    pub const surface_lowest = Color.fromHex("#020915");
    pub const surface_high = Color.fromHex("#0a2248");
    pub const surface_highest = Color.fromHex("#0d2a56");
    pub const panel = Color.fromHex("#041833");
    pub const outline = Color.fromHex("#2b4680");
    pub const outline_soft = Color.fromHex("#1c325b");
    pub const primary = Color.fromHex("#7bd0ff");
    pub const primary_soft = Color.fromHex("#2a6d96");
    pub const primary_dim = Color.fromHex("#4da7d9");
    pub const text = Color.fromHex("#dee5ff");
    pub const text_dim = Color.fromHex("#91aaeb");
    pub const text_soft = Color.fromHex("#60769c");
    pub const warning = Color.fromHex("#f0b34b");
    pub const success = Color.fromHex("#8ad9c9");
    pub const yaml = Color.fromHex("#81d6c6");
    pub const markdown = Color.fromHex("#b4bed9");
    pub const gutter = Color.fromHex("#05101f");
    pub const grid_dot = Color.fromHex("#7bd0ff").opacity(0.08);
};

pub const monolith_theme = blk: {
    var theme = dvui.Theme.builtin.adwaita_dark;

    theme.name = "Monolith";
    theme.focus = palette.primary;
    theme.text_select = palette.primary.opacity(0.28);

    theme.fill = palette.background;
    theme.fill_hover = palette.surface;
    theme.fill_press = palette.surface_high;
    theme.text = palette.text;
    theme.text_hover = palette.text;
    theme.text_press = palette.text;
    theme.border = palette.outline;

    theme.control = .{
        .fill = palette.surface_high,
        .fill_hover = palette.surface_highest,
        .fill_press = palette.primary_soft,
        .text = palette.text,
        .text_press = palette.text,
        .border = palette.outline,
    };
    theme.window = .{
        .fill = palette.surface_low,
        .fill_hover = palette.surface,
        .fill_press = palette.surface_high,
        .text = palette.text,
        .border = palette.outline_soft,
    };
    theme.highlight = .{
        .fill = palette.surface_highest,
        .fill_hover = palette.primary_soft,
        .fill_press = palette.primary_dim,
        .text = palette.primary,
        .border = palette.primary,
    };
    theme.app1 = .{
        .fill = palette.panel,
        .fill_hover = palette.surface_low,
        .fill_press = palette.surface_high,
        .text = palette.text_dim,
        .border = palette.outline_soft,
    };
    theme.app2 = .{
        .fill = palette.surface_high,
        .fill_hover = palette.surface_highest,
        .fill_press = palette.primary_soft,
        .text = palette.text,
        .border = palette.outline,
    };
    theme.app3 = .{
        .fill = palette.primary_soft,
        .fill_hover = palette.primary_dim,
        .fill_press = palette.primary_dim,
        .text = palette.primary,
        .border = palette.primary,
    };

    theme.font_body = .find(.{ .family = "Vera Sans", .size = 9.5 });
    theme.font_heading = .find(.{ .family = "Vera Sans", .weight = .bold, .size = 9.75 });
    theme.font_title = .find(.{ .family = "Vera Sans", .weight = .bold, .size = 15 });
    theme.font_mono = .find(.{ .family = "Vera Sans Mono", .size = 9.5 });

    break :blk theme;
};

pub const Language = enum {
    cpp,
    yaml,
    markdown,
    zig,
    text,
};

pub const RailMode = enum {
    explorer,
    search,
    layout,
};

pub const EditorFile = struct {
    name: []const u8 = "",
    path: []const u8 = "",
    language: Language = .text,
    content: []u8 = &.{},
    window_open: bool = false,
    window_rect: Rect = .{},
    window_home_rect: Rect = .{},
    window_velocity: Point = .{},
    z_index: usize = 0,

    pub fn deinit(self: *EditorFile, gpa: std.mem.Allocator) void {
        if (self.name.len != 0) gpa.free(self.name);
        if (self.path.len != 0) gpa.free(self.path);
        if (self.content.len != 0) gpa.free(self.content);
        self.* = .{};
    }
};

pub const FolderNode = struct {
    name: []const u8 = "",
    relative_path: []const u8 = "",
    open: bool = true,
    folders: std.ArrayList(FolderNode) = .empty,
    file_indices: std.ArrayList(usize) = .empty,

    pub fn deinit(self: *FolderNode, gpa: std.mem.Allocator) void {
        for (self.folders.items) |*folder| {
            folder.deinit(gpa);
        }
        self.folders.deinit(gpa);
        self.file_indices.deinit(gpa);
        if (self.name.len != 0) gpa.free(self.name);
        if (self.relative_path.len != 0) gpa.free(self.relative_path);
        self.* = .{};
    }
};

pub const ProjectState = struct {
    name: []const u8 = "",
    root_path: []const u8 = "",
    files: std.ArrayList(EditorFile) = .empty,
    tree: FolderNode = .{},

    pub fn deinit(self: *ProjectState, gpa: std.mem.Allocator) void {
        for (self.files.items) |*file| {
            file.deinit(gpa);
        }
        self.files.deinit(gpa);
        self.tree.deinit(gpa);
        if (self.name.len != 0) gpa.free(self.name);
        if (self.root_path.len != 0) gpa.free(self.root_path);
        self.* = .{};
    }
};

pub const CanvasState = struct {
    scroll_info: ScrollInfo = .{
        .vertical = .given,
        .horizontal = .given,
    },
    origin: Point = .{},
    scale: f32 = 1.0,
    pending_zoom_delta: f32 = 0.0,
    center_requested: bool = false,
};

pub const ResizeEdges = struct {
    left: bool = false,
    right: bool = false,
    top: bool = false,
    bottom: bool = false,

    pub fn any(self: ResizeEdges) bool {
        return self.left or self.right or self.top or self.bottom;
    }

    pub fn cursor(self: ResizeEdges) dvui.enums.Cursor {
        if ((self.left and self.top) or (self.right and self.bottom)) return .arrow_nw_se;
        if ((self.right and self.top) or (self.left and self.bottom)) return .arrow_ne_sw;
        if (self.left or self.right) return .arrow_w_e;
        if (self.top or self.bottom) return .arrow_n_s;
        return .arrow;
    }
};

pub const WindowRenderMeta = struct {
    index: usize,
    frame_wd: dvui.WidgetData,
    header_wd: dvui.WidgetData,
    close_wd: dvui.WidgetData,
};

pub const AppState = struct {
    initialized: bool = false,
    sidebar_open: bool = true,
    explorer_root_open: bool = true,
    rail_mode: RailMode = .explorer,
    pending_focus_file: ?usize = null,
    pending_editor_focus: ?usize = null,
    pending_search_focus: bool = false,
    manipulated_window: ?usize = null,
    settling_anchor_window: ?usize = null,
    last_active_file: ?usize = null,
    next_z_index: usize = 1,
    search_buf: [256]u8 = [_]u8{0} ** 256,
    project: ProjectState = .{},
    canvas: CanvasState = .{},
    resize_edges: ResizeEdges = .{},
    previous_rects: std.ArrayList(Rect) = .empty,
    render_order: std.ArrayList(usize) = .empty,
    render_metas: std.ArrayList(WindowRenderMeta) = .empty,

    pub fn deinit(self: *AppState, gpa: std.mem.Allocator) void {
        self.project.deinit(gpa);
        self.previous_rects.deinit(gpa);
        self.render_order.deinit(gpa);
        self.render_metas.deinit(gpa);
        self.* = .{};
    }
};

const RuntimeState = struct {
    initialized: bool = false,
    allocator: ?std.mem.Allocator = null,
    io: ?std.Io = null,
    project_path: ?[]u8 = null,
};

var runtime: RuntimeState = .{};
pub var app: AppState = .{};

pub fn initRuntime(init: std.process.Init) !void {
    if (runtime.initialized) return;

    runtime.allocator = init.gpa;
    runtime.io = init.io;

    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();

    _ = args.next();
    if (args.next()) |path| {
        runtime.project_path = try init.gpa.dupe(u8, path);
    } else {
        const cwd = try std.process.currentPathAlloc(init.io, init.gpa);
        defer init.gpa.free(cwd);
        runtime.project_path = try init.gpa.dupe(u8, cwd);
    }

    runtime.initialized = true;
}

pub fn deinit() void {
    if (runtime.allocator) |gpa| {
        app.deinit(gpa);
        if (runtime.project_path) |path| {
            gpa.free(path);
        }
    }
    runtime = .{};
}

pub fn allocator() std.mem.Allocator {
    return runtime.allocator orelse @panic("app runtime not initialized");
}

pub fn io() std.Io {
    return runtime.io orelse @panic("app runtime not initialized");
}

pub fn fileText(file: *const EditorFile) []const u8 {
    return std.mem.sliceTo(file.content, 0);
}

pub fn prepareRenderScratch(file_count: usize) bool {
    const gpa = allocator();

    app.previous_rects.resize(gpa, file_count) catch return false;
    app.render_order.clearRetainingCapacity();
    app.render_order.ensureTotalCapacity(gpa, file_count) catch return false;
    app.render_metas.resize(gpa, file_count) catch return false;
    return true;
}

pub fn languageForPath(path: []const u8) Language {
    const ext = std.fs.path.extension(path);
    if (std.mem.eql(u8, ext, ".yaml") or std.mem.eql(u8, ext, ".yml")) return .yaml;
    if (std.mem.eql(u8, ext, ".md") or std.mem.eql(u8, ext, ".markdown")) return .markdown;
    if (std.mem.eql(u8, ext, ".zig") or std.mem.eql(u8, ext, ".zon")) return .zig;
    if (std.mem.eql(u8, ext, ".c") or std.mem.eql(u8, ext, ".cc") or std.mem.eql(u8, ext, ".cpp") or std.mem.eql(u8, ext, ".cxx") or std.mem.eql(u8, ext, ".h") or std.mem.eql(u8, ext, ".hh") or std.mem.eql(u8, ext, ".hpp") or std.mem.eql(u8, ext, ".hxx")) return .cpp;
    return .text;
}

pub fn ensureAppState() !void {
    if (app.initialized) return;

    const project_path = runtime.project_path orelse return error.MissingProjectPath;
    var project = try loadProjectFromPath(project_path);
    errdefer project.deinit(allocator());

    app.project = project;
    app.next_z_index = 1;
    app.pending_focus_file = null;
    app.last_active_file = null;

    var top_idx: ?usize = null;
    for (app.project.files.items, 0..) |file, i| {
        if (!file.window_open) continue;
        if (file.z_index >= app.next_z_index) {
            app.next_z_index = file.z_index + 1;
        }
        if (top_idx == null or app.project.files.items[top_idx.?].z_index <= file.z_index) {
            top_idx = i;
        }
    }

    app.pending_focus_file = top_idx;
    app.last_active_file = top_idx;
    app.initialized = true;
}

fn loadProjectFromPath(project_path: []const u8) !ProjectState {
    var project: ProjectState = .{
        .name = try makeProjectName(project_path),
        .root_path = try makeProjectRootPath(project_path),
    };
    errdefer project.deinit(allocator());

    var root_dir = try openProjectDir(project_path);
    defer root_dir.close(io());

    var walker = try std.Io.Dir.walkSelectively(root_dir, allocator());
    defer walker.deinit();

    while (try walker.next(io())) |entry| {
        switch (entry.kind) {
            .directory => {
                if (!shouldSkipDirectory(entry.basename)) {
                    try walker.enter(io(), entry);
                }
            },
            .file => {
                maybeAppendFilesystemFile(&project, root_dir, entry.path) catch |err| {
                    std.log.warn("skipping {s}: {t}", .{ entry.path, err });
                };
            },
            else => {},
        }
    }

    std.sort.block(EditorFile, project.files.items, {}, struct {
        fn lessThan(_: void, a: EditorFile, b: EditorFile) bool {
            return std.mem.order(u8, a.path, b.path) == .lt;
        }
    }.lessThan);

    project.tree = try buildProjectTree(project.files.items);

    return project;
}

fn openProjectDir(project_path: []const u8) !std.Io.Dir {
    return if (std.fs.path.isAbsolute(project_path))
        std.Io.Dir.openDirAbsolute(io(), project_path, .{ .iterate = true })
    else
        std.Io.Dir.cwd().openDir(io(), project_path, .{ .iterate = true });
}

fn makeProjectName(project_path: []const u8) ![]u8 {
    var end = project_path.len;
    while (end > 0 and project_path[end - 1] == std.fs.path.sep) : (end -= 1) {}
    const trimmed = project_path[0..end];
    if (trimmed.len == 0 or std.mem.eql(u8, trimmed, ".")) {
        const cwd = try std.process.currentPathAlloc(io(), allocator());
        defer allocator().free(cwd);
        return allocator().dupe(u8, std.fs.path.basename(cwd));
    }
    return allocator().dupe(u8, std.fs.path.basename(trimmed));
}

fn makeProjectRootPath(project_path: []const u8) ![]u8 {
    if (project_path.len == 0 or std.mem.eql(u8, project_path, ".")) {
        const cwd = try std.process.currentPathAlloc(io(), allocator());
        defer allocator().free(cwd);
        return allocator().dupe(u8, cwd);
    }
    return allocator().dupe(u8, project_path);
}

fn buildProjectTree(files: []const EditorFile) !FolderNode {
    var root: FolderNode = .{};
    errdefer root.deinit(allocator());

    for (files, 0..) |file, i| {
        try addFileToTree(&root, i, file.path);
    }

    return root;
}

fn addFileToTree(root: *FolderNode, file_index: usize, file_path: []const u8) !void {
    const dir_path = std.fs.path.dirname(file_path) orelse "";
    var current = root;
    var parts = std.mem.tokenizeScalar(u8, dir_path, std.fs.path.sep);
    while (parts.next()) |segment| {
        current = try ensureFolderChild(current, segment);
    }
    try current.file_indices.append(allocator(), file_index);
}

fn ensureFolderChild(parent: *FolderNode, name: []const u8) !*FolderNode {
    for (parent.folders.items) |*child| {
        if (std.mem.eql(u8, child.name, name)) return child;
    }

    const child_name = try allocator().dupe(u8, name);
    errdefer allocator().free(child_name);

    const relative_path = if (parent.relative_path.len == 0)
        try allocator().dupe(u8, name)
    else
        try std.fmt.allocPrint(allocator(), "{s}{c}{s}", .{ parent.relative_path, std.fs.path.sep, name });
    errdefer allocator().free(relative_path);

    try parent.folders.append(allocator(), .{
        .name = child_name,
        .relative_path = relative_path,
        .open = true,
    });
    return &parent.folders.items[parent.folders.items.len - 1];
}

fn shouldSkipDirectory(name: []const u8) bool {
    return std.mem.eql(u8, name, ".git") or
        std.mem.eql(u8, name, ".zig-cache") or
        std.mem.eql(u8, name, "zig-cache") or
        std.mem.eql(u8, name, "zig-out") or
        std.mem.eql(u8, name, "zig-pkg") or
        std.mem.eql(u8, name, "node_modules");
}

fn maybeAppendFilesystemFile(project: *ProjectState, root_dir: std.Io.Dir, relative_path: []const u8) !void {
    const bytes = root_dir.readFileAlloc(io(), relative_path, allocator(), .limited(max_loaded_file_bytes)) catch |err| switch (err) {
        error.FileNotFound,
        error.AccessDenied,
        error.PermissionDenied,
        error.IsDir,
        error.NameTooLong,
        error.FileTooBig,
        error.StreamTooLong,
        => return,
        else => |e| return e,
    };
    defer allocator().free(bytes);

    if (!isTextContent(bytes)) return;

    const file = try makeEditorFile(relative_path, languageForPath(relative_path), bytes);
    errdefer {
        var doomed = file;
        doomed.deinit(allocator());
    }

    try project.files.append(allocator(), file);
}

fn makeEditorFile(relative_path: []const u8, language: Language, text: []const u8) !EditorFile {
    const name = try allocator().dupe(u8, std.fs.path.basename(relative_path));
    errdefer allocator().free(name);

    const path = try allocator().dupe(u8, relative_path);
    errdefer allocator().free(path);

    const content = try makeEditableBuffer(text);
    errdefer allocator().free(content);

    return .{
        .name = name,
        .path = path,
        .language = language,
        .content = content,
    };
}

fn makeEditableBuffer(text: []const u8) ![]u8 {
    const needed = text.len + 1;
    if (needed > max_editable_file_bytes) return error.FileTooLarge;

    const capacity = @min(@max(needed + file_buffer_headroom, 256), max_editable_file_bytes);
    const buffer = try allocator().alloc(u8, capacity);
    @memcpy(buffer[0..text.len], text);
    @memset(buffer[text.len..], 0);
    return buffer;
}

fn isTextContent(bytes: []const u8) bool {
    if (bytes.len == 0) return true;
    if (std.mem.indexOfScalar(u8, bytes, 0) != null) return false;
    return std.unicode.utf8ValidateSlice(bytes);
}

fn preferredInitialFile(files: []const EditorFile) usize {
    for (files, 0..) |file, i| {
        if (std.ascii.eqlIgnoreCase(file.name, "README.md")) return i;
    }
    return 0;
}
