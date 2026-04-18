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
    var root = dvui.box(@src(), .{}, .{
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

    _ = dvui.spacer(@src(), .{ .expand = .horizontal });

    {
        var right = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .gravity_x = 1.0,
            .gravity_y = 0.5,
        });
        defer right.deinit();

        drawSearchField();
        _ = dvui.spacer(@src(), .{ .min_size_content = .width(10) });

        if (dvui.button(@src(), "Sync", .{}, .{
            .background = true,
            .color_fill = palette.primary_soft,
            .color_fill_hover = palette.primary_dim,
            .color_fill_press = palette.primary_dim,
            .color_text = palette.text,
            .color_border = palette.primary,
            .style = .app3,
            .padding = .{ .x = 12, .y = 4, .w = 12, .h = 4 },
            .corner_radius = Rect.all(6),
        })) {}

        _ = dvui.spacer(@src(), .{ .min_size_content = .width(10) });
        drawAvatar();
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

fn drawSearchField() void {
    var field = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .gravity_y = 0.5,
        .background = true,
        .color_fill = palette.surface_high,
        .color_border = palette.outline_soft,
        .border = Rect.all(1),
        .corner_radius = Rect.all(4),
        .padding = .{ .x = 8, .y = 4, .w = 8, .h = 4 },
        .min_size_content = .{ .w = 180 },
    });
    defer field.deinit();

    dvui.icon(@src(), "search", entypo.magnifying_glass, .{}, .{
        .color_text = palette.text_dim,
        .min_size_content = .all(12),
        .gravity_y = 0.5,
    });
    _ = dvui.spacer(@src(), .{ .min_size_content = .width(6) });

    var te: dvui.TextEntryWidget = undefined;
    te.init(@src(), .{
        .placeholder = "Search Files...",
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
    te.processEvents();
    te.draw();
    te.deinit();
}

fn drawAvatar() void {
    var avatar = dvui.box(@src(), .{}, .{
        .gravity_y = 0.5,
        .background = true,
        .color_fill = palette.surface_highest,
        .color_border = palette.outline,
        .border = Rect.all(1),
        .corner_radius = Rect.all(999),
        .min_size_content = .{ .w = 24, .h = 24 },
    });
    defer avatar.deinit();

    dvui.labelNoFmt(@src(), "M", .{ .align_x = 0.5, .align_y = 0.5 }, .{
        .expand = .both,
        .font = Font.theme(.body).withWeight(.bold).larger(-1),
        .color_text = palette.text,
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
    }
    if (railButton(11, "Search", entypo.magnifying_glass, app.rail_mode == .search and app.sidebar_open)) {
        if (app.rail_mode == .search) {
            app.sidebar_open = !app.sidebar_open;
        } else {
            app.rail_mode = .search;
            app.sidebar_open = true;
        }
    }
    if (railButton(12, "Layout", entypo.grid, app.rail_mode == .layout and app.sidebar_open)) {
        if (app.rail_mode == .layout) {
            app.sidebar_open = !app.sidebar_open;
        } else {
            app.rail_mode = .layout;
            app.sidebar_open = true;
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

fn drawExplorerPanel() void {
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

    if (app.rail_mode != .explorer) {
        drawPlaceholderPanel();
        return;
    }

    {
        var title_row = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .horizontal,
            .padding = .{ .x = 14, .y = 14, .w = 14, .h = 10 },
        });
        defer title_row.deinit();

        dvui.labelNoFmt(@src(), "Project Explorer", .{ .align_y = 0.5 }, .{
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

    var scroll = dvui.scrollArea(@src(), .{}, .{
        .expand = .both,
        .background = false,
        .padding = .{ .x = 0, .y = 0, .w = 0, .h = 8 },
    });
    defer scroll.deinit();

    const query = workspace.searchQuery();
    var visible_count: usize = 0;

    if (explorerRow(100, app.project.name, entypo.folder, 0, true, app.explorer_root_open, true)) {
        app.explorer_root_open = !app.explorer_root_open;
    }

    if (app.explorer_root_open) {
        for (app.project.files.items, 0..) |file, i| {
            if (!workspace.matchesSearch(&file, query)) continue;
            visible_count += 1;

            if (explorerRow(200 + i, file.path, entypo.text_document, 18, file.window_open, false, false)) {
                workspace.openFile(i);
            }
        }
    }

    if (visible_count == 0) {
        var empty = dvui.box(@src(), .{}, .{
            .padding = .{ .x = 18, .y = 14, .w = 18, .h = 14 },
        });
        defer empty.deinit();
        dvui.labelNoFmt(@src(), if (query.len > 0) "No matching files" else "No text files loaded", .{}, .{
            .font = Font.theme(.body).larger(-1),
            .color_text = palette.text_soft,
        });
    }
}

fn drawPlaceholderPanel() void {
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

    switch (app.rail_mode) {
        .search => {
            text.addText("Search lives in the top bar in the Monolith reference.\nUse the field above to filter the explorer.", .{
                .color_text = palette.text_dim,
            });
        },
        .layout => {
            text.addText("Layout controls stay on the canvas overlay.\nUse Rearrange and Center from the command strip.", .{
                .color_text = palette.text_dim,
            });
        },
        .explorer => unreachable,
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

fn drawMainArea() void {
    var overlay = dvui.overlay(@src(), .{
        .expand = .both,
        .background = true,
        .color_fill = palette.canvas,
    });
    defer overlay.deinit();

    spatial_canvas.drawSpatialCanvas();
    if (app.sidebar_open) {
        drawExplorerPanel();
    }
    navigation_ui.drawCommandStrip();
    navigation_ui.drawZoomDock();
}
