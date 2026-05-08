const std = @import("std");

const Repo = struct {
    dir_name: []const u8,
};

const QueryFiles = struct {
    highlights: []const []const u8 = &.{},
    injections: []const []const u8 = &.{},
    locals: []const []const u8 = &.{},
    folds: []const []const u8 = &.{},
    tags: []const []const u8 = &.{},
};

const GrammarConfig = struct {
    rel_in_repo: []const u8,
    display_name: []const u8,
    file_types: []const []const u8 = &.{},
    queries: QueryFiles = .{},
    has_content_regex: bool = false,
};

const Grammar = struct {
    repo_dir: []const u8,
    rel_root: []const u8,
    rel_in_repo: []const u8,
    module_name: []const u8,
    symbol: []const u8,
    display_name: []const u8,
    file_types: []const []const u8,
    queries: QueryFiles,
    path_matchable: bool,
    canonical: bool = true,
    order_index: usize,
};

const vendor_repositories = [_]Repo{
    .{ .dir_name = "tree-sitter-agda" },
    .{ .dir_name = "tree-sitter-arduino" },
    .{ .dir_name = "tree-sitter-bash" },
    .{ .dir_name = "tree-sitter-bicep" },
    .{ .dir_name = "tree-sitter-bitbake" },
    .{ .dir_name = "tree-sitter-c" },
    .{ .dir_name = "tree-sitter-c-sharp" },
    .{ .dir_name = "tree-sitter-cairo" },
    .{ .dir_name = "tree-sitter-capnp" },
    .{ .dir_name = "tree-sitter-chatl" },
    .{ .dir_name = "tree-sitter-chatito" },
    .{ .dir_name = "tree-sitter-commonlisp" },
    .{ .dir_name = "tree-sitter-cpon" },
    .{ .dir_name = "tree-sitter-cpp" },
    .{ .dir_name = "tree-sitter-css" },
    .{ .dir_name = "tree-sitter-cst" },
    .{ .dir_name = "tree-sitter-csv" },
    .{ .dir_name = "tree-sitter-cuda" },
    .{ .dir_name = "tree-sitter-cyberchef" },
    .{ .dir_name = "tree-sitter-diff" },
    .{ .dir_name = "tree-sitter-doxygen" },
    .{ .dir_name = "tree-sitter-embedded-template" },
    .{ .dir_name = "tree-sitter-firrtl" },
    .{ .dir_name = "tree-sitter-fluent" },
    .{ .dir_name = "tree-sitter-func" },
    .{ .dir_name = "tree-sitter-gitattributes" },
    .{ .dir_name = "tree-sitter-glsl" },
    .{ .dir_name = "tree-sitter-gn" },
    .{ .dir_name = "tree-sitter-go" },
    .{ .dir_name = "tree-sitter-go-sum" },
    .{ .dir_name = "tree-sitter-gpg-config" },
    .{ .dir_name = "tree-sitter-graph" },
    .{ .dir_name = "tree-sitter-gstlaunch" },
    .{ .dir_name = "tree-sitter-hare" },
    .{ .dir_name = "tree-sitter-haskell" },
    .{ .dir_name = "tree-sitter-hcl" },
    .{ .dir_name = "tree-sitter-hlsl" },
    .{ .dir_name = "tree-sitter-html" },
    .{ .dir_name = "tree-sitter-hyprlang" },
    .{ .dir_name = "tree-sitter-ispc" },
    .{ .dir_name = "tree-sitter-java" },
    .{ .dir_name = "tree-sitter-javascript" },
    .{ .dir_name = "tree-sitter-jsdoc" },
    .{ .dir_name = "tree-sitter-json" },
    .{ .dir_name = "tree-sitter-julia" },
    .{ .dir_name = "tree-sitter-kconfig" },
    .{ .dir_name = "tree-sitter-kdl" },
    .{ .dir_name = "tree-sitter-kotlin" },
    .{ .dir_name = "tree-sitter-linkerscript" },
    .{ .dir_name = "tree-sitter-lua" },
    .{ .dir_name = "tree-sitter-luadoc" },
    .{ .dir_name = "tree-sitter-luap" },
    .{ .dir_name = "tree-sitter-luau" },
    .{ .dir_name = "tree-sitter-make" },
    .{ .dir_name = "tree-sitter-markdown" },
    .{ .dir_name = "tree-sitter-markdown-inline" },
    .{ .dir_name = "tree-sitter-meson" },
    .{ .dir_name = "tree-sitter-move" },
    .{ .dir_name = "tree-sitter-nqc" },
    .{ .dir_name = "tree-sitter-objc" },
    .{ .dir_name = "tree-sitter-ocaml" },
    .{ .dir_name = "tree-sitter-odin" },
    .{ .dir_name = "tree-sitter-pem" },
    .{ .dir_name = "tree-sitter-php" },
    .{ .dir_name = "tree-sitter-php-only" },
    .{ .dir_name = "tree-sitter-po" },
    .{ .dir_name = "tree-sitter-poe-filter" },
    .{ .dir_name = "tree-sitter-pony" },
    .{ .dir_name = "tree-sitter-printf" },
    .{ .dir_name = "tree-sitter-psv" },
    .{ .dir_name = "tree-sitter-properties" },
    .{ .dir_name = "tree-sitter-puppet" },
    .{ .dir_name = "tree-sitter-pymanifest" },
    .{ .dir_name = "tree-sitter-python" },
    .{ .dir_name = "tree-sitter-ql" },
    .{ .dir_name = "tree-sitter-ql-dbscheme" },
    .{ .dir_name = "tree-sitter-qmldir" },
    .{ .dir_name = "tree-sitter-query" },
    .{ .dir_name = "tree-sitter-re2c" },
    .{ .dir_name = "tree-sitter-readline" },
    .{ .dir_name = "tree-sitter-regex" },
    .{ .dir_name = "tree-sitter-requirements" },
    .{ .dir_name = "tree-sitter-ron" },
    .{ .dir_name = "tree-sitter-ruby" },
    .{ .dir_name = "tree-sitter-rust" },
    .{ .dir_name = "tree-sitter-scala" },
    .{ .dir_name = "tree-sitter-scss" },
    .{ .dir_name = "tree-sitter-slang" },
    .{ .dir_name = "tree-sitter-smali" },
    .{ .dir_name = "tree-sitter-squirrel" },
    .{ .dir_name = "tree-sitter-ssh-config" },
    .{ .dir_name = "tree-sitter-starlark" },
    .{ .dir_name = "tree-sitter-svelte" },
    .{ .dir_name = "tree-sitter-tablegen" },
    .{ .dir_name = "tree-sitter-tcl" },
    .{ .dir_name = "tree-sitter-terraform" },
    .{ .dir_name = "tree-sitter-test" },
    .{ .dir_name = "tree-sitter-thrift" },
    .{ .dir_name = "tree-sitter-toml" },
    .{ .dir_name = "tree-sitter-tsv" },
    .{ .dir_name = "tree-sitter-tsx" },
    .{ .dir_name = "tree-sitter-typescript" },
    .{ .dir_name = "tree-sitter-udev" },
    .{ .dir_name = "tree-sitter-ungrammar" },
    .{ .dir_name = "tree-sitter-uxntal" },
    .{ .dir_name = "tree-sitter-verilog" },
    .{ .dir_name = "tree-sitter-vim" },
    .{ .dir_name = "tree-sitter-vue" },
    .{ .dir_name = "tree-sitter-wgsl-bevy" },
    .{ .dir_name = "tree-sitter-xcompose" },
    .{ .dir_name = "tree-sitter-xml" },
    .{ .dir_name = "tree-sitter-yaml" },
    .{ .dir_name = "tree-sitter-yuck" },
    .{ .dir_name = "tree-sitter-zig" },
};

/// Discover vendored grammars, generate one Zig wrapper module per grammar,
/// and compile the corresponding parser C sources into static libraries.
pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const grammars = try loadGrammars(b);
    const write_files = b.addWriteFiles();

    const registry_source = try makeRegistrySource(b, grammars);
    const registry_mod = b.addModule("tree_sitter_language_pack", .{
        .root_source_file = write_files.add("tree_sitter_language_pack.zig", registry_source),
        .target = target,
        .optimize = optimize,
    });

    for (grammars) |grammar| {
        const grammar_source = try makeGrammarSource(b, grammar);
        const grammar_root_rel = b.pathJoin(&.{ "vendor", grammar.rel_root });
        const grammar_root = b.path(grammar_root_rel);
        const src_dir_rel = b.pathJoin(&.{ grammar_root_rel, "src" });

        const lib = b.addLibrary(.{
            .name = grammar.module_name,
            .linkage = .static,
            .root_module = b.createModule(.{
                .root_source_file = null,
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            }),
        });
        lib.root_module.addIncludePath(b.path(src_dir_rel));
        lib.root_module.addCSourceFiles(.{
            .root = grammar_root,
            .files = &.{"src/parser.c"},
            .flags = &.{"-std=c11"},
        });

        if (fileExists(b, b.pathJoin(&.{ grammar_root_rel, "src", "scanner.c" }))) {
            lib.root_module.addCSourceFiles(.{
                .root = grammar_root,
                .files = &.{"src/scanner.c"},
                .flags = &.{"-std=c11"},
            });
        }

        const mod = b.addModule(grammar.module_name, .{
            .root_source_file = write_files.add(b.fmt("{s}.zig", .{grammar.module_name}), grammar_source),
            .target = target,
            .optimize = optimize,
        });
        mod.linkLibrary(lib);
        if (grammar.canonical) {
            registry_mod.addImport(grammar.module_name, mod);
        }
    }
}

/// Collect every grammar exposed by the vendored repos and reject any module
/// name collisions before generating code.
fn loadGrammars(b: *std.Build) ![]Grammar {
    var list = std.ArrayList(Grammar).empty;
    var order_index: usize = 0;

    for (vendor_repositories) |repo| {
        try appendRepoGrammars(b, &list, repo, &order_index);
    }

    try ensureUniqueModuleNames(b, list.items);
    markCanonical(list.items);
    return list.toOwnedSlice(b.allocator);
}

/// Walk a single repo, discover each `src/parser.c`, and combine filesystem
/// discovery with config metadata into concrete `Grammar` records.
fn appendRepoGrammars(
    b: *std.Build,
    list: *std.ArrayList(Grammar),
    repo: Repo,
    order_index: *usize,
) !void {
    const configs = try loadRepoConfigs(b, repo.dir_name);

    const repo_rel = b.pathJoin(&.{ "vendor", repo.dir_name });
    const repo_abs = b.pathFromRoot(repo_rel);
    var repo_dir = try std.Io.Dir.openDirAbsolute(b.graph.io, repo_abs, .{ .iterate = true });
    defer repo_dir.close(b.graph.io);

    var walker = try std.Io.Dir.walk(repo_dir, b.allocator);
    defer walker.deinit();

    while (try walker.next(b.graph.io)) |entry| {
        if (entry.kind != .file) continue;
        if (!isParserPath(entry.path)) continue;

        const rel_in_repo = grammarRelInRepo(entry.path) orelse continue;
        const rel_root = if (rel_in_repo.len == 0)
            try b.allocator.dupe(u8, repo.dir_name)
        else
            try std.fmt.allocPrint(b.allocator, "{s}/{s}", .{ repo.dir_name, rel_in_repo });

        const parser_rel = b.pathJoin(&.{ "vendor", repo.dir_name, entry.path });
        const symbol = try extractLanguageSymbol(b, parser_rel);
        const module_name = try makeModuleName(b, repo.dir_name, rel_in_repo);

        const config = findBestConfig(configs, rel_in_repo);
        const fallback = manualFallbackConfig(repo.dir_name, rel_in_repo);

        const display_name = if (config) |cfg|
            cfg.display_name
        else if (fallback) |cfg|
            cfg.display_name
        else
            try defaultDisplayName(b, repo.dir_name, rel_in_repo);

        const file_types = if (config) |cfg|
            cfg.file_types
        else if (fallback) |cfg|
            cfg.file_types
        else
            &.{};

        var queries = if (config) |cfg|
            cfg.queries
        else
            QueryFiles{};

        if (queries.highlights.len == 0) queries.highlights = try defaultQueryPaths(b, rel_root, "highlights");
        if (queries.injections.len == 0) queries.injections = try defaultQueryPaths(b, rel_root, "injections");
        if (queries.locals.len == 0) queries.locals = try defaultQueryPaths(b, rel_root, "locals");
        if (queries.folds.len == 0) queries.folds = try defaultQueryPaths(b, rel_root, "folds");
        if (queries.tags.len == 0) queries.tags = try defaultQueryPaths(b, rel_root, "tags");

        try list.append(b.allocator, .{
            .repo_dir = repo.dir_name,
            .rel_root = rel_root,
            .rel_in_repo = try b.allocator.dupe(u8, rel_in_repo),
            .module_name = module_name,
            .symbol = symbol,
            .display_name = display_name,
            .file_types = file_types,
            .queries = queries,
            .path_matchable = file_types.len != 0 and !(config != null and config.?.has_content_regex),
            .order_index = order_index.*,
        });
        order_index.* += 1;
    }
}

/// Load grammar metadata from `tree-sitter.json` when available, otherwise
/// fall back to the older `package.json` tree-sitter section.
fn loadRepoConfigs(b: *std.Build, repo_dir: []const u8) ![]GrammarConfig {
    const tree_sitter_json_rel = b.pathJoin(&.{ "vendor", repo_dir, "tree-sitter.json" });
    if (fileExists(b, tree_sitter_json_rel)) {
        return try parseConfigFile(b, repo_dir, tree_sitter_json_rel, .tree_sitter_json);
    }

    const package_json_rel = b.pathJoin(&.{ "vendor", repo_dir, "package.json" });
    if (fileExists(b, package_json_rel)) {
        return try parseConfigFile(b, repo_dir, package_json_rel, .package_json);
    }

    return &.{};
}

const ConfigFileFormat = enum {
    tree_sitter_json,
    package_json,
};

/// Parse a grammar metadata file and normalize its grammar entries into a
/// uniform in-memory representation.
fn parseConfigFile(
    b: *std.Build,
    repo_dir: []const u8,
    rel_path: []const u8,
    format: ConfigFileFormat,
) ![]GrammarConfig {
    const data = try b.build_root.handle.readFileAlloc(
        b.graph.io,
        rel_path,
        b.allocator,
        .limited(1024 * 1024),
    );
    var parsed = try std.json.parseFromSlice(std.json.Value, b.allocator, data, .{});
    defer parsed.deinit();

    const root = parsed.value;
    if (root != .object) return &.{};

    const field_name = switch (format) {
        .tree_sitter_json => "grammars",
        .package_json => "tree-sitter",
    };

    const node = root.object.get(field_name) orelse return &.{};

    var configs = std.ArrayList(GrammarConfig).empty;
    switch (node) {
        .array => |array| {
            for (array.items) |item| {
                try appendConfigFromValue(b, &configs, repo_dir, item);
            }
        },
        .object => {
            try appendConfigFromValue(b, &configs, repo_dir, node);
        },
        else => {},
    }

    return configs.toOwnedSlice(b.allocator);
}

/// Convert one JSON grammar description into a `GrammarConfig`, including
/// file-type matching and any explicitly declared query paths.
fn appendConfigFromValue(
    b: *std.Build,
    configs: *std.ArrayList(GrammarConfig),
    repo_dir: []const u8,
    value: std.json.Value,
) !void {
    if (value != .object) return;

    const rel_in_repo = if (value.object.get("path")) |path_value|
        try normalizeGrammarPath(b, try duplicateJsonString(b, path_value))
    else
        try b.allocator.dupe(u8, "");

    const display_name = if (value.object.get("camelcase")) |name_value|
        try duplicateJsonString(b, name_value)
    else if (value.object.get("name")) |name_value|
        try duplicateJsonString(b, name_value)
    else
        try defaultDisplayName(b, repo_dir, rel_in_repo);

    try configs.append(b.allocator, .{
        .rel_in_repo = rel_in_repo,
        .display_name = display_name,
        .file_types = try duplicateJsonStringArray(b, value.object.get("file-types")),
        .queries = .{
            .highlights = try duplicateQueryPathArray(b, repo_dir, rel_in_repo, value.object.get("highlights")),
            .injections = try duplicateQueryPathArray(b, repo_dir, rel_in_repo, value.object.get("injections")),
            .locals = try duplicateQueryPathArray(b, repo_dir, rel_in_repo, value.object.get("locals")),
            .folds = try duplicateQueryPathArray(b, repo_dir, rel_in_repo, value.object.get("folds")),
            .tags = try duplicateQueryPathArray(b, repo_dir, rel_in_repo, value.object.get("tags")),
        },
        .has_content_regex = value.object.get("content-regex") != null,
    });
}

/// Copy a required JSON string value into build-owned storage.
fn duplicateJsonString(b: *std.Build, value: std.json.Value) ![]const u8 {
    if (value != .string) return error.InvalidConfigValue;
    return b.allocator.dupe(u8, value.string);
}

/// Normalize a JSON string-or-array field into a flat owned string slice.
fn duplicateJsonStringArray(b: *std.Build, value: ?std.json.Value) ![]const []const u8 {
    const node = value orelse return &.{};
    var strings = std.ArrayList([]const u8).empty;

    switch (node) {
        .string => {
            try strings.append(b.allocator, try b.allocator.dupe(u8, node.string));
        },
        .array => |array| {
            for (array.items) |item| {
                if (item != .string) continue;
                try strings.append(b.allocator, try b.allocator.dupe(u8, item.string));
            }
        },
        else => {},
    }

    return strings.toOwnedSlice(b.allocator);
}

/// Normalize a query field into repo-relative paths, skipping entries that do
/// not resolve to files in the vendored tree.
fn duplicateQueryPathArray(
    b: *std.Build,
    repo_dir: []const u8,
    rel_in_repo: []const u8,
    value: ?std.json.Value,
) ![]const []const u8 {
    const node = value orelse return &.{};
    var paths = std.ArrayList([]const u8).empty;

    switch (node) {
        .string => {
            if (try resolveConfigQueryPath(b, repo_dir, rel_in_repo, node.string)) |path| {
                try paths.append(b.allocator, path);
            }
        },
        .array => |array| {
            for (array.items) |item| {
                if (item != .string) continue;
                if (try resolveConfigQueryPath(b, repo_dir, rel_in_repo, item.string)) |path| {
                    try paths.append(b.allocator, path);
                }
            }
        },
        else => {},
    }

    return paths.toOwnedSlice(b.allocator);
}

/// Resolve a query path from grammar metadata, handling both repo-relative
/// paths and the older grammar-root-relative form used by some repos.
fn resolveConfigQueryPath(
    b: *std.Build,
    repo_dir: []const u8,
    rel_in_repo: []const u8,
    query_path: []const u8,
) !?[]const u8 {
    const rel_under_vendor = if (std.mem.startsWith(u8, query_path, "node_modules/")) blk: {
        const remainder = query_path["node_modules/".len..];
        const slash = std.mem.indexOfScalar(u8, remainder, '/') orelse return null;
        break :blk try std.fmt.allocPrint(b.allocator, "{s}/{s}", .{
            remainder[0..slash],
            remainder[slash + 1 ..],
        });
    } else blk: {
        const repo_relative = try std.fmt.allocPrint(b.allocator, "{s}/{s}", .{ repo_dir, query_path });
        if (fileExists(b, b.pathJoin(&.{ "vendor", repo_relative }))) {
            break :blk repo_relative;
        }

        if (rel_in_repo.len == 0) {
            break :blk repo_relative;
        }

        break :blk try std.fmt.allocPrint(b.allocator, "{s}/{s}/{s}", .{ repo_dir, rel_in_repo, query_path });
    };

    const full_rel = b.pathJoin(&.{ "vendor", rel_under_vendor });
    if (!fileExists(b, full_rel)) return null;
    return rel_under_vendor;
}

/// Treat `"."` in config metadata as the repo root so downstream path logic
/// can use the empty string for root grammars consistently.
fn normalizeGrammarPath(b: *std.Build, raw_path: []const u8) ![]const u8 {
    if (std.mem.eql(u8, raw_path, ".")) {
        b.allocator.free(raw_path);
        return b.allocator.dupe(u8, "");
    }
    return raw_path;
}

/// Probe the conventional `queries/<name>.scm` location under a grammar root
/// when the metadata file does not declare that query explicitly.
fn defaultQueryPaths(
    b: *std.Build,
    rel_root: []const u8,
    comptime query_name: []const u8,
) ![]const []const u8 {
    const rel_under_vendor = b.pathJoin(&.{ rel_root, "queries", query_name ++ ".scm" });
    const full_rel = b.pathJoin(&.{ "vendor", rel_under_vendor });
    if (!fileExists(b, full_rel)) return &.{};

    var paths = try b.allocator.alloc([]const u8, 1);
    paths[0] = rel_under_vendor;
    return paths;
}

/// Supply minimal metadata for repos that do not ship enough config for path
/// matching or display naming.
fn manualFallbackConfig(repo_dir: []const u8, rel_in_repo: []const u8) ?GrammarConfig {
    if (rel_in_repo.len != 0) return null;

    if (std.mem.eql(u8, repo_dir, "tree-sitter-fluent")) {
        return .{ .rel_in_repo = "", .display_name = "Fluent", .file_types = &.{"ftl"} };
    }
    if (std.mem.eql(u8, repo_dir, "tree-sitter-graph")) {
        return .{ .rel_in_repo = "", .display_name = "Tree-Sitter Graph", .file_types = &.{"tsg"} };
    }
    if (std.mem.eql(u8, repo_dir, "tree-sitter-move")) {
        return .{ .rel_in_repo = "", .display_name = "Move", .file_types = &.{"move"} };
    }

    return null;
}

/// Choose the config entry for a discovered grammar root, preferring entries
/// that do not require content-regex disambiguation.
fn findBestConfig(configs: []const GrammarConfig, rel_in_repo: []const u8) ?GrammarConfig {
    var fallback: ?GrammarConfig = null;
    for (configs) |config| {
        if (!std.mem.eql(u8, config.rel_in_repo, rel_in_repo)) continue;
        if (!config.has_content_regex) return config;
        if (fallback == null) fallback = config;
    }
    return fallback;
}

/// Mark the earliest discovered grammar for each exported tree-sitter symbol
/// as canonical so duplicate symbol providers do not both enter the registry.
fn markCanonical(grammars: []Grammar) void {
    for (grammars, 0..) |*grammar, index| {
        grammar.canonical = true;
        var best_index = index;
        for (grammars, 0..) |candidate, candidate_index| {
            if (!std.mem.eql(u8, grammar.symbol, candidate.symbol)) continue;
            if (candidate.order_index < grammars[best_index].order_index) {
                best_index = candidate_index;
            }
        }

        if (best_index != index) {
            grammar.canonical = false;
        }
    }
}

/// Refuse to generate code when two different grammars would collapse to the
/// same Zig module name under the current naming policy.
fn ensureUniqueModuleNames(b: *std.Build, grammars: []const Grammar) !void {
    var seen = std.StringHashMapUnmanaged([]const u8){};
    defer seen.deinit(b.allocator);

    for (grammars) |grammar| {
        const gop = try seen.getOrPut(b.allocator, grammar.module_name);
        if (gop.found_existing) {
            if (!std.mem.eql(u8, gop.value_ptr.*, grammar.rel_root)) {
                std.debug.print(
                    "error: module name collision for {s}: {s} and {s}\n",
                    .{ grammar.module_name, gop.value_ptr.*, grammar.rel_root },
                );
                return error.ModuleNameCollision;
            }
            continue;
        }

        gop.value_ptr.* = grammar.rel_root;
    }
}

/// Generate the top-level registry module that imports canonical grammars and
/// performs path-based runtime lookup by file extension or basename.
fn makeRegistrySource(b: *std.Build, grammars: []const Grammar) ![]u8 {
    var out = std.ArrayList(u8).empty;
    try out.appendSlice(b.allocator,
        \\const std = @import("std");
        \\
    );

    for (grammars) |grammar| {
        if (!grammar.canonical) continue;
        try out.print(b.allocator, "const {s} = @import(\"{s}\");\n", .{ grammar.module_name, grammar.module_name });
    }

    try out.appendSlice(b.allocator,
        \\
        \\pub const GrammarInfo = struct {
        \\    display_name: []const u8,
        \\    module_name: []const u8,
        \\    relative_root: []const u8,
        \\    symbol: []const u8,
        \\};
        \\
        \\pub const Match = struct {
        \\    display_name: []const u8,
        \\    module_name: []const u8,
        \\    relative_root: []const u8,
        \\    symbol: []const u8,
        \\    language: *const anyopaque,
        \\    highlights: ?[]const u8,
        \\    injections: ?[]const u8,
        \\    locals: ?[]const u8,
        \\    folds: ?[]const u8,
        \\    tags: ?[]const u8,
        \\};
        \\
        \\pub const grammars = [_]GrammarInfo{
        \\
    );
    for (grammars) |grammar| {
        if (!grammar.canonical) continue;
        try out.print(
            b.allocator,
            "    .{{ .display_name = \"{s}\", .module_name = \"{s}\", .relative_root = \"{s}\", .symbol = \"{s}\" }},\n",
            .{ grammar.display_name, grammar.module_name, grammar.rel_root, grammar.symbol },
        );
    }
    try out.appendSlice(b.allocator,
        \\};
        \\
        \\pub fn displayNameForPath(path: []const u8) ?[]const u8 {
        \\    return if (lookup(path)) |match| match.display_name else null;
        \\}
        \\
        \\pub fn lookup(path: []const u8) ?Match {
        \\    const basename = std.fs.path.basename(path);
        \\
    );

    for (grammars) |grammar| {
        if (!grammar.canonical or !grammar.path_matchable) continue;

        try out.appendSlice(b.allocator, "    if (matchesFileTypes(basename, &.{");
        for (grammar.file_types) |file_type| {
            try appendZigStringLiteral(b.allocator, &out, file_type);
            try out.appendSlice(b.allocator, ", ");
        }
        try out.print(
            b.allocator,
            "}})) return .{{ .display_name = \"{s}\", .module_name = \"{s}\", .relative_root = \"{s}\", .symbol = \"{s}\", .language = {s}.language(), .highlights = {s}.highlights, .injections = {s}.injections, .locals = {s}.locals, .folds = {s}.folds, .tags = {s}.tags }};\n",
            .{
                grammar.display_name,
                grammar.module_name,
                grammar.rel_root,
                grammar.symbol,
                grammar.module_name,
                grammar.module_name,
                grammar.module_name,
                grammar.module_name,
                grammar.module_name,
                grammar.module_name,
            },
        );
    }

    try out.appendSlice(b.allocator,
        \\
        \\    return null;
        \\}
        \\
        \\fn matchesFileTypes(basename: []const u8, file_types: []const []const u8) bool {
        \\    for (file_types) |file_type| {
        \\        if (matchesFileType(basename, file_type)) return true;
        \\    }
        \\    return false;
        \\}
        \\
        \\fn matchesFileType(basename: []const u8, file_type: []const u8) bool {
        \\    if (std.mem.eql(u8, basename, file_type)) return true;
        \\    if (file_type.len == 0) return false;
        \\    if (file_type[0] == '.') return std.mem.endsWith(u8, basename, file_type);
        \\    if (basename.len <= file_type.len) return false;
        \\    const offset = basename.len - file_type.len;
        \\    return basename[offset - 1] == '.' and std.mem.eql(u8, basename[offset..], file_type);
        \\}
        \\
    );
    return out.toOwnedSlice(b.allocator);
}

/// Generate the tiny Zig wrapper for one grammar: exported language accessor
/// plus embedded highlight and injection query strings.
fn makeGrammarSource(b: *std.Build, grammar: Grammar) ![]u8 {
    var out = std.ArrayList(u8).empty;
    try out.print(
        b.allocator,
        \\pub const display_name = "{s}";
        \\pub const module_name = "{s}";
        \\pub const relative_root = "{s}";
        \\pub const symbol_name = "{s}";
        \\
        \\extern fn {s}() callconv(.c) *const anyopaque;
        \\
        \\pub fn language() *const anyopaque {{
        \\    return {s}();
        \\}}
        \\
    ,
        .{
            grammar.display_name,
            grammar.module_name,
            grammar.rel_root,
            grammar.symbol,
            grammar.symbol,
            grammar.symbol,
        },
    );

    try appendQueryConst(b, &out, "highlights", grammar.queries.highlights);
    try appendQueryConst(b, &out, "injections", grammar.queries.injections);
    try appendQueryConst(b, &out, "locals", grammar.queries.locals);
    try appendQueryConst(b, &out, "folds", grammar.queries.folds);
    try appendQueryConst(b, &out, "tags", grammar.queries.tags);
    return out.toOwnedSlice(b.allocator);
}

/// Embed one query family as a Zig string constant, concatenating multiple
/// query files when a grammar composes them from several sources.
fn appendQueryConst(
    b: *std.Build,
    out: *std.ArrayList(u8),
    comptime query_name: []const u8,
    rel_paths: []const []const u8,
) !void {
    if (rel_paths.len == 0) {
        try out.print(b.allocator, "pub const {s}: ?[]const u8 = null;\n", .{query_name});
        return;
    }

    try out.print(b.allocator, "pub const {s}: ?[]const u8 = ", .{query_name});
    try out.append(b.allocator, '"');
    for (rel_paths, 0..) |rel_path, index| {
        const full_rel = b.pathJoin(&.{ "vendor", rel_path });
        const query = try b.build_root.handle.readFileAlloc(
            b.graph.io,
            full_rel,
            b.allocator,
            .limited(1024 * 1024),
        );
        try appendEscapedBytes(b.allocator, out, query);
        if (index + 1 != rel_paths.len and (query.len == 0 or query[query.len - 1] != '\n')) {
            try out.appendSlice(b.allocator, "\\n");
        }
    }
    try out.appendSlice(b.allocator, "\";\n");
}

/// Return true when a walked path is a grammar parser implementation root.
fn isParserPath(path: []const u8) bool {
    return std.mem.eql(u8, path, "src/parser.c") or std.mem.endsWith(u8, path, "/src/parser.c");
}

/// Convert `foo/bar/src/parser.c` into the grammar root path `foo/bar`.
fn grammarRelInRepo(parser_path: []const u8) ?[]const u8 {
    const src_dir = std.fs.path.dirname(parser_path) orelse return null;
    if (!std.mem.eql(u8, std.fs.path.basename(src_dir), "src")) return null;
    return std.fs.path.dirname(src_dir) orelse "";
}

/// Parse the generated parser C file to discover the exported
/// `tree_sitter_<lang>` symbol name.
fn extractLanguageSymbol(b: *std.Build, parser_rel: []const u8) ![]const u8 {
    const parser = try b.build_root.handle.readFileAlloc(
        b.graph.io,
        parser_rel,
        b.allocator,
        .limited(64 * 1024 * 1024),
    );

    const public_prefix = "TS_PUBLIC const TSLanguage *";
    if (std.mem.indexOf(u8, parser, public_prefix)) |prefix_index| {
        return parseSymbolFrom(parser[prefix_index + public_prefix.len ..], b.allocator);
    }

    const extern_prefix = "extern const TSLanguage *";
    if (std.mem.indexOf(u8, parser, extern_prefix)) |prefix_index| {
        return parseSymbolFrom(parser[prefix_index + extern_prefix.len ..], b.allocator);
    }

    return error.MissingLanguageSymbol;
}

/// Trim the function declaration prefix down to the raw exported symbol name.
fn parseSymbolFrom(source: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    const open_paren = std.mem.indexOfScalar(u8, source, '(') orelse return error.InvalidLanguageSymbol;
    return allocator.dupe(u8, std.mem.trim(u8, source[0..open_paren], " \t\r\n"));
}

/// Derive the public Zig module name from the repo name plus, when needed,
/// the leaf subgrammar name.
fn makeModuleName(b: *std.Build, repo_dir: []const u8, rel_in_repo: []const u8) ![]u8 {
    const repo_component = try normalizeModuleComponent(b, stripTreeSitterPrefix(repo_dir));
    defer b.allocator.free(repo_component);

    if (rel_in_repo.len == 0) {
        return std.fmt.allocPrint(b.allocator, "tree_sitter_{s}", .{repo_component});
    }

    const leaf_component = try normalizeModuleComponent(
        b,
        stripTreeSitterPrefix(std.fs.path.basename(rel_in_repo)),
    );
    defer b.allocator.free(leaf_component);

    if (std.mem.eql(u8, repo_component, leaf_component)) {
        return std.fmt.allocPrint(b.allocator, "tree_sitter_{s}", .{repo_component});
    }

    return std.fmt.allocPrint(b.allocator, "tree_sitter_{s}_{s}", .{ repo_component, leaf_component });
}

/// Convert an upstream repo or grammar slug into a safe snake_case module-name
/// component without punctuation.
fn normalizeModuleComponent(b: *std.Build, input: []const u8) ![]u8 {
    var out = std.ArrayList(u8).empty;
    var needs_separator = false;

    for (input) |byte| {
        switch (byte) {
            'a'...'z' => {
                if (needs_separator and out.items.len != 0 and out.items[out.items.len - 1] != '_') {
                    try out.append(b.allocator, '_');
                }
                needs_separator = false;
                try out.append(b.allocator, byte);
            },
            'A'...'Z' => {
                if (needs_separator and out.items.len != 0 and out.items[out.items.len - 1] != '_') {
                    try out.append(b.allocator, '_');
                }
                needs_separator = false;
                try out.append(b.allocator, std.ascii.toLower(byte));
            },
            '0'...'9' => {
                if (needs_separator and out.items.len != 0 and out.items[out.items.len - 1] != '_') {
                    try out.append(b.allocator, '_');
                }
                needs_separator = false;
                try out.append(b.allocator, byte);
            },
            else => needs_separator = true,
        }
    }

    if (out.items.len == 0) return error.InvalidModuleName;
    return out.toOwnedSlice(b.allocator);
}

/// Produce a human-facing grammar label when the metadata file does not supply
/// one explicitly.
fn defaultDisplayName(b: *std.Build, repo_dir: []const u8, rel_in_repo: []const u8) ![]const u8 {
    const slug = if (rel_in_repo.len != 0) std.fs.path.basename(rel_in_repo) else stripTreeSitterPrefix(repo_dir);
    return prettyDisplayNameFromSlug(b, slug);
}

/// Drop the standard `tree-sitter-` / `tree_sitter_` prefix before reusing a
/// repo or grammar slug for names and labels.
fn stripTreeSitterPrefix(repo_dir: []const u8) []const u8 {
    return if (std.mem.startsWith(u8, repo_dir, "tree-sitter-"))
        repo_dir["tree-sitter-".len..]
    else if (std.mem.startsWith(u8, repo_dir, "tree_sitter_"))
        repo_dir["tree_sitter_".len..]
    else
        repo_dir;
}

/// Turn a slug like `markdown-inline` into a readable display name.
fn prettyDisplayNameFromSlug(b: *std.Build, slug: []const u8) ![]const u8 {
    var out = std.ArrayList(u8).empty;
    var parts = std.mem.tokenizeAny(u8, slug, "-_");
    var first = true;
    while (parts.next()) |part| {
        if (!first) try out.append(b.allocator, ' ');
        first = false;

        if (part.len <= 4 and std.ascii.isLower(part[0])) {
            for (part) |byte| {
                try out.append(b.allocator, std.ascii.toUpper(byte));
            }
            continue;
        }

        try out.append(b.allocator, std.ascii.toUpper(part[0]));
        for (part[1..]) |byte| {
            try out.append(b.allocator, byte);
        }
    }
    return out.toOwnedSlice(b.allocator);
}

/// Cheap existence probe against the build root.
fn fileExists(b: *std.Build, rel_path: []const u8) bool {
    b.build_root.handle.access(b.graph.io, rel_path, .{}) catch return false;
    return true;
}

/// Emit one escaped Zig string literal into generated source.
fn appendZigStringLiteral(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    bytes: []const u8,
) !void {
    try out.append(allocator, '"');
    try appendEscapedBytes(allocator, out, bytes);
    try out.append(allocator, '"');
}

/// Escape arbitrary bytes so they can be embedded safely into generated Zig
/// source string literals.
fn appendEscapedBytes(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    bytes: []const u8,
) !void {
    for (bytes) |byte| {
        switch (byte) {
            '\\' => try out.appendSlice(allocator, "\\\\"),
            '"' => try out.appendSlice(allocator, "\\\""),
            '\n' => try out.appendSlice(allocator, "\\n"),
            '\r' => try out.appendSlice(allocator, "\\r"),
            '\t' => try out.appendSlice(allocator, "\\t"),
            else => {
                if (byte >= 0x20 and byte <= 0x7e) {
                    try out.append(allocator, byte);
                } else {
                    try out.print(allocator, "\\x{X:0>2}", .{byte});
                }
            },
        }
    }
}
