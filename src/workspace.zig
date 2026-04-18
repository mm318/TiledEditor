const std = @import("std");
const dvui = @import("dvui");
const app_core = @import("app_core.zig");

const app = &app_core.app;

pub fn openFile(index: usize) void {
    if (app.project.files.items[index].window_open) {
        app.pending_focus_file = index;
        return;
    }

    app.project.files.items[index].window_open = true;
    app.project.files.items[index].window_rect = findSpawnRect();
    app.pending_focus_file = index;
}

pub fn bringFileToFront(index: usize) void {
    if (!app.project.files.items[index].window_open) return;
    app.project.files.items[index].z_index = app.next_z_index;
    app.next_z_index += 1;
    app.last_active_file = index;
}

pub fn cycleFocusWindow() void {
    var order: std.ArrayList(usize) = .empty;
    defer order.deinit(app_core.allocator());

    order.ensureTotalCapacity(app_core.allocator(), app.project.files.items.len) catch return;
    const order_items = buildOpenWindowOrder(&order);
    if (order_items.len == 0) return;

    const current = app.last_active_file;
    var current_pos: ?usize = null;
    if (current) |idx| {
        for (order_items, 0..) |file_idx, pos| {
            if (file_idx == idx) {
                current_pos = pos;
                break;
            }
        }
    }

    const next_pos = if (current_pos) |pos| (pos + 1) % order_items.len else 0;
    bringFileToFront(order_items[next_pos]);
}

pub fn buildOpenWindowOrder(order: *std.ArrayList(usize)) []usize {
    order.clearRetainingCapacity();
    for (app.project.files.items, 0..) |file, i| {
        if (!file.window_open) continue;
        order.appendAssumeCapacity(i);
    }

    var i: usize = 1;
    while (i < order.items.len) : (i += 1) {
        const idx = order.items[i];
        var j = i;
        while (j > 0 and app.project.files.items[order.items[j - 1]].z_index > app.project.files.items[idx].z_index) : (j -= 1) {
            order.items[j] = order.items[j - 1];
        }
        order.items[j] = idx;
    }

    return order.items;
}

pub fn findSpawnRect() app_core.Rect {
    const width: f32 = 450;
    const height: f32 = 380;
    const gap: f32 = 20;

    var x: f32 = 200;
    var y: f32 = 150;
    var attempt: usize = 0;
    while (attempt < 64) : (attempt += 1) {
        const candidate = app_core.Rect{ .x = x, .y = y, .w = width, .h = height };
        if (!anyOpenWindowOverlaps(candidate, null)) {
            return candidate;
        }
        x += gap;
        y += gap;
    }

    return .{ .x = 200, .y = 150, .w = width, .h = height };
}

pub fn rearrangeWindows() void {
    const count = openWindowCount();
    if (count == 0) return;

    const cols: usize = @max(1, @as(usize, @intFromFloat(@ceil(std.math.sqrt(@as(f64, @floatFromInt(count)))))));
    const width: f32 = 500;
    const height: f32 = 400;
    const gap: f32 = 20;

    var nth_open: usize = 0;
    for (app.project.files.items) |*file| {
        if (!file.window_open) continue;

        const col = nth_open % cols;
        const row = nth_open / cols;
        file.window_rect = .{
            .x = 100 + @as(f32, @floatFromInt(col)) * (width + gap),
            .y = 100 + @as(f32, @floatFromInt(row)) * (height + gap),
            .w = width,
            .h = height,
        };
        nth_open += 1;
    }
}

pub fn openWindowCount() usize {
    var count: usize = 0;
    for (app.project.files.items) |file| {
        if (file.window_open) count += 1;
    }
    return count;
}

pub fn anyOpenWindowOverlaps(candidate: app_core.Rect, skip_index: ?usize) bool {
    for (app.project.files.items, 0..) |file, i| {
        if (skip_index != null and skip_index.? == i) continue;
        if (!file.window_open) continue;
        if (rectsOverlap(candidate, file.window_rect)) return true;
    }
    return false;
}

pub fn rectsOverlap(a: app_core.Rect, b: app_core.Rect) bool {
    return !(a.x + a.w <= b.x or a.x >= b.x + b.w or a.y + a.h <= b.y or a.y >= b.y + b.h);
}

pub fn sameRect(a: app_core.Rect, b: app_core.Rect) bool {
    return a.x == b.x and a.y == b.y and a.w == b.w and a.h == b.h;
}

pub fn searchQuery() []const u8 {
    return std.mem.sliceTo(app.search_buf[0..], 0);
}

pub fn matchesSearch(file: *const app_core.EditorFile, query: []const u8) bool {
    if (query.len == 0) return true;
    return containsIgnoreCase(file.name, query) or containsIgnoreCase(file.path, query);
}

pub fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0) return true;
    if (needle.len > haystack.len) return false;

    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        if (std.ascii.eqlIgnoreCase(haystack[i .. i + needle.len], needle)) {
            return true;
        }
    }
    return false;
}

pub fn countLines(text: []const u8) usize {
    if (text.len == 0) return 1;
    return std.mem.count(u8, text, "\n") + 1;
}

pub fn fileAccentColor(language: app_core.Language) app_core.Color {
    return switch (language) {
        .cpp => app_core.palette.primary,
        .yaml => app_core.palette.yaml,
        .markdown => app_core.palette.markdown,
        .zig => app_core.palette.warning,
        .text => app_core.palette.text_dim,
    };
}

pub fn iconColor(path: []const u8) app_core.Color {
    return fileAccentColor(app_core.languageForPath(path));
}

pub fn fileVirtualRect(r: app_core.Rect) app_core.Rect {
    return .{
        .x = (r.x - app.canvas.origin.x) * app.canvas.scale,
        .y = (r.y - app.canvas.origin.y) * app.canvas.scale,
        .w = r.w * app.canvas.scale,
        .h = r.h * app.canvas.scale,
    };
}

pub fn firstOpenFile() ?usize {
    for (app.project.files.items, 0..) |file, i| {
        if (file.window_open) return i;
    }
    return null;
}

pub fn activeFile() ?usize {
    if (app.pending_focus_file) |idx| {
        if (app.project.files.items[idx].window_open) return idx;
    }

    if (app.last_active_file) |idx| {
        if (app.project.files.items[idx].window_open) return idx;
    }
    return null;
}

pub fn activeLanguageLabel() []const u8 {
    if (activeFile()) |idx| {
        return switch (app.project.files.items[idx].language) {
            .cpp => "C++",
            .yaml => "YAML",
            .markdown => "Markdown",
            .zig => "Zig",
            .text => "Text",
        };
    }
    return "Spatial";
}

pub fn checkQuit() bool {
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
