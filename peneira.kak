declare-option -hidden str peneira_path %sh{ dirname $kak_source }
declare-option -hidden str peneira_selected_line 1

define-command peneira-filter -params 2 -docstring %{
    peneira-filter <lines> <cmd>: filter <lines> and then run <cmd> with its first argument set to the selected line.
} %{
    edit -scratch *peneira*

	map buffer prompt <down> "<a-;>: peneira-select-next-line<ret>"
	map buffer prompt <up> "<a-;>: peneira-select-previous-line<ret>"

    execute-keys "%%c%sh{ printf '%%s\n' $1 }"

    prompt -on-change %{
        peneira-replace-buffer "%val{text}" "%arg{1}"
        execute-keys "<a-;>%opt{peneira_selected_line}g"

    } -on-abort %{
        delete-buffer *peneira*

    } 'Filter: ' %{
        evaluate-commands -save-regs ac %{
            execute-keys -buffer *peneira* %opt{peneira_selected_line}gx_\"ay
            set-register c "%arg{2}"
            peneira-call "%reg{a}"
        }

        delete-buffer *peneira*
    }
}

define-command -hidden peneira-select-previous-line %{
    lua %opt{peneira_selected_line} %{
        local selected = arg[1]

        if selected == 1 then
        	selected = 2
    	end

        kak.set_option("buffer", "peneira_selected_line", selected - 1)
    }
}

define-command -hidden peneira-select-next-line %{
    lua %opt{peneira_selected_line} %val{buf_line_count} %{
        local selected, line_count = args()

        if selected >= line_count then
        	selected = line_count - 1
    	end

        kak.set_option("buffer", "peneira_selected_line", selected + 1)
    }
}

define-command -hidden peneira-replace-buffer -params 2 %{
    # arg1: prompt text
    # arg2: original lines
    evaluate-commands -buffer *peneira* %{
        lua %opt{peneira_path} %arg{@} %{
            local peneira_path, prompt, lines = args()

            if #prompt == 0 then
        		kak.execute_keys(string.format("%%c%s<esc>", lines))
        		return
    		end

            package.path = string.format("%s/?.lua;%s", peneira_path, package.path)
            local fzy = require "fzy"

            local filtered = {}

            for line in lines:gmatch("[^\n]*") do
            	if fzy.has_match(prompt, line) then
            		filtered[#filtered + 1] = line
        		end
    		end

    		local score_cache = {}

    		table.sort(filtered, function(a, b)
    			local score_a, score_b = score_cache[a], score_cache[b]

    			if not score_a then
    				score_a = fzy.score(prompt, a)
    			end

    			if not score_b then
    				score_b = fzy.score(prompt, b)
    			end

    			score_cache[a], score_cache[b] = score_a, score_b
    			return score_a > score_b
    		end)

    		local keys = string.format("%%c%s<esc>", table.concat(filtered, "\n"))
    		kak.execute_keys(keys)
		}
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
    peneira-filter %sh{ fd } %{
        edit %arg{1}
    }
}
