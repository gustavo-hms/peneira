local fzy = require "fzy"

-- Table for exported symbols
local pub = {}

-- Merge the data given by fzy.filter at each step with the accumulated
-- value of previous steps.
--
-- The first argument is a table containing the filtered lines up to the
-- current iteration and the accumulated information of previous calls
-- to fzy.filter:
--
--     {
--         lines = { line... },
--         matches = { line_number, { match_position... }, score }
--     }
--
-- The second argument is a table containing the data returned by fzy.filter
-- at the current iteration:
--
--     {
--         matches = { line_number, { match_position... }, score }
--     }
--
local function accumulate(accumulated, data)
    local lines = {}

    for i, item in ipairs(data.matches) do
        -- Keep only filtered lines
        local line_number = item[1]
        lines[i] = accumulated.lines[line_number]
        -- Reference the line number of the filtered table, not the original one
        item[1] = i

        if accumulated.matches then
            local accum = accumulated.matches[line_number]
            -- Concatenate table of positions
            item[2] = table.move(item[2], 1, #item[2], #accum[2] + 1, accum[2])
            -- Sum scores
            item[3] = item[3] + accum[3]
        end
    end

    data.lines = lines
    return data
end

-- We are going to filter the candidates based on the text inserted on
-- the prompt. The text is split in words, and each word is used to refine
-- the filter performed using previous words. Each pass does the following
-- steps:
--
--   1. filter lines that match the word;
--   2. for each filtered line, compute its score as an integer based on
--      fzy algorithm (higher is better);
--   3. add such score to the accumulated value of previous iterations;
--   4. for each filtered line, compute the positions of the matches as a table
--      of indices;
--   5. concatenate that table of indices with the accumulated table of
--      previous iterations.
--
-- Steps 1, 2 and 4 are done all at once by the fzy.filter function. It
-- returns a table with the following structure:
--
--     { line_number, { match_position... }, score }
--
-- Steps 3 and 5 are done by the accumulate function.
function pub.filter(filename, prompt, rank)
    local file = io.open(filename, 'r')

    if not file then
        kak.fail("couldn't open temporary file " .. filename)
        return
    end

    local lines = {}

    for line in file:lines() do
        lines[#lines + 1] = line
    end

    local data = { lines = lines }

    for word in prompt:gmatch("%S+") do
        local matches = fzy.filter(word, data.lines)
        data = accumulate(data, { matches = matches })
    end

    local highest_score = { 1, {}, fzy.get_score_min() }

    if rank then
        table.sort(data.matches, function(a, b)
            -- Sort based on the scores. Higher is better.
            return a[3] > b[3]
        end)
    else
        for _, match in ipairs(data.matches) do
            if match[3] > highest_score[3] then
                highest_score = match
            end
        end
    end

    local positions = {}
    local filtered = {}

    for i, item in ipairs(data.matches) do
        positions[i] = item[2]
        filtered[i] = data.lines[item[1]]
    end

    return filtered, positions, highest_score[1]
end

function pub.range_specs(positions)
    local specs = {}

    for line, chars in ipairs(positions) do
        if line > 200 then break end -- Unlikely that more than 200 lines can be seen

        for _, char in ipairs(chars) do
            specs[#specs + 1] = string.format("%d.%d,%d.%d|@PeneiraMatches", line, char, line, char)
        end
    end

    return specs
end

-- Functions to manipulate ctags data

function pub.read_tags(file)
    local command = string.format("ctags --output-format=json --fields=+n --sort=no -f - '%s'", file)
    local ctags = io.popen(command)
    return ctags and ctags:read('a')
end

function pub.parse_json(json)
    -- Convert JSON objects to lua tables
    data = json:gsub('([{,]%s*)("[^"]-"):', '%1[%2]='):gsub("\n", ", ")
    local chunk = string.format("return {%s}", data)
    return load(chunk)()
end

-- A scope tree --
------------------

-- We are going to build a tree of scopes from the data fetched from
-- ctags. Each tag is potentially also a new scope. The structure of a
-- scope is:
--
--     {
--         tag...
--
--         parent           = _parent scope_,
--         ordered_children = _ordered (as in the file) table of children_,
--         children         = _children table keyed by kind and then name_,
--         scope_path       = _ordered table of scopes, from the parents to
--                             the current one_
--     }


local function add_to_scope(tag, scope)
    scope.ordered_children[#scope.ordered_children + 1] = tag

    local kind = scope.children[tag.kind] or {}
    kind[tag.name] = tag
    scope.children[tag.kind] = kind

    return scope
end

string.split = function(s, separator)
    local segments = {}
    local start = 1

    repeat
        local first, last = s:find(separator, start)

        if not first then
            first, last = #s + 1, #s + 1
        end

        segments[#segments + 1] = s:sub(start, first - 1)
        start = last + 1
    until start > #s

    return segments
end

local function path_from_scope_field(tag)
    if not tag.scope then return {} end

    -- Some filetypes (e.g. markup languages for documentation) use `""`
    -- as a scope separator since they can have any of `:`, `.` and `/`
    -- on their headings.
    --
    -- To avoid interpreting those characters as scopes separators (risking
    -- entering an infinite recursion), we will make the assumption that
    -- any scope name containing spaces is using `""` as a separator.
    if tag.scope:find([[""]]) or tag.scope:find("%s") then
        return tag.scope:split([[""]])
    end

    return tag.scope:split("[:./]")
end

-- Every tag can potentially define a new scope
local function new_scope_from_tag(tag, parent)
    tag.children = {}
    tag.ordered_children = {}
    tag.parent = parent
    tag.scope_path = path_from_scope_field(tag)
    tag.scope_path[#tag.scope_path + 1] = tag.name

    return tag
end

-- Sometimes a scope is referenced but doesn't have an associated tag in
-- the source file. So we create a dummy tag to represent the referenced scope.
local function new_scope(name, kind, index, parent)
    local scope_path = table.move(parent.scope_path, 1, #parent.scope_path, 1, {})
    scope_path[#scope_path + 1] = name

    local tag = {
        name = name,
        kind = kind,
        index = index,
        parent = parent,
        children = {},
        ordered_children = {},
        scope_path = scope_path,
    }

    add_to_scope(tag, parent)
    return tag
end

local function is_scope(tag)
    return tag.children
end

local function find_parent(tags, index, scope)
    if not scope then return nil end

    local tag = tags[index]

    if tag.scopeKind == scope.kind then return scope end

    for i = index, 1, -1 do
        local previous = tags[i]

        if previous and tag.scopeKind == previous.kind then
            if is_scope(previous) then return previous end
            return new_scope_from_tag(previous, scope)
        end
    end
end

local function scope_path(tags, index, scope)
    local tag = tags[index]

    if not tag.scope then
        -- Ctags can't properly handle scopes from tags whose names have
        -- spaces (like headings on an asciidoc file). If the tag doesn't
        -- have a `scope` field but does have a `scopeKind` field (in which
        -- case it does belong to some scope), we probably are dealing with
        -- this ctags limitation. So we look for a parent scope with the
        -- same kind as `scopeKind`.
        if tag.scopeKind then
            local parent = find_parent(tags, index, scope)
            if not parent then return {} end
            tag.scope = table.concat(parent.scope_path, [[""]])

            return parent.scope_path
        end

        return {}
    end

    return path_from_scope_field(tag)
end

local function find_tag(name, scope)
    for i = #scope.ordered_children, 1, -1 do
        local tag = scope.ordered_children[i]
        if tag.name == name then return tag end
    end
end

local function subscope(name, kind, index, scope)
    local tag
    local scope_kind = scope.children[kind]

    if scope_kind then
        tag = scope_kind[name]
    else
        tag = find_tag(name, scope)
    end

    if not tag then
        tag = new_scope(name, kind, index, scope)
    end

    if is_scope(tag) then return tag end

    return new_scope_from_tag(tag, scope)
end

local function same_scope(path1, path2)
    if #path1 ~= #path2 then return false end

    for i in ipairs(path1) do
        if path1[i] ~= path2[i] then return false end
    end

    return true
end

local function add_tag_to_scope(tags, index, scope)
    if index > #tags then return end

    local tag = tags[index]

    if tag.name:sub(1, 6) == "__anon" then
        -- Ignore anonymous fields
        return add_tag_to_scope(tags, index + 1, scope)
    end

    tag.index = index
    local tag_scope_path = scope_path(tags, index, scope)

    if #tag_scope_path < #scope.scope_path then
        return add_tag_to_scope(tags, index, scope.parent)
    end

    if #tag_scope_path > #scope.scope_path then
        local name = tag_scope_path[#scope.scope_path + 1]
        return add_tag_to_scope(tags, index, subscope(name, tag.scopeKind, index, scope))
    end

    -- At this point, we guarantee we are at a scope with the same level as
    -- the scope the tag belongs to.

    if same_scope(tag_scope_path, scope.scope_path) then
        add_to_scope(tag, scope)
        return add_tag_to_scope(tags, index + 1, scope)
    end

    -- If the current scope is not the scope the tag belongs to, search for
    -- a sibling scope.
    return add_tag_to_scope(tags, index, scope.parent)
end

local function build_tree(tags)
    local toplevel = { children = {}, ordered_children = {}, scope_path = {} }
    add_tag_to_scope(tags, 1, toplevel)
    return toplevel
end

local function display_tag(tag, scope_level)
    local indent = string.rep(" ", 4 * scope_level)
    local type = tag.typeref and " : " .. tag.typeref:sub(10) or ""
    local scope = tag.scope and string.format(" (%s)", tag.scope) or ""
    return string.format("%s%s %s%s%s %d", indent, tag.name, tag.kind, type, scope, tag.index)
end

local function display_tree(tree, scope_level, lines)
    if not tree.ordered_children then return {} end

    scope_level = scope_level or 0
    local lines = lines or {}

    for i, tag in ipairs(tree.ordered_children) do
        local previous = tree.ordered_children[i - 1]

        -- Visually group each scope.
        if previous and (previous.ordered_children or tag.ordered_children) then
            lines[#lines + 1] = ""
        end

        local line = display_tag(tag, scope_level)
        lines[#lines + 1] = line
        display_tree(tag, scope_level + 1, lines)
    end

    return lines
end

function pub.display_symbol_tree(tags)
    local tree = build_tree(tags)
    local output = display_tree(tree)
    return table.concat(output, "\n")
end

return pub
