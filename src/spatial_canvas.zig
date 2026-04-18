const std = @import("std");
const dvui = @import("dvui");
const app_core = @import("app_core.zig");
const workspace = @import("workspace.zig");

const Font = app_core.Font;
const Point = app_core.Point;
const Rect = app_core.Rect;
const WindowRenderMeta = app_core.WindowRenderMeta;
const palette = app_core.palette;
const entypo = app_core.entypo;
const app = &app_core.app;

const resize_border: f32 = 6.0;
const min_window_w: f32 = 180.0;
const min_window_h: f32 = 100.0;

pub fn drawSpatialCanvas() void {
    var scroll_area = dvui.scrollArea(@src(), .{ .scroll_info = &app.canvas.scroll_info }, .{
        .expand = .both,
        .background = false,
        .style = .content,
    });

    var scroll_container = &scroll_area.scroll.?;
    const scroll_rect_scale = scroll_container.screenRectScale(.{});

    var scaler = dvui.scale(@src(), .{ .scale = &app.canvas.scale }, .{
        .rect = .{
            .x = -app.canvas.origin.x,
            .y = -app.canvas.origin.y,
        },
    });
    const data_rect_scale = scaler.screenRectScale(.{});

    drawCanvasGrid(scroll_rect_scale.r, data_rect_scale);

    var previous_rects: [app_core.max_files]Rect = undefined;
    for (app.files, 0..) |file, i| {
        previous_rects[i] = file.window_rect;
    }

    if (app.pending_focus_file) |idx| {
        if (app.files[idx].window_open) {
            workspace.bringFileToFront(idx);
        }
        app.pending_focus_file = null;
    }

    var bounds: ?Rect.Physical = null;
    const active_idx = workspace.activeFile();

    var render_order: [app_core.max_files]usize = undefined;
    const render_count = workspace.buildOpenWindowOrder(&render_order);
    var metas: [app_core.max_files]WindowRenderMeta = undefined;
    var meta_count: usize = 0;

    for (render_order[0..render_count]) |file_index| {
        drawEditorWindow(
            file_index,
            &app.files[file_index],
            active_idx != null and active_idx.? == file_index,
            &bounds,
            &metas[meta_count],
        );
        meta_count += 1;
    }

    processEditorWindowInteractions(metas[0..meta_count], scroll_container, data_rect_scale);

    handleCanvasInteractions(scroll_container, scroll_rect_scale, data_rect_scale);
    scaler.deinit();

    const scroll_container_id = scroll_container.data().id;
    scroll_area.deinit();

    updateCanvasBounds(scroll_container_id, scroll_rect_scale, bounds);
    resolveWindowCollisions(previous_rects);

    if (app.last_active_file) |idx| {
        if (!app.files[idx].window_open) {
            if (workspace.firstOpenFile()) |fallback| {
                app.last_active_file = fallback;
            } else {
                app.last_active_file = null;
            }
        }
    }
}

fn drawCanvasGrid(clip_rect: Rect.Physical, data_rect_scale: anytype) void {
    const old_clip = dvui.clip(clip_rect);
    defer dvui.clipSet(old_clip);

    const top_left = data_rect_scale.pointFromPhysical(clip_rect.topLeft());
    const bottom_right = data_rect_scale.pointFromPhysical(clip_rect.bottomRight());

    const spacing: f32 = 32.0;
    var x = std.math.floor(top_left.x / spacing) * spacing;
    while (x <= bottom_right.x + spacing) : (x += spacing) {
        var y = std.math.floor(top_left.y / spacing) * spacing;
        while (y <= bottom_right.y + spacing) : (y += spacing) {
            const pt = data_rect_scale.pointToPhysical(.{ .x = x, .y = y });
            const dot = Rect.Physical{
                .x = pt.x - 1,
                .y = pt.y - 1,
                .w = 2,
                .h = 2,
            };
            dot.fill(.{ .x = 1, .y = 1, .w = 1, .h = 1 }, .{
                .color = palette.grid_dot,
                .fade = 1.0,
            });
        }
    }
}

fn drawEditorWindow(index: usize, file: *app_core.EditorFile, is_active: bool, bounds: *?Rect.Physical, meta: *WindowRenderMeta) void {
    const base_id = 10_000 + index * 100;

    var frame_wd: dvui.WidgetData = undefined;
    var frame = dvui.box(@src(), .{ .dir = .vertical }, .{
        .id_extra = base_id,
        .rect = file.window_rect,
        .padding = .{},
        .background = true,
        .style = .window,
        .color_fill = palette.surface_low,
        .color_border = if (is_active) palette.primary.opacity(0.4) else palette.outline_soft,
        .border = Rect.all(1),
        .corner_radius = Rect.all(8),
        .data_out = &frame_wd,
        .box_shadow = .{
            .color = palette.primary,
            .alpha = if (is_active) 0.18 else 0.10,
            .offset = .{ .x = 0, .y = 12 },
            .fade = 22,
        },
    });
    defer frame.deinit();

    const frame_rect = frame.data().rectScale().r;
    if (bounds.*) |bb| {
        bounds.* = bb.unionWith(frame_rect);
    } else {
        bounds.* = frame_rect;
    }

    if (is_active) {
        frame_rect.outsetAll(1).stroke(.{ .x = 9, .y = 9, .w = 9, .h = 9 }, .{
            .thickness = 2,
            .color = palette.primary.opacity(0.55),
        });
    }

    var header_wd: dvui.WidgetData = undefined;
    var header = dvui.overlay(@src(), .{
        .id_extra = base_id + 1,
        .expand = .horizontal,
        .min_size_content = .{ .h = 34 },
        .max_size_content = .height(34),
        .background = true,
        .color_fill = palette.surface_high,
        .color_border = if (is_active) palette.primary.opacity(0.4) else palette.outline_soft,
        .border = .{ .h = 1 },
        .data_out = &header_wd,
    });

    {
        var title_row = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .both,
            .padding = .{ .x = 10, .y = 6, .w = 34, .h = 6 },
        });
        defer title_row.deinit();

        dvui.icon(@src(), "grip", entypo.menu, .{}, .{
            .id_extra = base_id + 2,
            .min_size_content = .all(12),
            .color_text = palette.text_soft,
            .gravity_y = 0.5,
        });
        _ = dvui.spacer(@src(), .{
            .id_extra = base_id + 3,
            .min_size_content = .width(8),
        });

        dvui.icon(@src(), file.name, entypo.text_document, .{}, .{
            .id_extra = base_id + 4,
            .min_size_content = .all(12),
            .color_text = workspace.fileAccentColor(file.language),
            .gravity_y = 0.5,
        });
        _ = dvui.spacer(@src(), .{
            .id_extra = base_id + 5,
            .min_size_content = .width(8),
        });

        dvui.labelNoFmt(@src(), file.name, .{ .align_y = 0.5 }, .{
            .id_extra = base_id + 6,
            .expand = .horizontal,
            .font = Font.theme(.mono).larger(-1).withWeight(.bold),
            .color_text = palette.text,
        });
    }

    var close_wd: dvui.WidgetData = undefined;
    {
        var close_box = dvui.box(@src(), .{}, .{
            .id_extra = base_id + 7,
            .gravity_x = 1.0,
            .gravity_y = 0.5,
            .margin = .{ .w = 8 },
            .background = true,
            .color_fill = palette.surface_low.opacity(0.55),
            .corner_radius = Rect.all(999),
            .padding = .{},
            .min_size_content = .all(18),
            .max_size_content = .all(18),
            .data_out = &close_wd,
        });
        defer close_box.deinit();

        dvui.icon(@src(), "close", entypo.cross, .{}, .{
            .id_extra = base_id + 70,
            .gravity_x = 0.5,
            .gravity_y = 0.5,
            .min_size_content = .all(10),
            .color_text = palette.text_dim,
        });
    }
    header.deinit();

    var body = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .id_extra = base_id + 8,
        .expand = .both,
        .background = true,
        .color_fill = palette.surface_lowest,
    });
    defer body.deinit();

    drawLineGutter(index, file);
    if (is_active) {
        drawEditorTextEntry(index, file);
    } else {
        drawEditorPreview(index, file);
    }

    meta.* = .{
        .index = index,
        .frame_wd = frame_wd,
        .header_wd = header_wd,
        .close_wd = close_wd,
    };
}

fn drawLineGutter(index: usize, file: *const app_core.EditorFile) void {
    var gutter = dvui.box(@src(), .{}, .{
        .id_extra = 20_000 + index,
        .min_size_content = .{ .w = 32 },
        .max_size_content = .width(32),
        .expand = .vertical,
        .background = true,
        .color_fill = palette.gutter,
        .color_border = palette.outline_soft.opacity(0.5),
        .border = .{ .w = 1 },
        .padding = .{ .x = 0, .y = 10, .w = 0, .h = 10 },
    });
    defer gutter.deinit();

    const total_lines = workspace.countLines(app_core.fileText(file));
    var line_no: usize = 1;
    while (line_no <= total_lines) : (line_no += 1) {
        dvui.label(@src(), "{d}", .{line_no}, .{
            .id_extra = index * 1_000 + line_no,
            .gravity_x = 1.0,
            .font = Font.theme(.mono).larger(-3),
            .color_text = palette.text_soft.opacity(0.7),
            .padding = .{ .x = 0, .y = 0, .w = 6, .h = 0 },
        });
    }
}

fn drawEditorTextEntry(index: usize, file: *app_core.EditorFile) void {
    const cw = dvui.currentWindow();

    cw.scroll_to_focused = false;

    var te: dvui.TextEntryWidget = undefined;
    te.init(@src(), .{
        .multiline = true,
        .break_lines = true,
        .scroll_horizontal = false,
        .text = .{ .buffer = file.content[0..] },
    }, .{
        .id_extra = 30_000 + index,
        .expand = .both,
        .margin = .{},
        .background = false,
        .border = .{},
        .padding = .{ .x = 12, .y = 10, .w = 12, .h = 10 },
        .font = Font.theme(.mono).larger(-1),
        .color_text = palette.text_dim,
    });

    if (dvui.focusedWidgetId() != te.data().id) {
        dvui.focusWidget(te.data().id, null, null);
    }
    cw.scroll_to_focused = false;

    for (dvui.events()) |*e| {
        if (e.handled or e.evt != .key) continue;
        const ke = e.evt.key;
        if (ke.code == .tab and (ke.action == .down or ke.action == .repeat) and ke.mod.control()) {
            e.handle(@src(), te.data());
            workspace.cycleFocusWindow();
            dvui.refresh(null, @src(), te.data().id);
        }
    }

    te.processEvents();
    cw.scroll_to_focused = false;

    te.drawBeforeText();
    te.textLayout.addText(te.text[0..te.len], te.data().options.strip());
    te.textLayout.addTextDone(te.data().options.strip());
    if (te.data().id == dvui.focusedWidgetId()) {
        te.drawCursor();
    }
    dvui.clipSet(te.prevClip);

    te.deinit();
}

fn drawEditorPreview(index: usize, file: *const app_core.EditorFile) void {
    var tl = dvui.textLayout(@src(), .{}, .{
        .id_extra = 40_000 + index,
        .expand = .both,
        .background = false,
        .padding = .{ .x = 12, .y = 10, .w = 12, .h = 10 },
        .font = Font.theme(.mono).larger(-1),
    });
    defer tl.deinit();

    tl.addText(app_core.fileText(file), .{
        .color_text = palette.text_soft.opacity(0.95),
    });
}

fn detectResizeEdges(frame_rect: Rect.Physical, p: Point.Physical) app_core.ResizeEdges {
    return .{
        .left = p.x <= frame_rect.x + resize_border,
        .right = p.x >= frame_rect.x + frame_rect.w - resize_border,
        .top = p.y <= frame_rect.y + resize_border,
        .bottom = p.y >= frame_rect.y + frame_rect.h - resize_border,
    };
}

fn processEditorWindowInteractions(metas: []const WindowRenderMeta, scroll_container: *dvui.ScrollContainerWidget, data_rect_scale: anytype) void {
    for (dvui.events()) |*e| {
        if (e.evt != .mouse) continue;
        const me = e.evt.mouse;
        if (me.floating_win != dvui.subwindowCurrentId()) continue;
        if (me.action != .press or !me.button.pointer()) continue;

        var i = metas.len;
        while (i > 0) : (i -= 1) {
            const meta = metas[i - 1];
            const frame_rect = meta.frame_wd.borderRectScale().r;
            if (frame_rect.contains(me.p)) {
                workspace.bringFileToFront(meta.index);
                dvui.refresh(null, @src(), scroll_container.data().id);
                break;
            }
        }
    }

    for (dvui.events()) |*e| {
        if (e.handled or e.evt != .mouse) continue;

        const me = e.evt.mouse;
        if (me.floating_win != dvui.subwindowCurrentId()) continue;
        var i = metas.len;
        while (i > 0) : (i -= 1) {
            const meta = metas[i - 1];
            const frame_rect = meta.frame_wd.borderRectScale().r;
            const captured_here = dvui.captured(meta.frame_wd.id);

            if (!captured_here and !frame_rect.contains(me.p)) continue;

            const header_rect = meta.header_wd.borderRectScale().r;
            const close_rect = meta.close_wd.borderRectScale().r;
            var file = &app.files[meta.index];

            const edges = detectResizeEdges(frame_rect, me.p);
            const on_border = edges.any() and !header_rect.insetAll(resize_border).contains(me.p);

            if (me.action == .position) {
                if (captured_here and app.resize_edges.any()) {
                    dvui.cursorSet(app.resize_edges.cursor());
                } else if (close_rect.contains(me.p)) {
                    dvui.cursorSet(.hand);
                } else if (on_border) {
                    dvui.cursorSet(edges.cursor());
                } else if (header_rect.contains(me.p)) {
                    dvui.cursorSet(.arrow_all);
                }
                break;
            }

            if (close_rect.contains(me.p) and !captured_here) {
                if (me.action == .press and me.button.pointer()) {
                    e.handle(@src(), &meta.close_wd);
                    file.window_open = false;
                    if (app.last_active_file != null and app.last_active_file.? == meta.index) {
                        app.last_active_file = workspace.firstOpenFile();
                    }
                    dvui.refresh(null, @src(), scroll_container.data().id);
                }
                break;
            }

            if ((on_border and !captured_here) or (captured_here and app.resize_edges.any())) {
                if (me.action == .press and me.button.pointer()) {
                    e.handle(@src(), &meta.frame_wd);
                    app.resize_edges = edges;
                    dvui.captureMouse(&meta.frame_wd, e.num);
                    dvui.dragPreStart(me.p, .{
                        .cursor = edges.cursor(),
                        .offset = me.p.diff(frame_rect.topLeft()),
                    });
                    dvui.refresh(null, @src(), scroll_container.data().id);
                } else if (me.action == .release and me.button.pointer() and captured_here) {
                    e.handle(@src(), &meta.frame_wd);
                    app.resize_edges = .{};
                    dvui.captureMouse(null, e.num);
                    dvui.dragEnd();
                } else if (me.action == .motion and captured_here) {
                    if (dvui.dragging(me.p, null)) |_| {
                        e.handle(@src(), &meta.frame_wd);
                        const mp = data_rect_scale.pointFromPhysical(me.p);
                        const re = app.resize_edges;
                        var r = file.window_rect;

                        if (re.right) {
                            r.w = @max(mp.x - r.x, min_window_w);
                        }
                        if (re.bottom) {
                            r.h = @max(mp.y - r.y, min_window_h);
                        }
                        if (re.left) {
                            const right_edge = r.x + r.w;
                            const new_x = @min(mp.x, right_edge - min_window_w);
                            r.w = right_edge - new_x;
                            r.x = new_x;
                        }
                        if (re.top) {
                            const bottom_edge = r.y + r.h;
                            const new_y = @min(mp.y, bottom_edge - min_window_h);
                            r.h = bottom_edge - new_y;
                            r.y = new_y;
                        }

                        file.window_rect = r;
                        dvui.refresh(null, @src(), scroll_container.data().id);
                    }
                }
                break;
            }

            if (header_rect.contains(me.p) or captured_here) {
                if (me.action == .press and me.button.pointer()) {
                    e.handle(@src(), &meta.header_wd);
                    dvui.captureMouse(&meta.frame_wd, e.num);
                    dvui.dragPreStart(me.p, .{
                        .cursor = .arrow_all,
                        .offset = me.p.diff(frame_rect.topLeft()),
                    });
                    dvui.refresh(null, @src(), scroll_container.data().id);
                } else if (me.action == .release and me.button.pointer() and captured_here) {
                    e.handle(@src(), &meta.frame_wd);
                    dvui.captureMouse(null, e.num);
                    dvui.dragEnd();
                } else if (me.action == .motion and captured_here) {
                    if (dvui.dragging(me.p, null)) |_| {
                        e.handle(@src(), &meta.frame_wd);
                        const top_left = me.p.diff(dvui.dragOffset());
                        const next_pos = data_rect_scale.pointFromPhysical(top_left);
                        file.window_rect.x = next_pos.x;
                        file.window_rect.y = next_pos.y;
                        dvui.refresh(null, @src(), scroll_container.data().id);

                        dvui.scrollDrag(.{
                            .mouse_pt = me.p,
                            .screen_rect = frame_rect,
                        });
                    }
                }
                break;
            }

            if (me.action == .press and me.button.pointer()) {
                e.handle(@src(), &meta.frame_wd);
            }
            break;
        }
    }
}

fn handleCanvasInteractions(scroll_container: *dvui.ScrollContainerWidget, scroll_rect_scale: anytype, data_rect_scale: anytype) void {
    var zoom_factor: f32 = 1.0;
    var zoom_anchor: Point.Physical = scroll_rect_scale.r.center();

    for (dvui.events()) |*e| {
        if (e.handled) continue;

        if (e.evt == .key) {
            const ke = e.evt.key;
            if (ke.code == .tab and (ke.action == .down or ke.action == .repeat) and ke.mod.control()) {
                e.handle(@src(), scroll_container.data());
                workspace.cycleFocusWindow();
                dvui.refresh(null, @src(), scroll_container.data().id);
                continue;
            }
        }

        if (!scroll_container.matchEvent(e)) continue;

        switch (e.evt) {
            .mouse => |me| {
                if (me.action == .press and me.button.pointer()) {
                    e.handle(@src(), scroll_container.data());
                    app.last_active_file = null;
                    dvui.refresh(null, @src(), scroll_container.data().id);
                } else if (me.action == .press and me.button == .middle) {
                    e.handle(@src(), scroll_container.data());
                    dvui.captureMouse(scroll_container.data(), e.num);
                    dvui.dragPreStart(me.p, .{});
                } else if (me.action == .release and me.button == .middle) {
                    if (dvui.captured(scroll_container.data().id)) {
                        e.handle(@src(), scroll_container.data());
                        dvui.captureMouse(null, e.num);
                        dvui.dragEnd();
                    }
                } else if (me.action == .motion) {
                    if (dvui.captured(scroll_container.data().id)) {
                        if (dvui.dragging(me.p, null)) |dps| {
                            e.handle(@src(), scroll_container.data());
                            app.canvas.scroll_info.viewport.x -= dps.x / scroll_rect_scale.s;
                            app.canvas.scroll_info.viewport.y -= dps.y / scroll_rect_scale.s;
                            dvui.refresh(null, @src(), scroll_container.data().id);
                        }
                    }
                } else if (me.action == .wheel_y and me.mod.matchBind("ctrl/cmd")) {
                    e.handle(@src(), scroll_container.data());
                    const base: f32 = 1.01;
                    const factor = @exp(@log(base) * me.action.wheel_y);
                    if (factor != 1.0) {
                        zoom_factor *= factor;
                        zoom_anchor = me.p;
                    }
                }
            },
            else => {},
        }
    }

    if (app.canvas.pending_zoom_delta != 0.0) {
        const target = std.math.clamp(app.canvas.scale + app.canvas.pending_zoom_delta, 0.5, 2.0);
        app.canvas.pending_zoom_delta = 0.0;
        if (target != app.canvas.scale) {
            zoom_factor *= target / app.canvas.scale;
            zoom_anchor = scroll_rect_scale.r.center();
        }
    }

    if (zoom_factor != 1.0) {
        applyZoomAroundPoint(scroll_container.data().id, zoom_factor, zoom_anchor, scroll_rect_scale, data_rect_scale);
    }

    if (app.canvas.center_requested) {
        app.canvas.center_requested = false;
        app.canvas.scale = 1.0;
        app.canvas.scroll_info.viewport.x = -app.canvas.origin.x;
        app.canvas.scroll_info.viewport.y = -app.canvas.origin.y;
        dvui.refresh(null, @src(), scroll_container.data().id);
    }
}

fn applyZoomAroundPoint(scroll_id: dvui.Id, zoom_factor: f32, anchor: Point.Physical, scroll_rect_scale: anytype, data_rect_scale: anytype) void {
    const prev_point = data_rect_scale.pointFromPhysical(anchor);

    var unscaled = prev_point.scale(1.0 / app.canvas.scale, Point);
    const next_scale = std.math.clamp(app.canvas.scale * zoom_factor, 0.5, 2.0);
    app.canvas.scale = next_scale;
    unscaled = unscaled.scale(app.canvas.scale, Point);

    const new_point = data_rect_scale.pointToPhysical(unscaled);
    const diff = scroll_rect_scale.pointFromPhysical(new_point).diff(scroll_rect_scale.pointFromPhysical(anchor));

    app.canvas.scroll_info.viewport.x += diff.x;
    app.canvas.scroll_info.viewport.y += diff.y;
    dvui.refresh(null, @src(), scroll_id);
}

fn updateCanvasBounds(scroll_id: dvui.Id, scroll_rect_scale: anytype, bounds: ?Rect.Physical) void {
    if (app.canvas.scroll_info.viewport.empty()) return;

    const pad: f32 = 120;
    var bbox = app.canvas.scroll_info.viewport.outsetAll(pad);
    if (bounds) |bb| {
        const scroll_bbox = scroll_rect_scale.rectFromPhysical(bb);
        bbox = bbox.unionWith(scroll_bbox);
    }

    if (bbox.y != 0) {
        const adjust = -bbox.y;
        app.canvas.scroll_info.virtual_size.h += adjust;
        app.canvas.scroll_info.viewport.y += adjust;
        app.canvas.origin.y -= adjust;
        dvui.refresh(null, @src(), scroll_id);
    }

    if (bbox.x != 0) {
        const adjust = -bbox.x;
        app.canvas.scroll_info.virtual_size.w += adjust;
        app.canvas.scroll_info.viewport.x += adjust;
        app.canvas.origin.x -= adjust;
        dvui.refresh(null, @src(), scroll_id);
    }

    if (bbox.h != app.canvas.scroll_info.virtual_size.h) {
        app.canvas.scroll_info.virtual_size.h = bbox.h;
        dvui.refresh(null, @src(), scroll_id);
    }

    if (bbox.w != app.canvas.scroll_info.virtual_size.w) {
        app.canvas.scroll_info.virtual_size.w = bbox.w;
        dvui.refresh(null, @src(), scroll_id);
    }
}

fn resolveWindowCollisions(previous_rects: [app_core.max_files]Rect) void {
    for (&app.files, 0..) |*file, i| {
        if (!file.window_open) continue;
        if (workspace.sameRect(previous_rects[i], file.window_rect)) continue;

        for (app.files, 0..) |other, j| {
            if (i == j or !other.window_open) continue;
            if (workspace.rectsOverlap(file.window_rect, other.window_rect)) {
                file.window_rect = previous_rects[i];
                break;
            }
        }
    }
}
