declare-option -hidden str peneira_path %sh{ dirname $kak_source }
declare-option -hidden str peneira_selected_line 1
declare-option -hidden range-specs peneira_matches

set-face global PeneiraSelected default,rgba:44444444
set-face global PeneiraMatches value

define-command peneira-filter -params 3 -docstring %{
    peneira-filter <prompt> <candidates> <cmd>: filter <candidates> and then run <cmd> with its first argument set to the selected candidate.
} %{
    edit -scratch *peneira*
    peneira-configure-buffer

    execute-keys "%%c%arg{2}<esc>gg"

    prompt -on-change %{
        evaluate-commands -buffer *peneira* %{
            peneira-replace-buffer "%val{text}" "%arg{2}"
            add-highlighter -override buffer/peneira-matches ranges peneira_matches
        }

        execute-keys "<a-;>%opt{peneira_selected_line}g"

    } -on-abort %{
        delete-buffer *peneira*

    } %arg{1} %{
        evaluate-commands -save-regs ac %{
            execute-keys -buffer *peneira* %opt{peneira_selected_line}gx_\"ay
            set-register c "%arg{3}"
            peneira-call "%reg{a}"
        }

        delete-buffer *peneira*
    }
}

define-command -hidden peneira-configure-buffer %{
	remove-highlighter window/number-lines
	add-highlighter window/current-line line %opt{peneira_selected_line} PeneiraSelected
	face window PrimaryCursor @PeneiraSelected
	map buffer prompt <down> "<a-;>: peneira-select-next-line<ret>"
	map buffer prompt <tab> "<a-;>: peneira-select-next-line<ret>"
	map buffer prompt <up> "<a-;>: peneira-select-previous-line<ret>"
	map buffer prompt <s-tab> "<a-;>: peneira-select-previous-line<ret>"
}

define-command -hidden peneira-select-previous-line %{
    lua %opt{peneira_selected_line} %val{buf_line_count} %{
        local selected, line_count = args()
        selected = selected > 1 and selected - 1 or line_count
        kak.set_option("buffer", "peneira_selected_line", selected)
    	kak.add_highlighter("-override", "window/current-line", "line", selected, "PeneiraSelected")
    }
}

define-command -hidden peneira-select-next-line %{
    lua %opt{peneira_selected_line} %val{buf_line_count} %{
        local selected, line_count = args()
        selected = selected % line_count + 1
        kak.set_option("buffer", "peneira_selected_line", selected)
    	kak.add_highlighter("-override", "window/current-line", "line", selected, "PeneiraSelected")
    }
}

# arg1: prompt text
# arg2: candidates
define-command -hidden peneira-replace-buffer -params 2 %{
    lua %opt{peneira_path} %arg{@} %{
        local peneira_path, prompt, candidates = args()

        if #prompt == 0 then
    		kak.execute_keys(string.format("%%c%s<esc>", candidates))
    		return
		end

        -- Add plugin path to the list of path to be searched by `require`
        package.path = string.format("%s/?.lua;%s", peneira_path, package.path)
        local fzy = require "fzy"

        local filtered = {}
        local score_cache = {}

        -- Treat each word in prompt as a new, refined, search
        local prompt_words = {}

        for word in prompt:gmatch("%S+") do
            prompt_words[#prompt_words + 1] = word
        end

        for candidate in candidates:gmatch("[^\n]+") do
        	if fzy.has_match(prompt_words[1], candidate) then
        		filtered[#filtered + 1] = candidate
                score_cache[candidate] = fzy.score(prompt_words[1], candidate)
    		end
		end

		-- Filter again, now using the other words
		for i = 2, #prompt_words do
		    local refined = {}

		    for _, candidate in ipairs(filtered) do
            	if fzy.has_match(prompt_words[i], candidate) then
            	    refined[#refined + 1] = candidate
                    score_cache[candidate] = score_cache[candidate] + fzy.score(prompt_words[i], candidate)
            	end
            end

            filtered = refined
        end

		table.sort(filtered, function(a, b)
            return score_cache[a] > score_cache[b]
		end)

        local contents = table.concat(filtered, "\n")
		kak.execute_keys(string.format("%%c%s<esc>", contents))
		kak.peneira_highlight_matches(prompt, contents)
	}
}

# arg1: prompt text
# arg2: candidates
define-command -hidden peneira-highlight-matches -params 2 %{
	lua %opt{peneira_path} %val{timestamp} %arg{@} %{
		local peneira_path, timestamp, prompt, lines = args()

		if #prompt == 0 then
		    return
	    end

        -- Add plugin path to the list of path to be searched by `require`
        package.path = string.format("%s/?.lua;%s", peneira_path, package.path)
        local fzy = require "fzy"

		local descriptors = {}
		local line_number = 0

		for line in lines:gmatch("[^\n]+") do
		    line_number = line_number + 1

		    if line_number > 50 then
		        break
		    end

            for word in prompt:gmatch("%S+") do
                local positions = fzy.positions(word, line)

    		    for _, position in pairs(positions) do
    		        descriptors[#descriptors + 1] = string.format("%d.%d,%d.%d|@PeneiraMatches", line_number, position, line_number, position)
    		    end
            end
        end

        kak.set_option("buffer", "peneira_matches", timestamp, unpack(descriptors))
	}
}

# Calls the command stored in the c register. This way, that command can use the
# argument passed to peneira-call as if it was an argument passed to it.
define-command -hidden peneira-call -params 1 %{
    evaluate-commands "%reg{c}"
}

define-command peneira-files -docstring %{
    peneira-files: select a file in the current directory tree
} %{
    peneira-filter 'files: ' %sh{ fd } %{
        edit %arg{1}
    }
}
