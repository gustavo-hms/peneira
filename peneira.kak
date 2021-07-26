declare-option -hidden str peneira_path %sh{ dirname $kak_source }
declare-option -hidden str peneira_selected_line 1
declare-option -hidden str peneira_face_selected @MenuForeground

define-command peneira-filter -params 2 -docstring %{
    peneira-filter <lines> <cmd>: filter <lines> and then run <cmd> with its first argument set to the selected line.
} %{
    edit -scratch *peneira*
    peneira-configure-buffer

    execute-keys "%%c%arg{1}<esc>gg"

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

define-command -hidden peneira-configure-buffer %{
	remove-highlighter window/number-lines
	add-highlighter window/current-line line %opt{peneira_selected_line} %opt{peneira_face_selected}
	face window PrimaryCursor %opt{peneira_face_selected}
	map buffer prompt <down> "<a-;>: peneira-select-next-line<ret>"
	map buffer prompt <up> "<a-;>: peneira-select-previous-line<ret>"
}

define-command -hidden peneira-select-previous-line %{
    lua %opt{peneira_selected_line} %opt{peneira_face_selected} %{
        local selected, face = args()
        selected = selected > 1 and selected - 1 or selected
        kak.set_option("buffer", "peneira_selected_line", selected)
    	kak.add_highlighter("-override", "window/current-line", "line", selected, face)
    }
}

define-command -hidden peneira-select-next-line %{
    lua %opt{peneira_selected_line} %opt{peneira_face_selected} %val{buf_line_count} %{
        local selected, face, line_count = args()
        selected = selected < line_count and selected + 1 or selected
        kak.set_option("buffer", "peneira_selected_line", selected)
    	kak.add_highlighter("-override", "window/current-line", "line", selected, face)
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
            local score_cache = {}

            for line in lines:gmatch("[^\n]*") do
            	if fzy.has_match(prompt, line) then
            		filtered[#filtered + 1] = line
                    score_cache[line] = fzy.score(prompt, line)
        		end
    		end

    		table.sort(filtered, function(a, b)
                return score_cache[a] > score_cache[b]
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
