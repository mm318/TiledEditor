const std = @import("std");
const dvui = @import("dvui");
const SDLBackend = @import("sdl3gpu-backend");
const c = SDLBackend.c;

const app_core = @import("app_core.zig");
const chrome_layout = @import("chrome_layout.zig");
const workspace = @import("workspace.zig");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    try app_core.initRuntime(init);
    defer app_core.deinit();

    if (@import("builtin").os.tag == .windows) {
        dvui.Backend.Common.windowsAttachConsole() catch {};
    }

    SDLBackend.enableSDLLogging();
    std.log.info("SDL version: {f}", .{SDLBackend.getSDLVersion()});

    var backend = try SDLBackend.initWindow(.{
        .allocator = gpa,
        .size = .{ .w = 1450.0, .h = 920.0 },
        .min_size = .{ .w = 900.0, .h = 620.0 },
        .vsync = app_core.vsync,
        .title = "Monolith",
    });
    defer backend.deinit();

    _ = c.SDL_EnableScreenSaver();

    var win = try dvui.Window.init(@src(), gpa, backend.backend(), .{
        .theme = app_core.monolith_theme,
    });
    defer win.deinit();

    var interrupted = false;
    const max_wait: u32 = @intFromFloat(1_000_000.0 / app_core.min_refresh_fps);

    main_loop: while (true) {
        const nstime = win.beginWait(interrupted);
        try win.begin(nstime);

        const quit = try backend.addAllEvents(&win);
        const keep = (try guiFrame()) and !quit;

        const end_micros = try win.end(.{});
        try backend.setCursor(win.cursorRequested());
        try backend.textInputRect(win.textInputRequested());
        try backend.renderPresent();

        if (!keep) break :main_loop;

        const wait_micros = @min(win.waitTime(end_micros), max_wait);
        interrupted = try backend.waitEventTimeout(wait_micros);
    }
}

fn guiFrame() !bool {
    try app_core.ensureAppState();
    chrome_layout.drawAppChrome();
    return workspace.checkQuit();
}
