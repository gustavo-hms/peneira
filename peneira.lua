local fzy = require "fzy"

local function filter(filename, prompt)
    local file = io.open(filename, 'r')

    if not file then
        kak.echo("-debug", "peneira: couldn't open temporary file " .. filename)
        return nil
    end

    -- Treat each word in prompt as a new, refined, search
    local prompt_words = {}

    for word in prompt:gmatch("%S+") do
        prompt_words[#prompt_words + 1] = word
    end

    local lines = {}

    for line in file:lines() do
	    lines[#lines + 1] = line
    end

    local info = fzy.filter(prompt, lines) -- TODO múltiplas palavras

	table.sort(info, function(a, b)
		return a[3] > b[3]
	end)

	local filtered = {}
	local positions = {}

	for i, item in ipairs(info) do
		filtered[i] = lines[item[1]]
		positions[i] = item[2]
	end

	return filtered, positions
end

local function range_specs(positions)
	local specs = {}

	for line, chars in ipairs(positions) do
		if line > 200 then break end -- Unlikely that more than 200 lines can be seen

		for _, char in ipairs(chars) do
	        specs[#specs + 1] = string.format("%d.%d,%d.%d|@PeneiraMatches", line, char, line, char)
		end
	end

	return specs
end

return {
	filter = filter,
	range_specs = range_specs,
}
