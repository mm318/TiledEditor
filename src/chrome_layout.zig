const std = @import("std");
const dvui = @import("dvui");
const app_core = @import("app_core.zig");
const workspace = @import("workspace.zig");
const navigation_ui = @import("navigation_ui.zig");
const spatial_canvas = @import("spatial_canvas.zig");

const Font = app_core.Font;
const Rect = app_core.Rect;
const entypo = app_core.entypo;
const palette = app_core.palette;
const app = &app_core.app;

pub fn drawAppChrome() void {
    var root = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .both,
        .background = true,
        .color_fill = palette.background,
    });
    defer root.deinit();

    drawTopBar();

    {
        var body = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .both,
        });
        defer body.deinit();

        drawRail();
        drawMainArea();
    }

    navigation_ui.drawFooter();
}

fn drawTopBar() void {
    var header = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .horizontal,
        .min_size_content = .{ .h = app_core.header_height },
        .max_size_content = .height(app_core.header_height),
        .background = true,
        .color_fill = palette.surface,
        .color_border = palette.outline_soft,
        .border = .{ .h = 1 },
        .padding = .{ .x = 16, .y = 8, .w = 16, .h = 8 },
    });
    defer header.deinit();

    {
        var left = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .gravity_y = 0.5,
        });
        defer left.deinit();

        dvui.labelNoFmt(@src(), "Monolith", .{ .align_y = 0.5 }, .{
            .font = Font.theme(.title),
            .color_text = palette.primary,
        });

        _ = dvui.spacer(@src(), .{ .min_size_content = .width(24) });
        _ = topMenuButton(1, "File", true);
        _ = topMenuButton(2, "Edit", false);
        _ = topMenuButton(3, "View", false);
        _ = topMenuButton(4, "Terminal", false);
    }
}

fn topMenuButton(id_extra: usize, label: []const u8, active: bool) bool {
    return dvui.button(@src(), label, .{}, .{
        .id_extra = id_extra,
        .background = false,
        .border = .{},
        .padding = .{ .x = 6, .y = 2, .w = 6, .h = 2 },
        .gravity_y = 0.5,
        .color_text = if (active) palette.text else palette.text_dim,
        .font = Font.theme(.body).withWeight(if (active) .bold else .normal).larger(-1),
    });
}

fn drawRail() void {
    var rail = dvui.box(@src(), .{}, .{
        .min_size_content = .{ .w = app_core.rail_width },
        .max_size_content = .width(app_core.rail_width),
        .expand = .vertical,
        .background = true,
        .color_fill = palette.surface_low,
        .color_border = palette.outline_soft,
        .border = .{ .w = 1 },
        .padding = .{ .x = 0, .y = 12, .w = 0, .h = 12 },
    });
    defer rail.deinit();

    {
        var logo = dvui.box(@src(), .{}, .{
            .gravity_x = 0.5,
            .background = true,
            .color_fill = palette.primary.opacity(0.08),
            .corner_radius = Rect.all(8),
            .min_size_content = .{ .w = 32, .h = 32 },
        });
        defer logo.deinit();
        dvui.icon(@src(), "logo", entypo.tools, .{}, .{
            .expand = .both,
            .color_text = palette.primary,
        });
    }

    _ = dvui.spacer(@src(), .{ .min_size_content = .height(20) });

    if (railButton(10, "Explorer", entypo.folder, app.rail_mode == .explorer and app.sidebar_open)) {
        if (app.rail_mode == .explorer) {
            app.sidebar_open = !app.sidebar_open;
        } else {
            app.rail_mode = .explorer;
            app.sidebar_open = true;
        }
        if (app.rail_mode != .search) {
            app.pending_search_focus = false;
        }
    }
    if (railButton(11, "Search", entypo.magnifying_glass, app.rail_mode == .search and app.sidebar_open)) {
        if (app.rail_mode == .search) {
            app.sidebar_open = !app.sidebar_open;
        } else {
            app.rail_mode = .search;
            app.sidebar_open = true;
        }
        app.pending_search_focus = app.sidebar_open and app.rail_mode == .search;
    }
    if (railButton(12, "Layout", entypo.grid, app.rail_mode == .layout and app.sidebar_open)) {
        if (app.rail_mode == .layout) {
            app.sidebar_open = !app.sidebar_open;
        } else {
            app.rail_mode = .layout;
            app.sidebar_open = true;
        }
        if (app.rail_mode != .search) {
            app.pending_search_focus = false;
        }
    }

    _ = dvui.spacer(@src(), .{ .expand = .vertical });
    _ = railButton(13, "Settings", entypo.cog, false);
}

fn railButton(id_extra: usize, label: []const u8, icon_bytes: []const u8, active: bool) bool {
    var bw: dvui.ButtonWidget = undefined;
    bw.init(@src(), .{}, .{
        .id_extra = id_extra,
        .expand = .horizontal,
        .background = true,
        .color_fill = if (active) palette.surface_high else palette.surface_low,
        .color_fill_hover = if (active) palette.surface_highest else palette.surface,
        .color_fill_press = palette.surface_highest,
        .color_text = if (active) palette.primary else palette.text_dim,
        .color_border = if (active) palette.primary else palette.surface_low,
        .border = .{ .w = if (active) 2 else 0 },
        .corner_radius = .{},
        .padding = .{ .x = 0, .y = 8, .w = 0, .h = 8 },
    });
    bw.processEvents();
    bw.drawBackground();

    {
        var col = dvui.box(@src(), .{}, .{
            .expand = .both,
        });
        defer col.deinit();

        dvui.icon(@src(), label, icon_bytes, .{}, .{
            .color_text = if (active) palette.primary else palette.text_dim,
            .gravity_x = 0.5,
            .min_size_content = .all(18),
        });

        dvui.labelNoFmt(@src(), label, .{ .align_x = 0.5 }, .{
            .expand = .horizontal,
            .font = Font.theme(.body).larger(-4).withWeight(.bold),
            .color_text = if (active) palette.primary else palette.text_dim,
        });
    }

    const clicked = bw.clicked();
    bw.drawFocus();
    bw.deinit();
    return clicked;
}

fn drawSidebarPanel() void {
    var panel = dvui.box(@src(), .{}, .{
        .min_size_content = .{ .w = app_core.explorer_width },
        .max_size_content = .width(app_core.explorer_width),
        .expand = .vertical,
        .background = true,
        .color_fill = palette.panel,
        .color_border = palette.outline_soft,
        .border = .{ .w = 1 },
    });

    const panel_rs = panel.data().rectScale();
    dvui.subwindowAdd(panel.data().id, panel.data().rect, panel_rs.r, false, null, true);
    const prev_sw = dvui.subwindowCurrentSet(panel.data().id, .cast(panel.data().rect));
    defer {
        _ = dvui.subwindowCurrentSet(prev_sw.id, prev_sw.rect);
        panel.deinit();
    }

    switch (app.rail_mode) {
        .explorer => drawExplorerPanel(),
        .search => drawSearchPanel(),
        .layout => drawLayoutPanel(),
    }
}

fn drawExplorerPanel() void {
    drawPanelHeader("Project Explorer", app.project.root_path);

    var scroll = dvui.scrollArea(@src(), .{}, .{
        .expand = .both,
        .background = false,
        .padding = .{ .x = 0, .y = 0, .w = 0, .h = 8 },
    });
    defer scroll.deinit();

    var visible_count: usize = 0;
    const root_expanded = app.explorer_root_open;

    if (explorerRow(100, app.project.name, entypo.folder, 0, true, root_expanded, true)) {
        app.explorer_root_open = !app.explorer_root_open;
    }

    if (root_expanded) {
        drawFolderNode(&app.project.tree, 18, &visible_count);
    }

    if (visible_count == 0) {
        drawEmptyPanelState("No text files loaded");
    }
}

fn drawSearchPanel() void {
    const query = workspace.searchQuery();
    drawPanelHeader("Search", "Find text inside loaded files");
    drawSearchPanelField();

    if (query.len == 0) {
        drawEmptyPanelState("Type in the search box to find matching file contents");
        return;
    }

    var scroll = dvui.scrollArea(@src(), .{}, .{
        .expand = .both,
        .background = false,
        .padding = .{ .x = 8, .y = 0, .w = 8, .h = 8 },
    });
    defer scroll.deinit();

    var result_count: usize = 0;
    for (app.project.files.items, 0..) |file, i| {
        const match = workspace.findTextSearchMatch(&file, query) orelse continue;
        result_count += 1;

        if (searchResultRow(20_000 + i, i, &file, match)) {
            workspace.openFile(i);
        }
    }

    if (result_count == 0) {
        drawEmptyPanelState("No matching file contents");
    }
}

fn drawLayoutPanel() void {
    drawPanelHeader("Layout", "Window and canvas tools");

    var scroll = dvui.scrollArea(@src(), .{}, .{
        .expand = .both,
        .background = false,
        .padding = .{ .x = 14, .y = 6, .w = 14, .h = 10 },
    });
    defer scroll.deinit();

    {
        var stats = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .horizontal,
        });
        defer stats.deinit();

        drawStatCard(1, "Files", app.project.files.items.len, palette.primary);
        _ = dvui.spacer(@src(), .{ .min_size_content = .width(8) });
        drawStatCard(2, "Open", workspace.openWindowCount(), palette.success);
    }

    _ = dvui.spacer(@src(), .{ .min_size_content = .height(14) });

    if (layoutActionButton(1, "Rearrange Windows", entypo.grid, "Reset open windows into a grid")) {
        workspace.rearrangeWindows();
    }
    if (layoutActionButton(2, "Center Canvas", entypo.compass, "Reset zoom and center the canvas viewport")) {
        app.canvas.center_requested = true;
    }
    if (layoutActionButton(3, "Cycle Focus", entypo.cycle, "Rotate focus through currently open windows")) {
        workspace.cycleFocusWindow();
    }

    _ = dvui.spacer(@src(), .{ .min_size_content = .height(16) });

    dvui.labelNoFmt(@src(), "Open Windows", .{}, .{
        .font = Font.theme(.heading).larger(-1),
        .color_text = palette.text_dim,
    });
    _ = dvui.spacer(@src(), .{ .min_size_content = .height(8) });

    var order: std.ArrayList(usize) = .empty;
    defer order.deinit(app_core.allocator());
    order.ensureTotalCapacity(app_core.allocator(), app.project.files.items.len) catch return;
    const open_order = workspace.buildOpenWindowOrder(&order);

    if (open_order.len == 0) {
        drawEmptyPanelState("No open windows");
        return;
    }

    for (open_order) |file_index| {
        if (layoutWindowRow(30_000 + file_index, file_index, &app.project.files.items[file_index])) {
            workspace.bringFileToFront(file_index);
        }
    }
}

fn explorerRow(id_extra: usize, label: []const u8, icon_bytes: []const u8, indent: f32, active: bool, expanded: bool, has_disclosure: bool) bool {
    var bw: dvui.ButtonWidget = undefined;
    bw.init(@src(), .{}, .{
        .id_extra = id_extra,
        .expand = .horizontal,
        .background = true,
        .color_fill = if (active) palette.surface_high.opacity(0.5) else palette.panel,
        .color_fill_hover = palette.surface_high.opacity(0.45),
        .color_fill_press = palette.surface_high.opacity(0.7),
        .color_border = palette.panel,
        .padding = .{ .x = 12, .y = 6, .w = 12, .h = 6 },
        .border = .{},
        .corner_radius = .{},
    });
    bw.processEvents();
    bw.drawBackground();

    {
        var row = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .horizontal,
        });
        defer row.deinit();

        _ = dvui.spacer(@src(), .{ .min_size_content = .width(indent) });

        if (has_disclosure) {
            dvui.icon(@src(), "disclosure", if (expanded) entypo.chevron_small_down else entypo.chevron_small_right, .{}, .{
                .min_size_content = .all(12),
                .color_text = palette.text_dim,
                .gravity_y = 0.5,
            });
        } else {
            _ = dvui.spacer(@src(), .{ .min_size_content = .width(12) });
        }

        _ = dvui.spacer(@src(), .{ .min_size_content = .width(6) });
        dvui.icon(@src(), label, icon_bytes, .{}, .{
            .min_size_content = .all(14),
            .color_text = if (has_disclosure) palette.primary else workspace.iconColor(label),
            .gravity_y = 0.5,
        });
        _ = dvui.spacer(@src(), .{ .min_size_content = .width(8) });
        dvui.labelNoFmt(@src(), label, .{ .align_y = 0.5 }, .{
            .expand = .horizontal,
            .font = Font.theme(.mono).larger(-1),
            .color_text = if (active) palette.text else palette.text_dim,
        });
    }

    const clicked = bw.clicked();
    bw.drawFocus();
    bw.deinit();
    return clicked;
}

fn drawPanelHeader(title: []const u8, subtitle: []const u8) void {
    {
        var title_row = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .horizontal,
            .padding = .{ .x = 14, .y = 14, .w = 14, .h = 10 },
        });
        defer title_row.deinit();

        dvui.labelNoFmt(@src(), title, .{ .align_y = 0.5 }, .{
            .font = Font.theme(.heading).larger(-1),
            .color_text = palette.text_dim,
        });
        _ = dvui.spacer(@src(), .{ .expand = .horizontal });
        dvui.icon(@src(), "more", entypo.menu, .{}, .{
            .color_text = palette.text_soft,
            .min_size_content = .all(14),
            .gravity_y = 0.5,
        });
    }

    if (subtitle.len != 0) {
        var subtitle_box = dvui.box(@src(), .{}, .{
            .expand = .horizontal,
            .padding = .{ .x = 14, .y = 0, .w = 14, .h = 10 },
        });
        defer subtitle_box.deinit();

        dvui.labelNoFmt(@src(), subtitle, .{}, .{
            .font = Font.theme(.body).larger(-2),
            .color_text = palette.text_soft,
        });
    }
}

fn drawEmptyPanelState(text_value: []const u8) void {
    var center = dvui.box(@src(), .{}, .{
        .expand = .both,
        .padding = .{ .x = 18, .y = 18, .w = 18, .h = 18 },
    });
    defer center.deinit();

    var text = dvui.textLayout(@src(), .{}, .{
        .expand = .both,
        .background = false,
    });
    defer text.deinit();

    text.addText(text_value, .{
        .color_text = palette.text_dim,
    });
}

fn drawFolderNode(node: *app_core.FolderNode, indent: f32, visible_count: *usize) void {
    for (node.folders.items) |*folder| {
        if (!folderHasVisibleEntries(folder)) continue;

        const expanded = folder.open;
        if (explorerRow(folderRowId(folder.relative_path), folder.name, entypo.folder, indent, false, expanded, true)) {
            folder.open = !folder.open;
        }

        if (expanded) {
            drawFolderNode(folder, indent + 18, visible_count);
        }
    }

    for (node.file_indices.items) |file_index| {
        const file = &app.project.files.items[file_index];
        visible_count.* += 1;

        if (explorerRow(40_000 + file_index, file.name, entypo.text_document, indent, file.window_open, false, false)) {
            workspace.openFile(file_index);
        }
    }
}

fn folderHasVisibleEntries(node: *const app_core.FolderNode) bool {
    if (node.file_indices.items.len != 0) return true;
    for (node.folders.items) |*folder| {
        if (folderHasVisibleEntries(folder)) return true;
    }
    return false;
}

fn folderRowId(relative_path: []const u8) usize {
    return 10_000 ^ @as(usize, @truncate(std.hash.Wyhash.hash(0, relative_path)));
}

fn searchResultRow(id_extra: usize, file_index: usize, file: *const app_core.EditorFile, match: workspace.TextSearchMatch) bool {
    var preview_buf: [256]u8 = undefined;
    const preview = workspace.searchMatchPreview(&preview_buf, file, match);

    var bw: dvui.ButtonWidget = undefined;
    bw.init(@src(), .{}, .{
        .id_extra = id_extra,
        .expand = .horizontal,
        .background = true,
        .color_fill = if (file.window_open) palette.surface_high.opacity(0.48) else palette.panel.opacity(0.6),
        .color_fill_hover = palette.surface_high.opacity(0.42),
        .color_fill_press = palette.surface_high.opacity(0.7),
        .color_border = if (workspace.activeFile() != null and workspace.activeFile().? == file_index) palette.primary.opacity(0.55) else palette.outline_soft.opacity(0.4),
        .border = Rect.all(1),
        .corner_radius = Rect.all(8),
        .padding = .{ .x = 10, .y = 8, .w = 10, .h = 8 },
    });
    bw.processEvents();
    bw.drawBackground();

    {
        var row = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .horizontal,
        });
        defer row.deinit();

        dvui.icon(@src(), file.path, entypo.text_document, .{}, .{
            .min_size_content = .all(14),
            .color_text = workspace.fileAccentColor(file.language),
            .gravity_y = 0.5,
        });
        _ = dvui.spacer(@src(), .{ .min_size_content = .width(8) });

        var text_col = dvui.box(@src(), .{}, .{
            .expand = .horizontal,
        });
        defer text_col.deinit();

        dvui.labelNoFmt(@src(), file.name, .{}, .{
            .font = Font.theme(.mono).larger(-1).withWeight(.bold),
            .color_text = palette.text,
        });
        dvui.labelNoFmt(@src(), file.path, .{}, .{
            .font = Font.theme(.body).larger(-3),
            .color_text = palette.text_soft,
        });
        dvui.label(@src(), "Line {d}  {s}", .{ match.line_number, preview }, .{
            .id_extra = 70_000 + file_index,
            .font = Font.theme(.mono).larger(-3),
            .color_text = palette.text_dim,
        });

        drawLanguageBadge(file_index, file.path, file.language);
    }

    const clicked = bw.clicked();
    bw.drawFocus();
    bw.deinit();
    return clicked;
}

fn drawLanguageBadge(id_extra: usize, path: []const u8, language: app_core.Language) void {
    const accent = workspace.fileAccentColor(language);

    var badge = dvui.box(@src(), .{}, .{
        .id_extra = 60_000 + id_extra,
        .gravity_y = 0.5,
        .background = true,
        .color_fill = accent.opacity(0.12),
        .color_border = accent.opacity(0.32),
        .border = Rect.all(1),
        .corner_radius = Rect.all(999),
        .padding = .{ .x = 8, .y = 4, .w = 8, .h = 4 },
    });
    defer badge.deinit();

    dvui.labelNoFmt(@src(), workspace.fileLanguageLabel(path, language), .{}, .{
        .id_extra = 61_000 + id_extra,
        .font = Font.theme(.body).larger(-3).withWeight(.bold),
        .color_text = accent,
    });
}

fn drawSearchPanelField() void {
    var row = dvui.box(@src(), .{}, .{
        .expand = .horizontal,
        .padding = .{ .x = 14, .y = 0, .w = 14, .h = 10 },
    });
    defer row.deinit();

    var field = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .horizontal,
        .gravity_y = 0.5,
        .background = true,
        .color_fill = palette.surface_high,
        .color_border = palette.outline_soft,
        .border = Rect.all(1),
        .corner_radius = Rect.all(6),
        .padding = .{ .x = 8, .y = 6, .w = 8, .h = 6 },
    });
    defer field.deinit();

    dvui.icon(@src(), "search-panel-icon", entypo.magnifying_glass, .{}, .{
        .color_text = palette.text_dim,
        .min_size_content = .all(12),
        .gravity_y = 0.5,
    });
    _ = dvui.spacer(@src(), .{ .min_size_content = .width(6) });

    var te: dvui.TextEntryWidget = undefined;
    te.init(@src(), .{
        .placeholder = "Search file contents...",
        .text = .{ .buffer = app.search_buf[0..] },
    }, .{
        .id_extra = 500,
        .expand = .horizontal,
        .background = false,
        .border = .{},
        .padding = .{},
        .color_text = palette.text,
        .font = Font.theme(.body).larger(-1),
    });
    const current_sw = dvui.subwindowCurrentId();
    if (app.pending_search_focus and dvui.focusedWidgetId() != te.data().id) {
        dvui.focusSubwindow(current_sw, null);
        dvui.focusWidget(te.data().id, current_sw, null);
        app.pending_search_focus = false;
    }
    for (dvui.events()) |*e| {
        if (e.handled or !te.matchEvent(e) or e.evt != .mouse) continue;
        const me = e.evt.mouse;
        if (me.action == .focus) {
            dvui.focusSubwindow(current_sw, e.num);
            break;
        }
    }
    te.processEvents();
    te.draw();
    te.deinit();
}

fn drawStatCard(id_extra: usize, label: []const u8, value: usize, accent: app_core.Color) void {
    var card = dvui.box(@src(), .{}, .{
        .id_extra = 62_000 + id_extra,
        .expand = .horizontal,
        .background = true,
        .color_fill = palette.surface_low.opacity(0.95),
        .color_border = accent.opacity(0.35),
        .border = Rect.all(1),
        .corner_radius = Rect.all(8),
        .padding = .{ .x = 10, .y = 8, .w = 10, .h = 8 },
    });
    defer card.deinit();

    dvui.labelNoFmt(@src(), label, .{}, .{
        .id_extra = 63_000 + id_extra,
        .font = Font.theme(.body).larger(-3),
        .color_text = palette.text_soft,
    });
    dvui.label(@src(), "{d}", .{value}, .{
        .id_extra = 64_000 + id_extra,
        .font = Font.theme(.heading).larger(-1),
        .color_text = accent,
    });
}

fn layoutActionButton(id_extra: usize, title: []const u8, icon_bytes: []const u8, subtitle: []const u8) bool {
    var bw: dvui.ButtonWidget = undefined;
    bw.init(@src(), .{}, .{
        .id_extra = 50_000 + id_extra,
        .expand = .horizontal,
        .background = true,
        .color_fill = palette.surface_low.opacity(0.95),
        .color_fill_hover = palette.surface_high.opacity(0.65),
        .color_fill_press = palette.surface_highest.opacity(0.8),
        .color_border = palette.outline_soft,
        .border = Rect.all(1),
        .corner_radius = Rect.all(8),
        .padding = .{ .x = 10, .y = 8, .w = 10, .h = 8 },
    });
    bw.processEvents();
    bw.drawBackground();

    {
        var row = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .horizontal,
        });
        defer row.deinit();

        dvui.icon(@src(), title, icon_bytes, .{}, .{
            .color_text = palette.primary,
            .min_size_content = .all(14),
            .gravity_y = 0.5,
        });
        _ = dvui.spacer(@src(), .{ .min_size_content = .width(10) });

        var text_col = dvui.box(@src(), .{}, .{
            .expand = .horizontal,
        });
        defer text_col.deinit();

        dvui.labelNoFmt(@src(), title, .{}, .{
            .font = Font.theme(.body).withWeight(.bold),
            .color_text = palette.text,
        });
        dvui.labelNoFmt(@src(), subtitle, .{}, .{
            .font = Font.theme(.body).larger(-3),
            .color_text = palette.text_soft,
        });
    }

    const clicked = bw.clicked();
    bw.drawFocus();
    bw.deinit();
    return clicked;
}

fn layoutWindowRow(id_extra: usize, file_index: usize, file: *const app_core.EditorFile) bool {
    var bw: dvui.ButtonWidget = undefined;
    bw.init(@src(), .{}, .{
        .id_extra = id_extra,
        .expand = .horizontal,
        .background = true,
        .color_fill = if (workspace.activeFile() != null and workspace.activeFile().? == file_index) palette.surface_high.opacity(0.58) else palette.panel.opacity(0.55),
        .color_fill_hover = palette.surface_high.opacity(0.45),
        .color_fill_press = palette.surface_high.opacity(0.7),
        .color_border = palette.outline_soft.opacity(0.4),
        .border = Rect.all(1),
        .corner_radius = Rect.all(8),
        .padding = .{ .x = 10, .y = 8, .w = 10, .h = 8 },
    });
    bw.processEvents();
    bw.drawBackground();

    {
        var row = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .horizontal,
        });
        defer row.deinit();

        dvui.icon(@src(), file.name, entypo.text_document, .{}, .{
            .min_size_content = .all(14),
            .color_text = workspace.fileAccentColor(file.language),
            .gravity_y = 0.5,
        });
        _ = dvui.spacer(@src(), .{ .min_size_content = .width(8) });

        var text_col = dvui.box(@src(), .{}, .{
            .expand = .horizontal,
        });
        defer text_col.deinit();

        dvui.labelNoFmt(@src(), file.name, .{}, .{
            .font = Font.theme(.mono).larger(-1).withWeight(.bold),
            .color_text = palette.text,
        });
        dvui.labelNoFmt(@src(), file.path, .{}, .{
            .font = Font.theme(.body).larger(-3),
            .color_text = palette.text_soft,
        });

        dvui.label(@src(), "#{d}", .{file.z_index}, .{
            .font = Font.theme(.body).larger(-3).withWeight(.bold),
            .color_text = palette.primary,
        });
    }

    const clicked = bw.clicked();
    bw.drawFocus();
    bw.deinit();
    return clicked;
}

fn drawMainArea() void {
    var overlay = dvui.overlay(@src(), .{
        .expand = .both,
        .background = true,
        .color_fill = palette.canvas,
    });
    defer overlay.deinit();

    spatial_canvas.drawSpatialCanvas();
    if (app.sidebar_open) {
        drawSidebarPanel();
    }
    navigation_ui.drawCommandStrip();
    navigation_ui.drawZoomDock();
}
