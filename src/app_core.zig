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

pub const max_files = 4;
pub const max_text_bytes = 8_192;

pub const rail_width: f32 = 64.0;
pub const explorer_width: f32 = 240.0;
pub const header_height: f32 = 40.0;
pub const footer_height: f32 = 24.0;

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
};

pub const RailMode = enum {
    explorer,
    search,
    layout,
};

pub const FileSeed = struct {
    name: []const u8,
    path: []const u8,
    language: Language,
    content: []const u8,
    open: bool,
    rect: Rect,
};

pub const EditorFile = struct {
    name: []const u8 = "",
    path: []const u8 = "",
    language: Language = .cpp,
    content: [max_text_bytes]u8 = [_]u8{0} ** max_text_bytes,
    window_open: bool = false,
    window_rect: Rect = .{},
    z_index: usize = 0,
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

pub const AppState = struct {
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

pub const WindowRenderMeta = struct {
    index: usize,
    frame_wd: dvui.WidgetData,
    header_wd: dvui.WidgetData,
    close_wd: dvui.WidgetData,
};

pub const initial_files = [_]FileSeed{
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

pub var app: AppState = .{};

pub fn setFileText(file: *EditorFile, text: []const u8) void {
    @memset(file.content[0..], 0);
    const len = @min(text.len, file.content.len - 1);
    @memcpy(file.content[0..len], text[0..len]);
}

pub fn fileText(file: *const EditorFile) []const u8 {
    return std.mem.sliceTo(file.content[0..], 0);
}

pub fn ensureAppState() void {
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
