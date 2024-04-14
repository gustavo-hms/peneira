local peneira = require "peneira"

describe("The #display_symbol_tree", function()
    it("should generate symbols for a table of tags", function()
        local tags = {
            {
                _type = "tag",
                name = "add_to_scope",
                path = "filters.lua",
                pattern = "/^local function add_to_scope(tag, scope)$/",
                line = 29,
                kind = "function"
            },
            {
                _type = "tag",
                name = "split",
                path = "filters.lua",
                pattern = "/^string.split = function(s, separator)$/",
                line = 39,
                kind = "function",
                scope = "string",
                scopeKind = "unknown"
            },
            {
                _type = "tag",
                name = "path_from_scope_field",
                path = "filters.lua",
                pattern = "/^local function path_from_scope_field(tag)$/",
                line = 57,
                kind = "function"
            },
            {
                _type = "tag",
                name = "new_scope_from_tag",
                path = "filters.lua",
                pattern = "/^local function new_scope_from_tag(tag, parent)$/",
                line = 75,
                kind = "function"
            },
            {
                _type = "tag",
                name = "new_scope",
                path = "filters.lua",
                pattern = "/^local function new_scope(name, kind, index, parent)$/",
                line = 87,
                kind = "function"
            },
            {
                _type = "tag",
                name = "is_scope",
                path = "filters.lua",
                pattern = "/^local function is_scope(tag)$/",
                line = 105,
                kind = "function"
            },
            {
                _type = "tag",
                name = "find_parent",
                path = "filters.lua",
                pattern = "/^local function find_parent(tags, index, scope)$/",
                line = 109,
                kind = "function"
            },
            {
                _type = "tag",
                name = "scope_path",
                path = "filters.lua",
                pattern = "/^local function scope_path(tags, index, scope)$/",
                line = 126,
                kind = "function"
            },
            {
                _type = "tag",
                name = "find_tag",
                path = "filters.lua",
                pattern = "/^local function find_tag(name, scope)$/",
                line = 150,
                kind = "function"
            },
            {
                _type = "tag",
                name = "subscope",
                path = "filters.lua",
                pattern = "/^local function subscope(name, kind, index, scope)$/",
                line = 157,
                kind = "function"
            },
            {
                _type = "tag",
                name = "same_scope",
                path = "filters.lua",
                pattern = "/^local function same_scope(path1, path2)$/",
                line = 177,
                kind = "function"
            },
            {
                _type = "tag",
                name = "add_tag_to_scope",
                path = "filters.lua",
                pattern = "/^local function add_tag_to_scope(tags, index, scope)$/",
                line = 187,
                kind = "function"
            },
            {
                _type = "tag",
                name = "build_tree",
                path = "filters.lua",
                pattern = "/^local function build_tree(tags)$/",
                line = 222,
                kind = "function"
            },
            {
                _type = "tag",
                name = "print_tag",
                path = "filters.lua",
                pattern = "/^local function print_tag(tag, scope_level)$/",
                line = 228,
                kind = "function"
            },
            {
                _type = "tag",
                name = "print_tree",
                path = "filters.lua",
                pattern = "/^local function print_tree(tree, scope_level)$/",
                line = 236,
                kind = "function"
            },
            {
                _type = "tag",
                name = "symbols",
                path = "filters.lua",
                pattern = "/^function symbols(filename)$/",
                line = 265,
                kind = "function"
            },
            {
                _type = "tag",
                name = "lines",
                path = "filters.lua",
                pattern = "/^function lines(filename)$/",
                line = 274,
                kind = "function"
            },
            {
                _type = "tag",
                name = "log",
                path = "filters.lua",
                pattern = "/^    local log = math.log10 or function(x) return math.log(x, 10) end$/",
                line = 286,
                kind = "function"
            },
        }

        local output = peneira.display_symbol_tree(tags)
        local expected = [[
add_to_scope function 1

string unknown 2
    split function (string) 2

path_from_scope_field function 3
new_scope_from_tag function 4
new_scope function 5
is_scope function 6
find_parent function 7
scope_path function 8
find_tag function 9
subscope function 10
same_scope function 11
add_tag_to_scope function 12
build_tree function 13
print_tag function 14
print_tree function 15
symbols function 16
lines function 17
log function 18]]

        assert.are.equal(expected, output)
    end)

    it("should generate symbols for an asciidoc file", function()
        local tags = {
            {
                _type = "tag",
                name = "Peneira",
                path = "peneira.asciidoc",
                pattern = "/^= Peneira$/",
                line = 1,
                kind = "chapter"
            },
            {
                _type = "tag",
                name = "Writting your own filter",
                path = "peneira.asciidoc",
                pattern = "/^== Writting your own filter$/",
                line = 15,
                kind = "section",
                scope = "Peneira",
                scopeKind = "chapter"
            },
            {
                _type = "tag",
                name = "Built-in filters",
                path = "peneira.asciidoc",
                pattern = "/^== Built-in filters$/",
                line = 47,
                kind = "section",
                scope = "Peneira",
                scopeKind = "chapter"
            },
            {
                _type = "tag",
                name = "peneira-symbols",
                path = "peneira.asciidoc",
                pattern = "/^=== peneira-symbols$/",
                line = 51,
                kind = "subsection",
                scope = "Built-in filters",
                scopeKind = "section"
            },
            {
                _type = "tag",
                name = "peneira-lines",
                path = "peneira.asciidoc",
                pattern = "/^=== peneira-lines$/",
                line = 57,
                kind = "subsection",
                scope = "Built-in filters",
                scopeKind = "section"
            },
            {
                _type = "tag",
                name = "peneira-files",
                path = "peneira.asciidoc",
                pattern = "/^=== peneira-files$/",
                line = 62,
                kind = "subsection",
                scope = "Built-in filters",
                scopeKind = "section"
            },
            {
                _type = "tag",
                name = "peneira-local-files",
                path = "peneira.asciidoc",
                pattern = "/^=== peneira-local-files$/",
                line = 82,
                kind = "subsection",
                scope = "Built-in filters",
                scopeKind = "section"
            },
            {
                _type = "tag",
                name = "peneira-mru",
                path = "peneira.asciidoc",
                pattern = "/^=== peneira-mru$/",
                line = 87,
                kind = "subsection",
                scope = "Built-in filters",
                scopeKind = "section"
            },
            {
                _type = "tag",
                name = "Performance tips",
                path = "peneira.asciidoc",
                pattern = "/^== Performance tips$/",
                line = 101,
                kind = "section",
                scope = "Peneira",
                scopeKind = "chapter"
            },
            {
                _type = "tag",
                name = "Customization",
                path = "peneira.asciidoc",
                pattern = "/^== Customization$/",
                line = 111,
                kind = "section",
                scope = "Peneira",
                scopeKind = "chapter"
            },
            {
                _type = "tag",
                name = "Caveats",
                path = "peneira.asciidoc",
                pattern = "/^== Caveats$/",
                line = 128,
                kind = "section",
                scope = "Peneira",
                scopeKind = "chapter"
            },
        }

        local output = peneira.display_symbol_tree(tags)
        local expected = [[
Peneira chapter 1
    Writting your own filter section (Peneira) 2
    Built-in filters section (Peneira) 3
    Performance tips section (Peneira) 9
    Customization section (Peneira) 10
    Caveats section (Peneira) 11

Built-in filters section 4
    peneira-symbols subsection (Built-in filters) 4
    peneira-lines subsection (Built-in filters) 5
    peneira-files subsection (Built-in filters) 6
    peneira-local-files subsection (Built-in filters) 7
    peneira-mru subsection (Built-in filters) 8]]

        assert.are.equal(expected, output)
    end)
end)

describe("The conversion from #json", function()
    it("should generate a table for a python function whose return type is a string", function()
        local json = [[
            {"_type": "tag", "name": "from_file", "path": "file.py", "pattern": "/^    def from_file(file_name: str) -> \"Name\":$/", "line": 72, "typeref": "typename:\"Name\"", "kind": "member", "scope": "Name", "scopeKind": "class"}
        ]]

        local expected = {
            {
                _type = "tag",
                name = "from_file",
                path = "file.py",
                pattern = "/^    def from_file(file_name: str) -> \"Name\":$/",
                line = 72,
                typeref = "typename:\"Name\"",
                kind = "member",
                scope = "Name",
                scopeKind = "class",
            }
        }

        local result = peneira.parse_json(json)
        assert.are.same(expected, result)
    end)
end)
