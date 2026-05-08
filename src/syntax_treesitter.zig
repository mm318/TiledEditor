const dvui = @import("dvui");
const tree_sitter_language_pack = @import("tree_sitter_language_pack");

const palette = @import("app_core.zig").palette;

const syntax_highlights: []const dvui.TextEntryWidget.SyntaxHighlight = &.{
    .{ .name = "comment", .opts = .{ .color_text = palette.syntax_comment } },
    .{ .name = "comment.documentation", .opts = .{ .color_text = palette.syntax_comment } },
    .{ .name = "string", .opts = .{ .color_text = palette.syntax_string } },
    .{ .name = "text.literal", .opts = .{ .color_text = palette.syntax_code } },
    .{ .name = "string.escape", .opts = .{ .color_text = palette.primary_dim } },
    .{ .name = "character", .opts = .{ .color_text = palette.syntax_string } },
    .{ .name = "number", .opts = .{ .color_text = palette.syntax_number } },
    .{ .name = "boolean", .opts = .{ .color_text = palette.syntax_builtin } },
    .{ .name = "constant", .opts = .{ .color_text = palette.syntax_number } },
    .{ .name = "constant.builtin", .opts = .{ .color_text = palette.syntax_builtin } },
    .{ .name = "constant.macro", .opts = .{ .color_text = palette.syntax_preproc } },
    .{ .name = "type.builtin", .opts = .{ .color_text = palette.syntax_builtin } },
    .{ .name = "type.qualifier", .opts = .{ .color_text = palette.syntax_builtin } },
    .{ .name = "variable.builtin", .opts = .{ .color_text = palette.syntax_builtin } },
    .{ .name = "function.builtin", .opts = .{ .color_text = palette.syntax_builtin } },
    .{ .name = "keyword", .opts = .{ .color_text = palette.syntax_keyword } },
    .{ .name = "keyword.conditional", .opts = .{ .color_text = palette.syntax_keyword } },
    .{ .name = "keyword.function", .opts = .{ .color_text = palette.syntax_keyword } },
    .{ .name = "keyword.import", .opts = .{ .color_text = palette.syntax_preproc } },
    .{ .name = "keyword.operator", .opts = .{ .color_text = palette.syntax_keyword } },
    .{ .name = "keyword.repeat", .opts = .{ .color_text = palette.syntax_keyword } },
    .{ .name = "keyword.return", .opts = .{ .color_text = palette.syntax_keyword } },
    .{ .name = "keyword.type", .opts = .{ .color_text = palette.syntax_type } },
    .{ .name = "type", .opts = .{ .color_text = palette.syntax_type } },
    .{ .name = "type.definition", .opts = .{ .color_text = palette.syntax_type } },
    .{ .name = "include", .opts = .{ .color_text = palette.syntax_preproc } },
    .{ .name = "label", .opts = .{ .color_text = palette.syntax_link } },
    .{ .name = "module", .opts = .{ .color_text = palette.syntax_link } },
    .{ .name = "module.builtin", .opts = .{ .color_text = palette.syntax_builtin } },
    .{ .name = "namespace", .opts = .{ .color_text = palette.syntax_link } },
    .{ .name = "function.macro", .opts = .{ .color_text = palette.syntax_preproc } },
    .{ .name = "function.call", .opts = .{ .color_text = palette.primary } },
    .{ .name = "function", .opts = .{ .color_text = palette.primary_dim } },
    .{ .name = "function.method", .opts = .{ .color_text = palette.primary } },
    .{ .name = "function.special", .opts = .{ .color_text = palette.syntax_preproc } },
    .{ .name = "field", .opts = .{ .color_text = palette.syntax_property } },
    .{ .name = "parameter", .opts = .{ .color_text = palette.success } },
    .{ .name = "variable.parameter", .opts = .{ .color_text = palette.success } },
    .{ .name = "variable.member", .opts = .{ .color_text = palette.syntax_property } },
    .{ .name = "property", .opts = .{ .color_text = palette.syntax_property } },
    .{ .name = "attribute", .opts = .{ .color_text = palette.syntax_property } },
    .{ .name = "exception", .opts = .{ .color_text = palette.syntax_preproc } },
    .{ .name = "delimiter", .opts = .{ .color_text = palette.text_dim } },
    .{ .name = "operator", .opts = .{ .color_text = palette.text_dim } },
    .{ .name = "punctuation", .opts = .{ .color_text = palette.text_dim } },
    .{ .name = "punctuation.delimiter", .opts = .{ .color_text = palette.text_dim } },
    .{ .name = "punctuation.bracket", .opts = .{ .color_text = palette.text_dim } },
    .{ .name = "punctuation.special", .opts = .{ .color_text = palette.primary_dim } },
    .{ .name = "tag", .opts = .{ .color_text = palette.syntax_keyword } },
    .{ .name = "tag.attribute", .opts = .{ .color_text = palette.syntax_property } },
    .{ .name = "markup.heading", .opts = .{ .color_text = palette.syntax_heading } },
    .{ .name = "markup.quote", .opts = .{ .color_text = palette.syntax_quote } },
    .{ .name = "markup.raw", .opts = .{ .color_text = palette.syntax_code } },
    .{ .name = "markup.link", .opts = .{ .color_text = palette.syntax_link } },
    .{ .name = "markup.list", .opts = .{ .color_text = palette.syntax_keyword } },
    .{ .name = "text.title", .opts = .{ .color_text = palette.syntax_heading } },
    .{ .name = "text.reference", .opts = .{ .color_text = palette.syntax_link } },
    .{ .name = "text.uri", .opts = .{ .color_text = palette.syntax_link } },
    .{ .name = "text.emphasis", .opts = .{ .color_text = palette.syntax_heading } },
    .{ .name = "preproc", .opts = .{ .color_text = palette.syntax_preproc } },
};

pub fn displayNameForPath(path: []const u8) ?[]const u8 {
    return tree_sitter_language_pack.displayNameForPath(path);
}

pub fn textEntryTreeSitter(path: []const u8) ?dvui.TextEntryWidget.InitOptions.TreeSitterOption {
    if (!dvui.useTreeSitter) return null;
    const grammar = tree_sitter_language_pack.lookup(path) orelse return null;
    const queries = grammar.highlights orelse return null;

    return .{
        .language = @ptrCast(@constCast(grammar.language)),
        .queries = queries,
        .highlights = syntax_highlights,
    };
}
