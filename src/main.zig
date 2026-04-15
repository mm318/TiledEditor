const std = @import("std");
const dvui = @import("dvui");
const SDLBackend = @import("sdl3gpu-backend");
const c = SDLBackend.c;

const Color = dvui.Color;
const Font = dvui.Font;
const Point = dvui.Point;
const Rect = dvui.Rect;
const ScrollInfo = dvui.ScrollInfo;
const Size = dvui.Size;
const entypo = dvui.entypo;

const vsync = true;
const min_refresh_fps: f32 = 30.0;

const max_files = 4;
const max_text_bytes = 8_192;

const rail_width: f32 = 64.0;
const explorer_width: f32 = 240.0;
const header_height: f32 = 40.0;
const footer_height: f32 = 24.0;

const palette = struct {
    const background = Color.fromHex("#060e20");
    const canvas = Color.fromHex("#07132b");
    const surface = Color.fromHex("#08172f");
    const surface_low = Color.fromHex("#06122d");
    const surface_lowest = Color.fromHex("#020915");
    const surface_high = Color.fromHex("#0a2248");
    const surface_highest = Color.fromHex("#0d2a56");
    const panel = Color.fromHex("#041833");
    const outline = Color.fromHex("#2b4680");
    const outline_soft = Color.fromHex("#1c325b");
    const primary = Color.fromHex("#7bd0ff");
    const primary_soft = Color.fromHex("#2a6d96");
    const primary_dim = Color.fromHex("#4da7d9");
    const text = Color.fromHex("#dee5ff");
    const text_dim = Color.fromHex("#91aaeb");
    const text_soft = Color.fromHex("#60769c");
    const warning = Color.fromHex("#f0b34b");
    const success = Color.fromHex("#8ad9c9");
    const yaml = Color.fromHex("#81d6c6");
    const markdown = Color.fromHex("#b4bed9");
    const gutter = Color.fromHex("#05101f");
    const grid_dot = Color.fromHex("#7bd0ff").opacity(0.08);
};

const monolith_theme = blk: {
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

const Language = enum {
    cpp,
    yaml,
    markdown,
};

const RailMode = enum {
    explorer,
    search,
    layout,
};

const FileSeed = struct {
    name: []const u8,
    path: []const u8,
    language: Language,
    content: []const u8,
    open: bool,
    rect: Rect,
};

const EditorFile = struct {
    name: []const u8 = "",
    path: []const u8 = "",
    language: Language = .cpp,
    content: [max_text_bytes]u8 = [_]u8{0} ** max_text_bytes,
    window_open: bool = false,
    window_rect: Rect = .{},
    z_index: usize = 0,
};

const CanvasState = struct {
    scroll_info: ScrollInfo = .{
        .vertical = .given,
        .horizontal = .given,
    },
    origin: Point = .{},
    scale: f32 = 1.0,
    pending_zoom_delta: f32 = 0.0,
    center_requested: bool = false,
};

const AppState = struct {
    initialized: bool = false,
    sidebar_open: bool = true,
    explorer_root_open: bool = true,
    explorer_src_open: bool = true,
    rail_mode: RailMode = .explorer,
    pending_focus_file: ?usize = null,
    last_active_file: ?usize = 1,
    next_z_index: usize = 1,
    search_buf: [96]u8 = [_]u8{0} ** 96,
    files: [max_files]EditorFile = undefined,
    canvas: CanvasState = .{},
    resize_edges: ResizeEdges = .{},
};

const ResizeEdges = struct {
    left: bool = false,
    right: bool = false,
    top: bool = false,
    bottom: bool = false,

    fn any(self: ResizeEdges) bool {
        return self.left or self.right or self.top or self.bottom;
    }

    fn cursor(self: ResizeEdges) dvui.enums.Cursor {
        if ((self.left and self.top) or (self.right and self.bottom)) return .arrow_nw_se;
        if ((self.right and self.top) or (self.left and self.bottom)) return .arrow_ne_sw;
        if (self.left or self.right) return .arrow_w_e;
        if (self.top or self.bottom) return .arrow_n_s;
        return .arrow;
    }
};

const WindowRenderMeta = struct {
    index: usize,
    frame_wd: dvui.WidgetData,
    header_wd: dvui.WidgetData,
    close_wd: dvui.WidgetData,
};

const initial_files = [_]FileSeed{
    .{
        .name = "main.cpp",
        .path = "src/core/execution",
        .language = .cpp,
        .content =
        \\#include "monolith_core.h"
        \\#include "utils.h"
        \\
        \\int main(int argc) {
        \\  auto engine = Engine::create();
        \\  engine->initialize();
        \\
        \\  while (engine->isRunning()) {
        \\    engine->update();
        \\    engine->render();
        \\  }
        \\
        \\  return 0;
        \\}
        ,
        .open = true,
        .rect = .{ .x = 100, .y = 100, .w = 500, .h = 400 },
    },
    .{
        .name = "utils.h",
        .path = "src/util",
        .language = .cpp,
        .content =
        \\#ifndef UTILS_H
        \\#define UTILS_H
        \\
        \\#include <string>
        \\#include <vector>
        \\
        \\namespace mon_util {
        \\  void log(const std::string& msg);
        \\  std::vector<std::string> split(const std::string& s, char delimiter);
        \\}
        \\
        \\#endif
        ,
        .open = true,
        .rect = .{ .x = 650, .y = 150, .w = 300, .h = 350 },
    },
    .{
        .name = "config.yaml",
        .path = "config",
        .language = .yaml,
        .content =
        \\version: "1.0.4"
        \\env: prod
        \\logging:
        \\  level: debug
        \\  output: stdout
        \\network:
        \\  port: 8080
        \\  host: 0.0.0.0
        ,
        .open = false,
        .rect = .{ .x = 360, .y = 240, .w = 450, .h = 380 },
    },
    .{
        .name = "README.md",
        .path = ".",
        .language = .markdown,
        .content =
        \\# Monolith
        \\
        \\Spatial computing engine for high-performance code exploration.
        \\
        \\## Features
        \\- Tiling spatial layout
        \\- Real-time synchronization
        \\- Minimalist design system
        \\- High-performance rendering
        ,
        .open = false,
        .rect = .{ .x = 420, .y = 280, .w = 450, .h = 380 },
    },
};

var app: AppState = .{};

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;

    if (@import("builtin").os.tag == .windows) {
        dvui.Backend.Common.windowsAttachConsole() catch {};
    }

    SDLBackend.enableSDLLogging();
    std.log.info("SDL version: {f}", .{SDLBackend.getSDLVersion()});

    var backend = try SDLBackend.initWindow(.{
        .allocator = gpa,
        .size = .{ .w = 1450.0, .h = 920.0 },
        .min_size = .{ .w = 900.0, .h = 620.0 },
        .vsync = vsync,
        .title = "Monolith",
    });
    defer backend.deinit();

    _ = c.SDL_EnableScreenSaver();

    var win = try dvui.Window.init(@src(), gpa, backend.backend(), .{
        .theme = monolith_theme,
    });
    defer win.deinit();

    var interrupted = false;
    const max_wait: u32 = @intFromFloat(1_000_000.0 / min_refresh_fps);

    main_loop: while (true) {
        const nstime = win.beginWait(interrupted);
        try win.begin(nstime);

        const quit = try backend.addAllEvents(&win);
        const keep = guiFrame() and !quit;

        const end_micros = try win.end(.{});
        try backend.setCursor(win.cursorRequested());
        try backend.textInputRect(win.textInputRequested());
        try backend.renderPresent();

        if (!keep) break :main_loop;

        const wait_micros = @min(win.waitTime(end_micros), max_wait);
        interrupted = try backend.waitEventTimeout(wait_micros);
    }
}

fn guiFrame() bool {
    ensureAppState();
    drawAppChrome();
    return checkQuit();
}

fn ensureAppState() void {
    if (app.initialized) return;

    var next_z: usize = 1;
    for (initial_files, 0..) |seed, i| {
        app.files[i] = .{
            .name = seed.name,
            .path = seed.path,
            .language = seed.language,
            .window_open = seed.open,
            .window_rect = seed.rect,
            .z_index = if (seed.open) blk: {
                defer next_z += 1;
                break :blk next_z;
            } else 0,
        };
        setFileText(&app.files[i], seed.content);
    }

    app.next_z_index = next_z;
    app.pending_focus_file = 1;
    app.last_active_file = 1;
    app.initialized = true;
}

fn drawAppChrome() void {
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

    drawFooter();
}

fn drawTopBar() void {
    var header = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .horizontal,
        .min_size_content = .{ .h = header_height },
        .max_size_content = .height(header_height),
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
        .min_size_content = .{ .w = rail_width },
        .max_size_content = .width(rail_width),
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
        .min_size_content = .{ .w = explorer_width },
        .max_size_content = .width(explorer_width),
        .expand = .vertical,
        .background = true,
        .color_fill = palette.panel,
        .color_border = palette.outline_soft,
        .border = .{ .w = 1 },
    });

    // Register as subwindow so mouse events are routed here
    // instead of passing through to the canvas below.
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

    const query = searchQuery();
    var visible_count: usize = 0;

    if (explorerRow(100, "monolith-core", entypo.folder, 0, true, app.explorer_root_open, true)) {
        app.explorer_root_open = !app.explorer_root_open;
    }

    if (app.explorer_root_open) {
        if (explorerRow(101, "src", entypo.folder, 18, true, app.explorer_src_open, true)) {
            app.explorer_src_open = !app.explorer_src_open;
        }

        if (app.explorer_src_open) {
            for (app.files, 0..) |file, i| {
                if (!matchesSearch(&file, query)) continue;
                visible_count += 1;

                if (explorerRow(200 + i, file.name, entypo.text_document, 40, file.window_open, false, false)) {
                    openFile(i);
                }
            }
        }
    }

    if (visible_count == 0 and query.len > 0) {
        var empty = dvui.box(@src(), .{}, .{
            .padding = .{ .x = 18, .y = 14, .w = 18, .h = 14 },
        });
        defer empty.deinit();
        dvui.labelNoFmt(@src(), "No matching files", .{}, .{
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
            .color_text = if (has_disclosure) palette.primary else iconColor(label),
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

    drawSpatialCanvas();
    if (app.sidebar_open) {
        drawExplorerPanel();
    }
    drawCommandStrip();
    drawZoomDock();
}

fn drawSpatialCanvas() void {
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

    var previous_rects: [max_files]Rect = undefined;
    for (app.files, 0..) |file, i| {
        previous_rects[i] = file.window_rect;
    }

    if (app.pending_focus_file) |idx| {
        if (app.files[idx].window_open) {
            bringFileToFront(idx);
        }
        app.pending_focus_file = null;
    }

    var bounds: ?Rect.Physical = null;
    const active_idx = activeFile();

    var render_order: [max_files]usize = undefined;
    const render_count = buildOpenWindowOrder(&render_order);
    var metas: [max_files]WindowRenderMeta = undefined;
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
            if (firstOpenFile()) |fallback| {
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

fn drawEditorWindow(index: usize, file: *EditorFile, is_active: bool, bounds: *?Rect.Physical, meta: *WindowRenderMeta) void {
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
            .color_text = fileAccentColor(file.language),
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

fn drawLineGutter(index: usize, file: *const EditorFile) void {
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

    const total_lines = countLines(fileText(file));
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

fn drawEditorTextEntry(index: usize, file: *EditorFile) void {
    const cw = dvui.currentWindow();

    // Prevent focus changes from scrolling the canvas.
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

    // The active window's text entry should always have keyboard focus.
    if (dvui.focusedWidgetId() != te.data().id) {
        dvui.focusWidget(te.data().id, null, null);
    }
    cw.scroll_to_focused = false;

    // Intercept Ctrl+Tab before the text entry consumes it.
    for (dvui.events()) |*e| {
        if (e.handled or e.evt != .key) continue;
        const ke = e.evt.key;
        if (ke.code == .tab and (ke.action == .down or ke.action == .repeat) and ke.mod.control()) {
            e.handle(@src(), te.data());
            cycleFocusWindow();
            dvui.refresh(null, @src(), te.data().id);
        }
    }

    te.processEvents();
    cw.scroll_to_focused = false;

    // Draw text and cursor without the focus border (the window frame
    // already provides the active-window highlight).
    te.drawBeforeText();
    te.textLayout.addText(te.text[0..te.len], te.data().options.strip());
    te.textLayout.addTextDone(te.data().options.strip());
    if (te.data().id == dvui.focusedWidgetId()) {
        te.drawCursor();
    }
    dvui.clipSet(te.prevClip);

    te.deinit();
}

fn drawEditorPreview(index: usize, file: *const EditorFile) void {
    var tl = dvui.textLayout(@src(), .{}, .{
        .id_extra = 40_000 + index,
        .expand = .both,
        .background = false,
        .padding = .{ .x = 12, .y = 10, .w = 12, .h = 10 },
        .font = Font.theme(.mono).larger(-1),
    });
    defer tl.deinit();

    tl.addText(fileText(file), .{
        .color_text = palette.text_soft.opacity(0.95),
    });
}

const resize_border: f32 = 6.0;
const min_window_w: f32 = 180.0;
const min_window_h: f32 = 100.0;

fn detectResizeEdges(frame_rect: Rect.Physical, p: Point.Physical) ResizeEdges {
    return .{
        .left = p.x <= frame_rect.x + resize_border,
        .right = p.x >= frame_rect.x + frame_rect.w - resize_border,
        .top = p.y <= frame_rect.y + resize_border,
        .bottom = p.y >= frame_rect.y + frame_rect.h - resize_border,
    };
}

fn processEditorWindowInteractions(metas: []const WindowRenderMeta, scroll_container: *dvui.ScrollContainerWidget, data_rect_scale: anytype) void {
    // First pass: focus on any press inside a window (even if already handled by a child widget)
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
                bringFileToFront(meta.index);
                dvui.refresh(null, @src(), scroll_container.data().id);
                break;
            }
        }
    }

    // Second pass: handle interactions (close, drag, resize)
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

            // Cursor feedback
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

            // Close button
            if (close_rect.contains(me.p) and !captured_here) {
                if (me.action == .press and me.button.pointer()) {
                    e.handle(@src(), &meta.close_wd);
                    file.window_open = false;
                    if (app.last_active_file != null and app.last_active_file.? == meta.index) {
                        app.last_active_file = firstOpenFile();
                    }
                    dvui.refresh(null, @src(), scroll_container.data().id);
                }
                break;
            }

            // Resize: press on border edge
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

            // Header drag (move)
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

            // Click on body - just consume
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

        // Ctrl+Tab: cycle focus through open windows
        if (e.evt == .key) {
            const ke = e.evt.key;
            if (ke.code == .tab and (ke.action == .down or ke.action == .repeat) and ke.mod.control()) {
                e.handle(@src(), scroll_container.data());
                cycleFocusWindow();
                dvui.refresh(null, @src(), scroll_container.data().id);
                continue;
            }
        }

        if (!scroll_container.matchEvent(e)) continue;

        switch (e.evt) {
            .mouse => |me| {
                // Left-click on blank canvas: defocus all windows
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

fn resolveWindowCollisions(previous_rects: [max_files]Rect) void {
    for (&app.files, 0..) |*file, i| {
        if (!file.window_open) continue;
        if (sameRect(previous_rects[i], file.window_rect)) continue;

        for (app.files, 0..) |other, j| {
            if (i == j or !other.window_open) continue;
            if (rectsOverlap(file.window_rect, other.window_rect)) {
                file.window_rect = previous_rects[i];
                break;
            }
        }
    }
}

fn drawCommandStrip() void {
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
        rearrangeWindows();
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

fn drawZoomDock() void {
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
    const active_idx = activeFile();

    for (app.files, 0..) |file, i| {
        if (!file.window_open) continue;
        const vr = fileVirtualRect(file.window_rect);
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

fn drawFooter() void {
    var footer = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .horizontal,
        .min_size_content = .{ .h = footer_height },
        .max_size_content = .height(footer_height),
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
        dvui.labelNoFmt(@src(), activeLanguageLabel(), .{ .align_y = 0.5 }, .{
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

fn openFile(index: usize) void {
    if (app.files[index].window_open) {
        app.pending_focus_file = index;
        return;
    }

    app.files[index].window_open = true;
    app.files[index].window_rect = findSpawnRect();
    app.pending_focus_file = index;
}

fn bringFileToFront(index: usize) void {
    if (!app.files[index].window_open) return;
    app.files[index].z_index = app.next_z_index;
    app.next_z_index += 1;
    app.last_active_file = index;
}

fn cycleFocusWindow() void {
    var order: [max_files]usize = undefined;
    const count = buildOpenWindowOrder(&order);
    if (count == 0) return;

    // Find current active in z-order
    const current = app.last_active_file;
    var current_pos: ?usize = null;
    if (current) |idx| {
        for (order[0..count], 0..) |file_idx, pos| {
            if (file_idx == idx) {
                current_pos = pos;
                break;
            }
        }
    }

    // Cycle to next in z-order (wrapping), or first if none active
    const next_pos = if (current_pos) |pos| (pos + 1) % count else 0;
    bringFileToFront(order[next_pos]);
}

fn buildOpenWindowOrder(order: *[max_files]usize) usize {
    var count: usize = 0;
    for (app.files, 0..) |file, i| {
        if (!file.window_open) continue;
        order[count] = i;
        count += 1;
    }

    var i: usize = 1;
    while (i < count) : (i += 1) {
        const idx = order[i];
        var j = i;
        while (j > 0 and app.files[order[j - 1]].z_index > app.files[idx].z_index) : (j -= 1) {
            order[j] = order[j - 1];
        }
        order[j] = idx;
    }

    return count;
}

fn findSpawnRect() Rect {
    const width: f32 = 450;
    const height: f32 = 380;
    const gap: f32 = 20;

    var x: f32 = 200;
    var y: f32 = 150;
    var attempt: usize = 0;
    while (attempt < 64) : (attempt += 1) {
        const candidate = Rect{ .x = x, .y = y, .w = width, .h = height };
        if (!anyOpenWindowOverlaps(candidate, null)) {
            return candidate;
        }
        x += gap;
        y += gap;
    }

    return .{ .x = 200, .y = 150, .w = width, .h = height };
}

fn rearrangeWindows() void {
    const count = openWindowCount();
    if (count == 0) return;

    const cols: usize = @max(1, @as(usize, @intFromFloat(@ceil(std.math.sqrt(@as(f64, @floatFromInt(count)))))));
    const width: f32 = 500;
    const height: f32 = 400;
    const gap: f32 = 20;

    var nth_open: usize = 0;
    for (&app.files) |*file| {
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

fn openWindowCount() usize {
    var count: usize = 0;
    for (app.files) |file| {
        if (file.window_open) count += 1;
    }
    return count;
}

fn anyOpenWindowOverlaps(candidate: Rect, skip_index: ?usize) bool {
    for (app.files, 0..) |file, i| {
        if (skip_index != null and skip_index.? == i) continue;
        if (!file.window_open) continue;
        if (rectsOverlap(candidate, file.window_rect)) return true;
    }
    return false;
}

fn rectsOverlap(a: Rect, b: Rect) bool {
    return !(a.x + a.w <= b.x or a.x >= b.x + b.w or a.y + a.h <= b.y or a.y >= b.y + b.h);
}

fn sameRect(a: Rect, b: Rect) bool {
    return a.x == b.x and a.y == b.y and a.w == b.w and a.h == b.h;
}

fn setFileText(file: *EditorFile, text: []const u8) void {
    @memset(file.content[0..], 0);
    const len = @min(text.len, file.content.len - 1);
    @memcpy(file.content[0..len], text[0..len]);
}

fn fileText(file: *const EditorFile) []const u8 {
    return std.mem.sliceTo(file.content[0..], 0);
}

fn searchQuery() []const u8 {
    return std.mem.sliceTo(app.search_buf[0..], 0);
}

fn matchesSearch(file: *const EditorFile, query: []const u8) bool {
    if (query.len == 0) return true;
    return containsIgnoreCase(file.name, query) or containsIgnoreCase(file.path, query);
}

fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
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

fn countLines(text: []const u8) usize {
    if (text.len == 0) return 1;
    return std.mem.count(u8, text, "\n") + 1;
}

fn fileAccentColor(language: Language) Color {
    return switch (language) {
        .cpp => palette.primary,
        .yaml => palette.yaml,
        .markdown => palette.markdown,
    };
}

fn iconColor(name: []const u8) Color {
    _ = name;
    return palette.text_dim;
}

fn fileVirtualRect(r: Rect) Rect {
    return .{
        .x = (r.x - app.canvas.origin.x) * app.canvas.scale,
        .y = (r.y - app.canvas.origin.y) * app.canvas.scale,
        .w = r.w * app.canvas.scale,
        .h = r.h * app.canvas.scale,
    };
}

fn firstOpenFile() ?usize {
    for (app.files, 0..) |file, i| {
        if (file.window_open) return i;
    }
    return null;
}

fn activeFile() ?usize {
    if (app.pending_focus_file) |idx| {
        if (app.files[idx].window_open) return idx;
    }

    if (app.last_active_file) |idx| {
        if (app.files[idx].window_open) return idx;
    }
    return null;
}

fn activeLanguageLabel() []const u8 {
    if (activeFile()) |idx| {
        return switch (app.files[idx].language) {
            .cpp => "C++ 20",
            .yaml => "YAML",
            .markdown => "Markdown",
        };
    }
    return "Spatial";
}

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
