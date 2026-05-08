const std = @import("std");
const dvui = @import("dvui");
const app_core = @import("app_core.zig");
const syntax_treesitter = @import("syntax_treesitter.zig");

const app = &app_core.app;
const min_window_w: f32 = 180.0;
const min_window_h: f32 = 100.0;
const default_window_w: f32 = 450.0;
const default_window_h: f32 = 380.0;
const layout_margin: f32 = 24.0;
const layout_gap: f32 = 20.0;
const spawn_gap: f32 = 12.0;
const visible_spawn_rings: i32 = 6;
const fallback_spawn_rings: i32 = 16;
const collision_search_steps: usize = 14;
const spring_pull: f32 = 0.12;
const spring_damping: f32 = 0.82;
const max_window_speed: f32 = 42.0;
const collision_iterations: usize = 10;
const collision_velocity_transfer: f32 = 0.28;
const settle_position_epsilon: f32 = 0.35;
const settle_velocity_epsilon: f32 = 0.05;

pub const TextSearchMatch = struct {
    line_number: usize,
    line_start: usize,
    line_end: usize,
    match_start: usize,
    match_end: usize,
};

pub fn openFile(index: usize) void {
    if (app.project.files.items[index].window_open) {
        app.pending_focus_file = index;
        app.pending_editor_focus = index;
        app.pending_search_focus = false;
        return;
    }

    app.project.files.items[index].window_open = true;
    app.project.files.items[index].window_rect = findSpawnRect();
    app.project.files.items[index].window_home_rect = app.project.files.items[index].window_rect;
    app.project.files.items[index].window_velocity = .{};
    app.pending_focus_file = index;
    app.pending_editor_focus = index;
    app.pending_search_focus = false;
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
    const next_file = order_items[next_pos];
    bringFileToFront(next_file);
    app.pending_editor_focus = next_file;
    app.pending_search_focus = false;
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
    const viewport = canvasViewportRect();
    const preferred = clampRectToViewport(.{
        .x = viewport.x + (viewport.w - default_window_w) * 0.5,
        .y = viewport.y + (viewport.h - default_window_h) * 0.5,
        .w = default_window_w,
        .h = default_window_h,
    }, viewport);

    if (findPackedSpawnRect(preferred, viewport, null)) |candidate| {
        return candidate;
    }

    return findNearestFreeRect(preferred, null);
}

pub fn rearrangeWindows() void {
    var order: std.ArrayList(usize) = .empty;
    defer order.deinit(app_core.allocator());
    order.ensureTotalCapacity(app_core.allocator(), app.project.files.items.len) catch return;
    const open_order = buildOpenWindowOrder(&order);
    if (open_order.len == 0) return;

    const viewport = canvasViewportRect();

    std.sort.block(usize, open_order, {}, struct {
        fn lessThan(_: void, a: usize, b: usize) bool {
            const a_rect = app.project.files.items[a].window_rect;
            const b_rect = app.project.files.items[b].window_rect;
            if (a_rect.h != b_rect.h) return a_rect.h > b_rect.h;
            if (a_rect.w != b_rect.w) return a_rect.w > b_rect.w;
            return app.project.files.items[a].z_index < app.project.files.items[b].z_index;
        }
    }.lessThan);

    var placed_rects: std.ArrayList(app_core.Rect) = .empty;
    defer placed_rects.deinit(app_core.allocator());
    placed_rects.ensureTotalCapacity(app_core.allocator(), open_order.len) catch return;

    for (open_order) |file_index| {
        var file = &app.project.files.items[file_index];
        const preferred = clampRectToViewport(.{
            .x = viewport.x + (viewport.w - file.window_rect.w) * 0.5,
            .y = viewport.y + (viewport.h - file.window_rect.h) * 0.5,
            .w = file.window_rect.w,
            .h = file.window_rect.h,
        }, viewport);

        const next_rect = if (findPackedRectAgainstRects(preferred, viewport, placed_rects.items)) |candidate|
            candidate
        else
            findNearestFreeRectAgainstRects(preferred, viewport, placed_rects.items);

        file.window_rect = next_rect;

        file.window_home_rect = file.window_rect;
        file.window_velocity = .{};
        placed_rects.appendAssumeCapacity(file.window_rect);
    }
}

pub fn commitWindowHome(index: usize) void {
    if (index >= app.project.files.items.len) return;

    var file = &app.project.files.items[index];
    file.window_home_rect = file.window_rect;
    file.window_velocity = .{};
}

pub fn commitAllWindowHomes() void {
    for (app.project.files.items) |*file| {
        if (!file.window_open) continue;
        file.window_home_rect = file.window_rect;
        file.window_velocity = .{};
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

pub fn findNearestFreeRect(preferred: app_core.Rect, skip_index: ?usize) app_core.Rect {
    const viewport = canvasViewportRect();
    const visible_preferred = clampRectToViewport(preferred, viewport);

    if (!anyOpenWindowOverlaps(visible_preferred, skip_index)) {
        return visible_preferred;
    }

    if (findSpiralFreeRect(visible_preferred, skip_index, viewport, true, visible_spawn_rings)) |candidate| {
        return candidate;
    }

    if (findSpiralFreeRect(visible_preferred, skip_index, viewport, false, fallback_spawn_rings)) |candidate| {
        return candidate;
    }

    return visible_preferred;
}

pub fn constrainRectToOpenSpace(current_rect: app_core.Rect, target_rect: app_core.Rect, skip_index: ?usize) app_core.Rect {
    if (sameRect(current_rect, target_rect)) return current_rect;
    if (!anyOpenWindowOverlaps(target_rect, skip_index)) return target_rect;
    if (anyOpenWindowOverlaps(current_rect, skip_index)) return findNearestFreeRect(target_rect, skip_index);

    var lo: f32 = 0.0;
    var hi: f32 = 1.0;
    var best = current_rect;
    var step: usize = 0;
    while (step < collision_search_steps) : (step += 1) {
        const mid = (lo + hi) * 0.5;
        const candidate = lerpRect(current_rect, target_rect, mid);
        if (anyOpenWindowOverlaps(candidate, skip_index)) {
            hi = mid;
        } else {
            lo = mid;
            best = candidate;
        }
    }

    return best;
}

pub fn stepWindowPhysics() bool {
    var order: std.ArrayList(usize) = .empty;
    defer order.deinit(app_core.allocator());
    order.ensureTotalCapacity(app_core.allocator(), app.project.files.items.len) catch return false;
    const open_order = buildOpenWindowOrder(&order);
    if (open_order.len == 0) return false;

    const manipulated = app.manipulated_window;
    const anchored = app.settling_anchor_window;
    var needs_refresh = false;

    for (open_order) |index| {
        if (isFixedWindow(index, manipulated, anchored)) {
            app.project.files.items[index].window_velocity = .{};
            continue;
        }

        var file = &app.project.files.items[index];
        const home_dx = file.window_home_rect.x - file.window_rect.x;
        const home_dy = file.window_home_rect.y - file.window_rect.y;
        const prev_rect = file.window_rect;

        file.window_velocity.x = clampVelocity((file.window_velocity.x + home_dx * spring_pull) * spring_damping);
        file.window_velocity.y = clampVelocity((file.window_velocity.y + home_dy * spring_pull) * spring_damping);
        file.window_rect.x += file.window_velocity.x;
        file.window_rect.y += file.window_velocity.y;

        if (!sameRect(prev_rect, file.window_rect)) {
            needs_refresh = true;
        }
    }

    var iter: usize = 0;
    while (iter < collision_iterations) : (iter += 1) {
        var separated_any = false;

        var i: usize = 0;
        while (i < open_order.len) : (i += 1) {
            const a_index = open_order[i];
            if (!app.project.files.items[a_index].window_open) continue;

            var j: usize = i + 1;
            while (j < open_order.len) : (j += 1) {
                const b_index = open_order[j];
                if (!app.project.files.items[b_index].window_open) continue;

                if (resolvePairOverlap(a_index, b_index, manipulated, anchored)) {
                    separated_any = true;
                    needs_refresh = true;
                }
            }
        }

        if (!separated_any) break;
    }

    for (open_order) |index| {
        if (isFixedWindow(index, manipulated, anchored)) continue;
        if (snapWindowToHome(index)) {
            needs_refresh = true;
        }
    }

    return needs_refresh or physicsStillActive(open_order, manipulated, anchored);
}

pub fn searchQuery() []const u8 {
    return std.mem.sliceTo(app.search_buf[0..], 0);
}

pub fn findTextSearchMatch(file: *const app_core.EditorFile, query: []const u8) ?TextSearchMatch {
    if (query.len == 0) return null;

    const text = app_core.fileText(file);
    const match_start = indexOfIgnoreCase(text, query) orelse return null;
    const match_end = match_start + query.len;

    const line_start = if (std.mem.lastIndexOfScalar(u8, text[0..match_start], '\n')) |idx|
        idx + 1
    else
        0;
    const line_end = std.mem.indexOfScalarPos(u8, text, match_end, '\n') orelse text.len;

    return .{
        .line_number = 1 + std.mem.count(u8, text[0..match_start], "\n"),
        .line_start = line_start,
        .line_end = line_end,
        .match_start = match_start,
        .match_end = match_end,
    };
}

pub fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    return indexOfIgnoreCase(haystack, needle) != null;
}

pub fn indexOfIgnoreCase(haystack: []const u8, needle: []const u8) ?usize {
    if (needle.len == 0) return 0;
    if (needle.len > haystack.len) return null;

    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        if (std.ascii.eqlIgnoreCase(haystack[i .. i + needle.len], needle)) {
            return i;
        }
    }
    return null;
}

pub fn searchMatchPreview(buffer: []u8, file: *const app_core.EditorFile, match: TextSearchMatch) []const u8 {
    const context_before: usize = 28;
    const context_after: usize = 60;
    const line = app_core.fileText(file)[match.line_start..match.line_end];
    const match_offset = match.match_start - match.line_start;

    const snippet_start = if (match_offset > context_before) match_offset - context_before else 0;
    const trailing_match = match_offset + (match.match_end - match.match_start);
    const snippet_end = @min(line.len, trailing_match + context_after);

    var out_len: usize = 0;
    if (snippet_start > 0) {
        buffer[out_len..][0..3].* = "...".*;
        out_len += 3;
    }

    const body = std.mem.trim(u8, line[snippet_start..snippet_end], &std.ascii.whitespace);
    @memcpy(buffer[out_len..][0..body.len], body);
    out_len += body.len;

    if (snippet_end < line.len) {
        buffer[out_len..][0..3].* = "...".*;
        out_len += 3;
    }

    return buffer[0..out_len];
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

pub fn languageLabel(language: app_core.Language) []const u8 {
    return switch (language) {
        .cpp => "C++",
        .yaml => "YAML",
        .markdown => "Markdown",
        .zig => "Zig",
        .text => "Text",
    };
}

pub fn fileLanguageLabel(path: []const u8, language: app_core.Language) []const u8 {
    return syntax_treesitter.displayNameForPath(path) orelse languageLabel(language);
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
        const file = &app.project.files.items[idx];
        return fileLanguageLabel(file.path, file.language);
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

fn canvasViewportRect() app_core.Rect {
    if (app.canvas.scroll_info.viewport.empty()) {
        const sidebar_w: f32 = if (app.sidebar_open) app_core.explorer_width else 0.0;
        const fallback_w: f32 = 1200.0 - app_core.rail_width - sidebar_w;
        return .{ .x = 100 + sidebar_w, .y = 80, .w = fallback_w, .h = 760 };
    }

    const scale = @max(app.canvas.scale, 0.001);
    const sidebar_w = if (app.sidebar_open) app_core.explorer_width / scale else 0.0;
    return .{
        .x = app.canvas.scroll_info.viewport.x / scale + app.canvas.origin.x + sidebar_w,
        .y = app.canvas.scroll_info.viewport.y / scale + app.canvas.origin.y,
        .w = @max(0.0, app.canvas.scroll_info.viewport.w / scale - sidebar_w),
        .h = app.canvas.scroll_info.viewport.h / scale,
    };
}

fn findPackedSpawnRect(preferred: app_core.Rect, viewport: app_core.Rect, skip_index: ?usize) ?app_core.Rect {
    var best: ?app_core.Rect = null;
    var best_score = std.math.inf(f32);

    for (app.project.files.items, 0..) |file, i| {
        if (!file.window_open) continue;
        if (skip_index != null and skip_index.? == i) continue;

        const rect = file.window_rect;
        const y_positions = [_]f32{
            rect.y,
            rect.y + (rect.h - preferred.h) * 0.5,
            rect.y + rect.h - preferred.h,
        };
        const x_positions = [_]f32{
            rect.x,
            rect.x + (rect.w - preferred.w) * 0.5,
            rect.x + rect.w - preferred.w,
        };

        for (y_positions) |candidate_y| {
            considerPackedCandidate(.{
                .x = rect.x + rect.w + spawn_gap,
                .y = candidate_y,
                .w = preferred.w,
                .h = preferred.h,
            }, preferred, viewport, skip_index, &best, &best_score);
            considerPackedCandidate(.{
                .x = rect.x - preferred.w - spawn_gap,
                .y = candidate_y,
                .w = preferred.w,
                .h = preferred.h,
            }, preferred, viewport, skip_index, &best, &best_score);
        }

        for (x_positions) |candidate_x| {
            considerPackedCandidate(.{
                .x = candidate_x,
                .y = rect.y + rect.h + spawn_gap,
                .w = preferred.w,
                .h = preferred.h,
            }, preferred, viewport, skip_index, &best, &best_score);
            considerPackedCandidate(.{
                .x = candidate_x,
                .y = rect.y - preferred.h - spawn_gap,
                .w = preferred.w,
                .h = preferred.h,
            }, preferred, viewport, skip_index, &best, &best_score);
        }
    }

    return best;
}

fn findPackedRectAgainstRects(preferred: app_core.Rect, viewport: app_core.Rect, rects: []const app_core.Rect) ?app_core.Rect {
    var best: ?app_core.Rect = null;
    var best_score = std.math.inf(f32);

    for (rects) |rect| {
        const y_positions = [_]f32{
            rect.y,
            rect.y + (rect.h - preferred.h) * 0.5,
            rect.y + rect.h - preferred.h,
        };
        const x_positions = [_]f32{
            rect.x,
            rect.x + (rect.w - preferred.w) * 0.5,
            rect.x + rect.w - preferred.w,
        };

        for (y_positions) |candidate_y| {
            considerPackedRectCandidate(.{
                .x = rect.x + rect.w + spawn_gap,
                .y = candidate_y,
                .w = preferred.w,
                .h = preferred.h,
            }, preferred, viewport, rects, &best, &best_score);
            considerPackedRectCandidate(.{
                .x = rect.x - preferred.w - spawn_gap,
                .y = candidate_y,
                .w = preferred.w,
                .h = preferred.h,
            }, preferred, viewport, rects, &best, &best_score);
        }

        for (x_positions) |candidate_x| {
            considerPackedRectCandidate(.{
                .x = candidate_x,
                .y = rect.y + rect.h + spawn_gap,
                .w = preferred.w,
                .h = preferred.h,
            }, preferred, viewport, rects, &best, &best_score);
            considerPackedRectCandidate(.{
                .x = candidate_x,
                .y = rect.y - preferred.h - spawn_gap,
                .w = preferred.w,
                .h = preferred.h,
            }, preferred, viewport, rects, &best, &best_score);
        }
    }

    return best;
}

fn clampRectToViewport(rect: app_core.Rect, viewport: app_core.Rect) app_core.Rect {
    return .{
        .x = clampAxisToViewport(rect.x, rect.w, viewport.x, viewport.w),
        .y = clampAxisToViewport(rect.y, rect.h, viewport.y, viewport.h),
        .w = rect.w,
        .h = rect.h,
    };
}

fn clampAxisToViewport(pos: f32, size: f32, viewport_start: f32, viewport_size: f32) f32 {
    const max_pos = viewport_start + viewport_size - size - layout_margin;
    const min_pos = viewport_start + layout_margin;

    if (max_pos >= min_pos) {
        return std.math.clamp(pos, min_pos, max_pos);
    }

    return viewport_start + (viewport_size - size) * 0.5;
}

fn findSpiralFreeRect(base_rect: app_core.Rect, skip_index: ?usize, viewport: app_core.Rect, require_viewport_overlap: bool, max_rings: i32) ?app_core.Rect {
    const step_x = @max(base_rect.w * 0.45, min_window_w * 0.7);
    const step_y = @max(base_rect.h * 0.45, min_window_h * 0.7);

    var ring: i32 = 0;
    while (ring <= max_rings) : (ring += 1) {
        var dy: i32 = -ring;
        while (dy <= ring) : (dy += 1) {
            var dx: i32 = -ring;
            while (dx <= ring) : (dx += 1) {
                if (ring != 0 and dx != -ring and dx != ring and dy != -ring and dy != ring) continue;

                const candidate = app_core.Rect{
                    .x = base_rect.x + @as(f32, @floatFromInt(dx)) * step_x,
                    .y = base_rect.y + @as(f32, @floatFromInt(dy)) * step_y,
                    .w = base_rect.w,
                    .h = base_rect.h,
                };

                if (require_viewport_overlap and !rectsOverlap(candidate, viewport)) continue;
                if (!anyOpenWindowOverlaps(candidate, skip_index)) return candidate;
            }
        }
    }

    return null;
}

fn findNearestFreeRectAgainstRects(preferred: app_core.Rect, viewport: app_core.Rect, rects: []const app_core.Rect) app_core.Rect {
    const visible_preferred = clampRectToViewport(preferred, viewport);

    if (!rectOverlapsAny(visible_preferred, rects)) {
        return visible_preferred;
    }

    if (findSpiralFreeRectAgainstRects(visible_preferred, viewport, rects, true, visible_spawn_rings)) |candidate| {
        return candidate;
    }

    if (findSpiralFreeRectAgainstRects(visible_preferred, viewport, rects, false, fallback_spawn_rings)) |candidate| {
        return candidate;
    }

    return visible_preferred;
}

fn findSpiralFreeRectAgainstRects(base_rect: app_core.Rect, viewport: app_core.Rect, rects: []const app_core.Rect, require_viewport_overlap: bool, max_rings: i32) ?app_core.Rect {
    const step_x = @max(base_rect.w * 0.45, min_window_w * 0.7);
    const step_y = @max(base_rect.h * 0.45, min_window_h * 0.7);

    var ring: i32 = 0;
    while (ring <= max_rings) : (ring += 1) {
        var dy: i32 = -ring;
        while (dy <= ring) : (dy += 1) {
            var dx: i32 = -ring;
            while (dx <= ring) : (dx += 1) {
                if (ring != 0 and dx != -ring and dx != ring and dy != -ring and dy != ring) continue;

                const candidate = app_core.Rect{
                    .x = base_rect.x + @as(f32, @floatFromInt(dx)) * step_x,
                    .y = base_rect.y + @as(f32, @floatFromInt(dy)) * step_y,
                    .w = base_rect.w,
                    .h = base_rect.h,
                };

                if (require_viewport_overlap and !rectsOverlap(candidate, viewport)) continue;
                if (!rectOverlapsAny(candidate, rects)) return candidate;
            }
        }
    }

    return null;
}

fn considerPackedCandidate(candidate: app_core.Rect, preferred: app_core.Rect, viewport: app_core.Rect, skip_index: ?usize, best: *?app_core.Rect, best_score: *f32) void {
    considerPackedCandidateVariant(candidate, preferred, viewport, skip_index, best, best_score);

    const clamped_candidate = clampRectToViewport(candidate, viewport);
    if (!sameRect(clamped_candidate, candidate)) {
        considerPackedCandidateVariant(clamped_candidate, preferred, viewport, skip_index, best, best_score);
    }
}

fn considerPackedRectCandidate(candidate: app_core.Rect, preferred: app_core.Rect, viewport: app_core.Rect, rects: []const app_core.Rect, best: *?app_core.Rect, best_score: *f32) void {
    considerPackedRectCandidateVariant(candidate, preferred, viewport, rects, best, best_score);

    const clamped_candidate = clampRectToViewport(candidate, viewport);
    if (!sameRect(clamped_candidate, candidate)) {
        considerPackedRectCandidateVariant(clamped_candidate, preferred, viewport, rects, best, best_score);
    }
}

fn lerpRect(a: app_core.Rect, b: app_core.Rect, t: f32) app_core.Rect {
    return .{
        .x = std.math.lerp(a.x, b.x, t),
        .y = std.math.lerp(a.y, b.y, t),
        .w = std.math.lerp(a.w, b.w, t),
        .h = std.math.lerp(a.h, b.h, t),
    };
}

fn spawnCandidateScore(candidate: app_core.Rect, preferred: app_core.Rect, viewport: app_core.Rect) f32 {
    const preferred_center = rectCenter(preferred);
    const candidate_center = rectCenter(candidate);
    const dx = candidate_center.x - preferred_center.x;
    const dy = candidate_center.y - preferred_center.y;
    const invisible_area = candidate.w * candidate.h - rectIntersectionArea(candidate, viewport);
    return invisible_area * 4.0 + dx * dx + dy * dy;
}

fn considerPackedCandidateVariant(candidate: app_core.Rect, preferred: app_core.Rect, viewport: app_core.Rect, skip_index: ?usize, best: *?app_core.Rect, best_score: *f32) void {
    if (anyOpenWindowOverlaps(candidate, skip_index)) return;

    const visible_area = rectIntersectionArea(candidate, viewport);
    if (visible_area <= 0.0) return;

    const score = spawnCandidateScore(candidate, preferred, viewport);
    if (best.* == null or score < best_score.*) {
        best.* = candidate;
        best_score.* = score;
    }
}

fn considerPackedRectCandidateVariant(candidate: app_core.Rect, preferred: app_core.Rect, viewport: app_core.Rect, rects: []const app_core.Rect, best: *?app_core.Rect, best_score: *f32) void {
    if (rectOverlapsAny(candidate, rects)) return;

    const visible_area = rectIntersectionArea(candidate, viewport);
    if (visible_area <= 0.0) return;

    const score = spawnCandidateScore(candidate, preferred, viewport);
    if (best.* == null or score < best_score.*) {
        best.* = candidate;
        best_score.* = score;
    }
}

fn resolvePairOverlap(a_index: usize, b_index: usize, manipulated: ?usize, anchored: ?usize) bool {
    const a_rect = app.project.files.items[a_index].window_rect;
    const b_rect = app.project.files.items[b_index].window_rect;
    const correction = overlapCorrection(a_index, b_index, a_rect, b_rect) orelse return false;

    const a_fixed = isFixedWindow(a_index, manipulated, anchored);
    const b_fixed = isFixedWindow(b_index, manipulated, anchored);

    if (a_fixed and b_fixed) return false;

    if (a_fixed) {
        applyCollisionOffset(b_index, correction.x, correction.y);
    } else if (b_fixed) {
        applyCollisionOffset(a_index, -correction.x, -correction.y);
    } else {
        applyCollisionOffset(a_index, -correction.x * 0.5, -correction.y * 0.5);
        applyCollisionOffset(b_index, correction.x * 0.5, correction.y * 0.5);
    }

    return true;
}

fn overlapCorrection(a_index: usize, b_index: usize, a_rect: app_core.Rect, b_rect: app_core.Rect) ?app_core.Point {
    const a_center = rectCenter(a_rect);
    const b_center = rectCenter(b_rect);
    const dx = b_center.x - a_center.x;
    const dy = b_center.y - a_center.y;
    const overlap_x = (a_rect.w + b_rect.w) * 0.5 - @abs(dx);
    const overlap_y = (a_rect.h + b_rect.h) * 0.5 - @abs(dy);
    if (overlap_x <= 0.0 or overlap_y <= 0.0) return null;

    const a_home = rectCenter(app.project.files.items[a_index].window_home_rect);
    const b_home = rectCenter(app.project.files.items[b_index].window_home_rect);
    const dir_x = axisSign(dx, b_home.x - a_home.x, a_index < b_index);
    const dir_y = axisSign(dy, b_home.y - a_home.y, true);

    const basis_x = overlap_y;
    const basis_y = overlap_x;
    const basis_len = std.math.sqrt(basis_x * basis_x + basis_y * basis_y);
    if (basis_len <= 0.0001) {
        return if (overlap_x <= overlap_y)
            .{ .x = dir_x * overlap_x, .y = 0.0 }
        else
            .{ .x = 0.0, .y = dir_y * overlap_y };
    }

    const magnitude = @min(overlap_x, overlap_y) + 0.01;
    return .{
        .x = dir_x * (basis_x / basis_len) * magnitude,
        .y = dir_y * (basis_y / basis_len) * magnitude,
    };
}

fn applyCollisionOffset(index: usize, dx: f32, dy: f32) void {
    if (dx == 0.0 and dy == 0.0) return;

    var file = &app.project.files.items[index];
    file.window_rect.x += dx;
    file.window_rect.y += dy;
    file.window_velocity.x = clampVelocity(file.window_velocity.x + dx * collision_velocity_transfer);
    file.window_velocity.y = clampVelocity(file.window_velocity.y + dy * collision_velocity_transfer);
}

fn snapWindowToHome(index: usize) bool {
    var file = &app.project.files.items[index];
    const close_x = @abs(file.window_home_rect.x - file.window_rect.x) <= settle_position_epsilon;
    const close_y = @abs(file.window_home_rect.y - file.window_rect.y) <= settle_position_epsilon;
    const slow_x = @abs(file.window_velocity.x) <= settle_velocity_epsilon;
    const slow_y = @abs(file.window_velocity.y) <= settle_velocity_epsilon;
    if (!(close_x and close_y and slow_x and slow_y)) return false;
    if (anyOpenWindowOverlaps(file.window_home_rect, index)) return false;

    if (file.window_rect.x == file.window_home_rect.x and
        file.window_rect.y == file.window_home_rect.y and
        file.window_velocity.x == 0.0 and
        file.window_velocity.y == 0.0)
    {
        return false;
    }

    file.window_rect.x = file.window_home_rect.x;
    file.window_rect.y = file.window_home_rect.y;
    file.window_velocity = .{};
    return true;
}

fn physicsStillActive(open_order: []const usize, manipulated: ?usize, anchored: ?usize) bool {
    for (open_order) |index| {
        if (isFixedWindow(index, manipulated, anchored)) continue;

        const file = app.project.files.items[index];
        if (@abs(file.window_home_rect.x - file.window_rect.x) > settle_position_epsilon) return true;
        if (@abs(file.window_home_rect.y - file.window_rect.y) > settle_position_epsilon) return true;
        if (@abs(file.window_velocity.x) > settle_velocity_epsilon) return true;
        if (@abs(file.window_velocity.y) > settle_velocity_epsilon) return true;
    }

    var i: usize = 0;
    while (i < open_order.len) : (i += 1) {
        const a_index = open_order[i];
        if (!app.project.files.items[a_index].window_open) continue;

        var j: usize = i + 1;
        while (j < open_order.len) : (j += 1) {
            const b_index = open_order[j];
            if (!app.project.files.items[b_index].window_open) continue;
            if (rectsOverlap(app.project.files.items[a_index].window_rect, app.project.files.items[b_index].window_rect)) {
                return true;
            }
        }
    }

    return false;
}

fn rectCenter(rect: app_core.Rect) app_core.Point {
    return .{
        .x = rect.x + rect.w * 0.5,
        .y = rect.y + rect.h * 0.5,
    };
}

fn rectIntersectionArea(a: app_core.Rect, b: app_core.Rect) f32 {
    const left = @max(a.x, b.x);
    const top = @max(a.y, b.y);
    const right = @min(a.x + a.w, b.x + b.w);
    const bottom = @min(a.y + a.h, b.y + b.h);
    const w = right - left;
    const h = bottom - top;
    if (w <= 0.0 or h <= 0.0) return 0.0;
    return w * h;
}

fn rectOverlapsAny(candidate: app_core.Rect, rects: []const app_core.Rect) bool {
    for (rects) |rect| {
        if (rectsOverlap(candidate, rect)) return true;
    }
    return false;
}

fn axisSign(primary: f32, secondary: f32, default_positive: bool) f32 {
    if (primary > 0.001) return 1.0;
    if (primary < -0.001) return -1.0;
    if (secondary > 0.001) return 1.0;
    if (secondary < -0.001) return -1.0;
    return if (default_positive) 1.0 else -1.0;
}

fn clampVelocity(value: f32) f32 {
    return std.math.clamp(value, -max_window_speed, max_window_speed);
}

fn isFixedWindow(index: usize, manipulated: ?usize, anchored: ?usize) bool {
    if (manipulated != null and manipulated.? == index) return true;
    if (anchored != null and anchored.? == index) return true;
    return false;
}
