const std = @import("std");
const dvui = @import("dvui");
const app_core = @import("app_core.zig");
const workspace = @import("workspace.zig");

const Font = app_core.Font;
const Rect = app_core.Rect;
const entypo = app_core.entypo;
const palette = app_core.palette;
const app = &app_core.app;

pub fn drawCommandStrip() void {
    var panel = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .gravity_x = 0.5,
        .gravity_y = 1.0,
        .margin = .{ .h = 14 },
        .background = true,
        .color_fill = palette.surface.opacity(0.92),
        .color_border = palette.outline,
        .border = Rect.all(1),
        .corner_radius = Rect.all(10),
        .padding = .{ .x = 16, .y = 10, .w = 16, .h = 10 },
        .box_shadow = .{
            .color = .black,
            .alpha = 0.4,
            .offset = .{ .x = 0, .y = 8 },
            .fade = 18,
        },
    });

    const panel_rs = panel.data().rectScale();
    dvui.subwindowAdd(panel.data().id, panel.data().rect, panel_rs.r, false, null, true);
    const prev_sw = dvui.subwindowCurrentSet(panel.data().id, .cast(panel.data().rect));
    defer {
        _ = dvui.subwindowCurrentSet(prev_sw.id, prev_sw.rect);
        panel.deinit();
    }

    if (commandButton(2, "Rearrange", entypo.grid)) {
        workspace.rearrangeWindows();
    }

    verticalDivider(1);

    if (commandButton(3, "Center", entypo.compass)) {
        app.canvas.center_requested = true;
    }
}

fn commandButton(id_extra: usize, label: []const u8, icon_bytes: []const u8) bool {
    var bw: dvui.ButtonWidget = undefined;
    bw.init(@src(), .{}, .{
        .id_extra = 600 + id_extra,
        .background = false,
        .border = .{},
        .padding = .{ .x = 4, .y = 2, .w = 4, .h = 2 },
        .color_text = palette.text_dim,
        .color_text_hover = palette.primary,
    });
    bw.processEvents();
    bw.drawBackground();

    {
        var row = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .horizontal,
        });
        defer row.deinit();

        dvui.icon(@src(), label, icon_bytes, .{}, .{
            .gravity_y = 0.5,
            .color_text = palette.text_dim,
        });
        _ = dvui.spacer(@src(), .{ .min_size_content = .width(5) });
        dvui.labelNoFmt(@src(), label, .{ .align_y = 0.5 }, .{
            .font = Font.theme(.body).larger(-1).withWeight(.bold),
            .color_text = palette.text_dim,
        });
    }

    const clicked = bw.clicked();
    bw.drawFocus();
    bw.deinit();
    return clicked;
}

pub fn drawZoomDock() void {
    var dock = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .gravity_x = 1.0,
        .gravity_y = 1.0,
        .margin = .{ .w = 16, .h = 16 },
    });
    defer dock.deinit();

    drawMiniMap();
    _ = dvui.spacer(@src(), .{ .min_size_content = .width(14) });
    drawZoomPanel();
}

fn drawMiniMap() void {
    var outer = dvui.box(@src(), .{}, .{
        .gravity_y = 1.0,
        .min_size_content = .{ .w = 140, .h = 96 },
        .max_size_content = .size(.{ .w = 140, .h = 96 }),
        .background = true,
        .color_fill = palette.surface.opacity(0.92),
        .color_border = palette.outline,
        .border = Rect.all(1),
        .corner_radius = Rect.all(8),
        .padding = .{ .x = 8, .y = 6, .w = 8, .h = 6 },
        .box_shadow = .{
            .color = .black,
            .alpha = 0.35,
            .offset = .{ .x = 0, .y = 8 },
            .fade = 16,
        },
    });

    const outer_rs = outer.data().rectScale();
    dvui.subwindowAdd(outer.data().id, outer.data().rect, outer_rs.r, false, null, true);
    const prev_sw = dvui.subwindowCurrentSet(outer.data().id, .cast(outer.data().rect));
    defer {
        _ = dvui.subwindowCurrentSet(prev_sw.id, prev_sw.rect);
        outer.deinit();
    }

    {
        var title = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .horizontal,
        });
        defer title.deinit();

        dvui.labelNoFmt(@src(), "Minimap", .{ .align_y = 0.5 }, .{
            .font = Font.theme(.heading).larger(-4),
            .color_text = palette.text_soft,
        });
        _ = dvui.spacer(@src(), .{ .expand = .horizontal });
        dvui.icon(@src(), "mini-compass", entypo.compass, .{}, .{
            .min_size_content = .all(10),
            .color_text = palette.text_soft.opacity(0.8),
            .gravity_y = 0.5,
        });
    }

    _ = dvui.spacer(@src(), .{ .min_size_content = .height(6) });

    var map_box = dvui.box(@src(), .{}, .{
        .expand = .both,
        .background = true,
        .color_fill = palette.surface_lowest.opacity(0.9),
        .color_border = palette.outline_soft,
        .border = Rect.all(1),
        .corner_radius = Rect.all(4),
    });
    defer map_box.deinit();

    const inner = map_box.data().contentRectScale().r.insetAll(2);
    const old_clip = dvui.clip(inner);
    defer dvui.clipSet(old_clip);

    const virtual_w = @max(app.canvas.scroll_info.virtual_size.w, 1.0);
    const virtual_h = @max(app.canvas.scroll_info.virtual_size.h, 1.0);
    const sx = inner.w / virtual_w;
    const sy = inner.h / virtual_h;
    const active_idx = workspace.activeFile();

    for (app.files, 0..) |file, i| {
        if (!file.window_open) continue;
        const vr = workspace.fileVirtualRect(file.window_rect);
        const color = if (active_idx != null and active_idx.? == i)
            palette.primary.opacity(0.22)
        else
            palette.surface_highest.opacity(0.75);
        const border_color = if (active_idx != null and active_idx.? == i)
            palette.primary.opacity(0.65)
        else
            palette.outline.opacity(0.5);

        const r = Rect.Physical{
            .x = inner.x + vr.x * sx,
            .y = inner.y + vr.y * sy,
            .w = @max(vr.w * sx, 3),
            .h = @max(vr.h * sy, 3),
        };
        r.fill(.{ .x = 1, .y = 1, .w = 1, .h = 1 }, .{
            .color = color,
            .fade = 1.0,
        });
        r.stroke(.{ .x = 1, .y = 1, .w = 1, .h = 1 }, .{
            .thickness = 1,
            .color = border_color,
        });
    }

    const vp = app.canvas.scroll_info.viewport;
    const vp_rect = Rect.Physical{
        .x = inner.x + vp.x * sx,
        .y = inner.y + vp.y * sy,
        .w = @max(vp.w * sx, 8),
        .h = @max(vp.h * sy, 6),
    };
    vp_rect.fill(.{ .x = 1, .y = 1, .w = 1, .h = 1 }, .{
        .color = palette.primary.opacity(0.08),
        .fade = 1.0,
    });
    vp_rect.stroke(.{ .x = 1, .y = 1, .w = 1, .h = 1 }, .{
        .thickness = 1,
        .color = palette.primary.opacity(0.65),
    });
}

fn drawZoomPanel() void {
    var panel = dvui.box(@src(), .{}, .{
        .gravity_x = 1.0,
        .background = true,
        .color_fill = palette.surface.opacity(0.92),
        .color_border = palette.outline,
        .border = Rect.all(1),
        .corner_radius = Rect.all(10),
        .padding = .{ .x = 10, .y = 10, .w = 10, .h = 10 },
        .box_shadow = .{
            .color = .black,
            .alpha = 0.35,
            .offset = .{ .x = 0, .y = 8 },
            .fade = 16,
        },
    });

    const panel_rs = panel.data().rectScale();
    dvui.subwindowAdd(panel.data().id, panel.data().rect, panel_rs.r, false, null, true);
    const prev_sw = dvui.subwindowCurrentSet(panel.data().id, .cast(panel.data().rect));
    defer {
        _ = dvui.subwindowCurrentSet(prev_sw.id, prev_sw.rect);
        panel.deinit();
    }

    if (zoomIconButton(1, entypo.plus)) {
        app.canvas.pending_zoom_delta += 0.1;
    }

    _ = dvui.spacer(@src(), .{ .min_size_content = .height(8) });
    const zoom_percent: u32 = @intFromFloat(@round(app.canvas.scale * 100.0));
    dvui.label(@src(), "{d}%", .{zoom_percent}, .{
        .gravity_x = 0.5,
        .font = Font.theme(.heading).larger(-2),
        .color_text = palette.primary,
    });

    {
        var meter = dvui.box(@src(), .{}, .{
            .gravity_x = 0.5,
            .min_size_content = .{ .w = 8, .h = 86 },
            .max_size_content = .size(.{ .w = 8, .h = 86 }),
            .background = true,
            .color_fill = palette.surface_lowest,
            .corner_radius = Rect.all(999),
        });
        defer meter.deinit();

        const track = meter.data().contentRectScale().r.insetAll(1);
        const fraction = std.math.clamp((app.canvas.scale - 0.5) / 1.5, 0.0, 1.0);
        const fill_h = track.h * fraction;
        const fill_rect = Rect.Physical{
            .x = track.x,
            .y = track.y + track.h - fill_h,
            .w = track.w,
            .h = fill_h,
        };
        fill_rect.fill(.{ .x = 999, .y = 999, .w = 999, .h = 999 }, .{
            .color = palette.primary,
            .fade = 1.0,
        });
    }

    _ = dvui.spacer(@src(), .{ .min_size_content = .height(8) });

    if (zoomIconButton(2, entypo.minus)) {
        app.canvas.pending_zoom_delta -= 0.1;
    }
}

fn zoomIconButton(id_extra: usize, icon_bytes: []const u8) bool {
    return dvui.buttonIcon(@src(), "zoom", icon_bytes, .{}, .{}, .{
        .id_extra = 700 + id_extra,
        .background = true,
        .color_fill = palette.surface_high.opacity(0.6),
        .color_fill_hover = palette.surface_highest,
        .color_fill_press = palette.primary_soft,
        .color_border = palette.outline_soft,
        .border = Rect.all(1),
        .corner_radius = Rect.all(8),
        .padding = .{ .x = 8, .y = 8, .w = 8, .h = 8 },
        .min_size_content = .all(16),
        .color_text = palette.text_dim,
        .color_text_hover = palette.primary,
    });
}

pub fn drawFooter() void {
    var footer = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .horizontal,
        .min_size_content = .{ .h = app_core.footer_height },
        .max_size_content = .height(app_core.footer_height),
        .background = true,
        .color_fill = palette.surface_lowest,
        .color_border = palette.outline_soft,
        .border = .{ .y = 1 },
        .padding = .{ .x = 12, .y = 2, .w = 12, .h = 2 },
    });
    defer footer.deinit();

    {
        var left = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .gravity_y = 0.5,
        });
        defer left.deinit();

        dvui.icon(@src(), "branch", entypo.cw, .{}, .{
            .min_size_content = .all(10),
            .color_text = palette.primary,
            .gravity_y = 0.5,
        });
        _ = dvui.spacer(@src(), .{ .min_size_content = .width(4) });
        dvui.labelNoFmt(@src(), "Main*", .{ .align_y = 0.5 }, .{
            .font = Font.theme(.body).larger(-3),
            .color_text = palette.text_dim,
        });

        _ = dvui.spacer(@src(), .{ .min_size_content = .width(18) });
        dvui.icon(@src(), "warning", entypo.warning, .{}, .{
            .min_size_content = .all(10),
            .color_text = palette.warning,
            .gravity_y = 0.5,
        });
        _ = dvui.spacer(@src(), .{ .min_size_content = .width(4) });
        dvui.labelNoFmt(@src(), "1", .{ .align_y = 0.5 }, .{
            .font = Font.theme(.body).larger(-3),
            .color_text = palette.text_dim,
        });
    }

    _ = dvui.spacer(@src(), .{ .expand = .horizontal });

    {
        var right = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .gravity_x = 1.0,
            .gravity_y = 0.5,
        });
        defer right.deinit();

        dvui.labelNoFmt(@src(), "Spatial Mode", .{ .align_y = 0.5 }, .{
            .font = Font.theme(.body).larger(-3),
            .color_text = palette.text_soft,
        });
        _ = dvui.spacer(@src(), .{ .min_size_content = .width(12) });
        dvui.labelNoFmt(@src(), workspace.activeLanguageLabel(), .{ .align_y = 0.5 }, .{
            .font = Font.theme(.body).larger(-2).withWeight(.bold),
            .color_text = palette.primary,
        });
    }
}

fn verticalDivider(id_extra: usize) void {
    var div = dvui.box(@src(), .{}, .{
        .id_extra = id_extra,
        .min_size_content = .{ .w = 1, .h = 14 },
        .background = true,
        .color_fill = palette.outline_soft.opacity(0.8),
        .margin = .{ .x = 12, .w = 12 },
    });
    div.deinit();
}
