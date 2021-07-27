declare-option -hidden str peneira_path %sh{ dirname $kak_source }
declare-option -hidden int peneira_selected_line 1
declare-option -hidden range-specs peneira_matches
declare-option -hidden str peneira_previous_prompt
declare-option -hidden str peneira_temp_file

set-face global PeneiraSelected default,rgba:44444422
set-face global PeneiraMatches value

define-command peneira-filter -params 3 -docstring %{
    peneira-filter <prompt> <candidates> <cmd>: filter <candidates> and then run <cmd> with its first argument set to the selected candidate.
} %{
    edit -scratch *peneira*
    peneira-configure-buffer
    set-option buffer peneira_temp_file %sh{ mktemp }
    execute-keys "%%c%arg{2}<esc>gg: write %opt{peneira_temp_file}<ret>"

    prompt -on-change %{
        evaluate-commands -buffer *peneira* %{
            execute-keys ": write %opt{peneira_temp_file}<ret>"
            peneira-replace-buffer "%val{text}"
        }

        set-option buffer peneira_previous_prompt "%val{text}"
        execute-keys "<a-;>%opt{peneira_selected_line}g"

    } -on-abort %{
        nop %sh{ rm $kak_opt_peneira_temp_file }
        delete-buffer *peneira*

    } %arg{1} %{
        evaluate-commands -save-regs ac %{
            execute-keys -buffer *peneira* %opt{peneira_selected_line}gx_\"ay
            set-register c "%arg{3}"
            peneira-call "%reg{a}"
        }

        evaluate-commands -buffer *peneira* %{
            nop %sh{ rm $kak_opt_peneira_temp_file }
        }

        delete-buffer *peneira*
    }
}

define-command -hidden peneira-configure-buffer %{
	remove-highlighter window/number-lines
	add-highlighter window/current-line line %opt{peneira_selected_line} PeneiraSelected
    add-highlighter window/peneira-matches ranges peneira_matches
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

# arg: prompt text
define-command -hidden peneira-replace-buffer -params 1 %{
    lua %opt{peneira_path} %opt{peneira_temp_file} %opt{peneira_previous_prompt} %arg{1} %{
        local peneira_path, filename, previous_prompt, prompt = args()

        if #prompt < #previous_prompt then
            kak.execute_keys("u")
            return
        end

        if #prompt == 0 then
            return
        end

        -- Add plugin path to the list of path to be searched by `require`
        package.path = string.format("%s/?.lua;%s", peneira_path, package.path)
        local fzy = require "fzy"

        local filtered = {}
        local scores = {}

        -- Treat each word in prompt as a new, refined, search
        local prompt_words = {}

        for word in prompt:gmatch("%S+") do
            prompt_words[#prompt_words + 1] = word
        end

        local file = io.open(filename, 'r')

        if not file then
            kak.echo("-debug", "peneira: couldn't open temporary file " .. filename)
            return
        end

        for candidate in file:lines() do
        	if fzy.has_match(prompt_words[1], candidate) then
        		filtered[#filtered + 1] = candidate
                scores[candidate] = fzy.score(prompt_words[1], candidate)
    		end
		end

		-- Filter again, now using the remaining words
		for i = 2, #prompt_words do
		    local refined = {}

		    for _, candidate in ipairs(filtered) do
            	if fzy.has_match(prompt_words[i], candidate) then
            	    refined[#refined + 1] = candidate
                    scores[candidate] = scores[candidate] + fzy.score(prompt_words[i], candidate)
            	end
            end

            filtered = refined
        end

        -- Sort filtered candidates based on their scores
		table.sort(filtered, function(a, b)
            return scores[a] > scores[b]
		end)

		kak.execute_keys(string.format("%%c%s<esc>", table.concat(filtered, "\n")))

        -- Highlight matches
		local range_specs = {}

		for i, line in ipairs(filtered) do
		    if i > 50 then
		        break
		    end

            for _, word in ipairs(prompt_words) do
                local positions = fzy.positions(word, line)

    		    for _, position in pairs(positions) do
    		        range_specs[#range_specs + 1] = string.format("%d.%d,%d.%d|@PeneiraMatches", i, position, i, position)
    		    end
            end
        end

		kak.peneira_highlight_matches(table.concat(range_specs, "\n"))
	}
}

# arg: range specs
define-command -hidden peneira-highlight-matches -params 1 %{
	lua %val{timestamp} %arg{1} %{
		local timestamp, range_specs_text = args()
		local range_specs = {}

        for spec in range_specs_text:gmatch("[^\n]+") do
            range_specs[#range_specs + 1] = spec
        end

        kak.set_option("buffer", "peneira_matches", timestamp, unpack(range_specs))
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
