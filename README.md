# Monolith

Monolith is a spatial text editor written in Zig using `dvui`, the SDL3 GPU backend, and a bundled Tree-sitter language pack.

It loads a project directory, indexes text files, and presents them as draggable editor windows on an infinite canvas with:

- A project explorer sidebar
- Full-text search across loaded files
- A layout panel for rearranging and recentering windows
- Syntax highlighting when a Tree-sitter grammar is available
- A minimap and canvas zoom controls

## Usage

Run all commands from the project root.

### Build

Build the executable:

```bash
zig build
```

Build with a release optimization mode:

```bash
zig build -Doptimize=ReleaseSafe
```

### Run

Run Monolith against the current directory:

```bash
zig build -Doptimize=ReleaseSafe run
```

Run Monolith against a specific project path:

```bash
zig build -Doptimize=ReleaseSafe run -- /path/to/project
```

### Controls

- Use the left rail to switch between Explorer, Search, and Layout panels
- Click a file in Explorer or Search to open it on the canvas
- Drag window headers to move windows
- Drag window borders or corners to resize windows
- `Ctrl+Tab` cycles focus through open windows
- `Ctrl` + mouse wheel zooms the canvas
- Middle mouse drag pans the canvas

### Development

Format the source:

```bash
zig fmt .
```

List available build steps:

```bash
zig build --help
```

## Notes

- If no project path is provided, Monolith opens the current working directory
- Binary files are ignored; only text files are loaded
- Common generated or vendor directories such as `.git`, `zig-cache`, `zig-out`, `zig-pkg`, and `node_modules` are skipped
- File loading is capped at `512 KiB` per file, and editable buffers are capped at `2 MiB`

## Environment

Monolith was developed and tested on Ubuntu 24.04 under Wayland with Zig 0.16.0, SDL3 3.4.4, and the SDL3 GPU Vulkan backend.
