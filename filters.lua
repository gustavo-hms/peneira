local peneira = require 'peneira'

local function split_scopes(scope)
    local scopes = {}

    if not scope then return scopes end

    for s in scope:gmatch("[^:./]+") do
        scopes[#scopes + 1] = s
    end

    return scopes
end

local function new_scope(tag, parent)
    tag.symbols = {}
    tag.order = {}
    tag.parent = parent
    tag.scope_path = split_scopes(tag.scope)
    tag.scope_path[#tag.scope_path + 1] = tag.name

    return tag
end

local function add_to_scope(tag, scope)
    scope.order[#scope.order + 1] = tag

    local kind = scope.symbols[tag.kind] or {}
    kind[tag.name] = tag
    scope.symbols[tag.kind] = kind

    return scope
end

local function subscope(tag, scope)
    local scope_tag = scope.symbols[tag.scopeKind][tag.scope]
    return new_scope(scope_tag, scope)
end

local function add_tag_to_scope(tags, index, scope)
    if index > #tags then return scope end

    local tag = tags[index]
    local scope_path = split_scopes(tag.scope)

    if #scope_path > #scope.scope_path then
        scope = subscope(tag, scope)

    elseif #scope_path < #scope.scope_path then
        scope = scope.parent
    end

    add_to_scope(tag, scope)
    return add_tag_to_scope(tags, index + 1, scope)
end

local function build_tree(tags)
    local toplevel = { symbols = {}, order = {}, scope_path = {} }
    return add_tag_to_scope(tags, 1, toplevel)
end

local function print_tag(tag, scope_level)
    local indent = string.rep(" ", 4 * scope_level)
    local info = string.format("%s%s %s", indent, tag.name, tag.kind)
    print(info)
end

local function print_tree(tree, scope_level)
    if not tree.order then return end

    scope_level = scope_level or 0

    for _, tag in ipairs(tree.order) do
        print_tag(tag, scope_level)
        print_tree(tag, scope_level + 1)
    end
end

function tags(file)
    local tags = peneira.read_tags(file)
    local tree = build_tree(tags)
    print_tree(tree)
end

local command = table.remove(arg, 1)
local unpack = unpack or table.unpack
_G[command](unpack(arg))
