const std = @import("std");
const dvui = @import("dvui");
const SDLBackend = @import("sdl3gpu-backend");
const c = SDLBackend.c;

var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = gpa_instance.allocator();

const vsync = true;
const min_refresh_fps: f32 = 30.0;
const show_demo = true;
const show_debug_window = true;

const CanvasTarget = extern struct {
    texture: *c.SDL_GPUTexture,
    sampler: *c.SDL_GPUSampler,
};

var open_debug_window_next_frame = show_debug_window;
var canvas_time: f32 = 0.0;
var canvas_target: ?dvui.TextureTarget = null;
var canvas_texture: ?dvui.Texture = null;

/// This example shows how to use dvui for a normal application:
/// - dvui owns frame scheduling/event wait
/// - a custom SDL3GPU canvas is rendered into a dvui image widget
pub fn main() !void {
    if (@import("builtin").os.tag == .windows) {
        dvui.Backend.Common.windowsAttachConsole() catch {};
    }

    SDLBackend.enableSDLLogging();
    std.log.info("SDL version: {f}", .{SDLBackend.getSDLVersion()});

    dvui.Examples.show_demo_window = show_demo;

    defer if (gpa_instance.deinit() != .ok) @panic("Memory leak on exit!");

    var backend = try SDLBackend.initWindow(.{
        .allocator = gpa,
        .size = .{ .w = 800.0, .h = 600.0 },
        .min_size = .{ .w = 320.0, .h = 240.0 },
        .vsync = vsync,
        .title = "DVUI Standalone + SDL3GPU Canvas Widget",
    });
    defer backend.deinit();
    defer cleanupCanvasResources(&backend);

    _ = c.SDL_EnableScreenSaver();

    var win = try dvui.Window.init(@src(), gpa, backend.backend(), .{
        .theme = switch (backend.preferredColorScheme() orelse .light) {
            .light => dvui.Theme.builtin.adwaita_light,
            .dark => dvui.Theme.builtin.adwaita_dark,
        },
    });
    defer win.deinit();

    var interrupted = false;
    const max_wait_between_frames_micros: u32 = @intFromFloat(1_000_000.0 / min_refresh_fps);

    main_loop: while (true) {
        const nstime = win.beginWait(interrupted);
        try win.begin(nstime);

        const quit = try backend.addAllEvents(&win);
        // Always build the frame, even on quit events, so backend uploads/draws stay valid.
        const frame_keep_running = gui_frame(&backend);
        const keep_running = frame_keep_running and !quit;

        const end_micros = try win.end(.{});

        try backend.setCursor(win.cursorRequested());
        try backend.textInputRect(win.textInputRequested());
        try backend.renderPresent();

        if (!keep_running) break :main_loop;

        // Keep redraws alive even when dvui has no pending refresh, best-effort >= 30 FPS.
        const wait_event_micros = @min(win.waitTime(end_micros), max_wait_between_frames_micros);
        interrupted = try backend.waitEventTimeout(wait_event_micros);
    }
}

fn gui_frame(backend: *SDLBackend.SDLBackend) bool {
    const px = backend.pixelSize();
    const canvas_w = @max(@as(u32, 1), @as(u32, @intFromFloat(px.w)));
    const canvas_h = @max(@as(u32, 1), @as(u32, @intFromFloat(px.h)));

    ensureCanvasTexture(backend, canvas_w, canvas_h) catch |err| {
        std.log.err("Could not create canvas target {}x{}: {any}", .{ canvas_w, canvas_h, err });
    };

    if (canvas_target) |target| {
        renderCanvasTarget(backend, target);
    }

    {
        var root = dvui.box(@src(), .{}, .{
            .name = "main",
            .expand = .both,
            .background = true,
        });
        defer root.deinit();

        if (canvas_texture) |tex| {
            _ = dvui.image(@src(), .{
                .source = .{ .texture = tex },
                .shrink = .both,
            }, .{
                .name = "sdl3_canvas",
                .expand = .both,
                .margin = .{},
                .padding = .{},
                .border = .{},
                .corner_radius = .{},
            });
        } else {
            dvui.labelNoFmt(@src(), "Canvas unavailable", .{}, .{ .expand = .both });
        }
    }

    if (open_debug_window_next_frame) {
        dvui.toggleDebugWindow();
        open_debug_window_next_frame = false;
    }

    // Demo window is floating and appears over the main canvas widget.
    dvui.Examples.demo();

    for (dvui.events()) |*e| {
        if (e.evt == .window and e.evt.window.action == .close) return false;
        if (e.evt == .app and e.evt.app.action == .quit) return false;
    }

    return true;
}

fn ensureCanvasTexture(backend: *SDLBackend.SDLBackend, width: u32, height: u32) !void {
    if (canvas_target) |target| {
        if (target.width == width and target.height == height) return;
        cleanupCanvasResources(backend);
    }

    const target = try backend.textureCreateTarget(width, height, .linear);
    const texture = try backend.textureFromTarget(target);
    canvas_target = target;
    canvas_texture = texture;
}

fn cleanupCanvasResources(backend: *SDLBackend.SDLBackend) void {
    if (canvas_texture) |tex| {
        backend.textureDestroy(tex);
    }
    canvas_texture = null;
    canvas_target = null;
}

fn renderCanvasTarget(backend: *SDLBackend.SDLBackend, target: dvui.TextureTarget) void {
    const cmd = backend.cmd orelse return;

    canvas_time += 0.016;

    const r_wave = (@sin(@as(f64, canvas_time) * 0.7) + 1.0) * 0.5;
    const g_wave = (@sin(@as(f64, canvas_time) * 1.1 + 1.2) + 1.0) * 0.5;
    const b_wave = (@sin(@as(f64, canvas_time) * 0.5 + 2.4) + 1.0) * 0.5;

    const target_impl: *CanvasTarget = @ptrCast(@alignCast(target.ptr));

    var color_target = std.mem.zeroes(c.SDL_GPUColorTargetInfo);
    color_target.texture = target_impl.texture;
    color_target.clear_color = .{
        .r = @floatCast(0.05 + 0.18 * r_wave),
        .g = @floatCast(0.07 + 0.20 * g_wave),
        .b = @floatCast(0.11 + 0.24 * b_wave),
        .a = 1.0,
    };
    color_target.load_op = c.SDL_GPU_LOADOP_CLEAR;
    color_target.store_op = c.SDL_GPU_STOREOP_STORE;

    const pass = c.SDL_BeginGPURenderPass(cmd, &color_target, 1, null) orelse {
        std.log.err("Failed to begin canvas target pass: {s}", .{c.SDL_GetError()});
        return;
    };
    c.SDL_EndGPURenderPass(pass);
}
