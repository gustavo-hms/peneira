-- This executable is an auxiliary tool for peneira-symbols and peneira-lines.
--
-- For peneira-symbols, it builds a tree of tags from ctags output to print
-- it to stdout.
--
-- For peneira-lines, it prefixes each line from the temp file with its
-- number, padding them as necessary.

local peneira = require 'peneira'

-- When this file is invoked with a subcommand, the global function
-- corresponding to that subcommand will be executed. E.g.:
--
--    filters symbols filename
--
-- will call the `symbols` function passing `filename` as its argument.


-- Print symbols --
-------------------

function symbols(filename)
    local json = peneira.read_tags(filename)
    local tags = peneira.parse_json(json)
    print(peneira.display_symbol_tree(tags))
end

-- Number lines --
------------------

function lines(filename)
    local file = io.open(filename, 'r')
    if not file then return end

    local lines = {}

    for line in file:lines() do
        lines[#lines + 1] = line
    end

    -- We are going to compute the padding needed for displaying
    -- the line numbers.
    local log = math.log10 or function(x) return math.log(x, 10) end
    local number_of_digits = math.floor(log(#lines)) + 1
    -- The format will become "%{#digits}d %s", where {#digits}
    -- is the number of digits in the biggest line number
    local format = string.format("%%%dd %%s", number_of_digits)

    for i, line in ipairs(lines) do
        print(string.format(format, i, line))
    end
end

local command = table.remove(arg, 1)
local unpack = unpack or table.unpack
_G[command](unpack(arg))
