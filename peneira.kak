declare-option -hidden str peneira_path %sh{ dirname $kak_source }

define-command peneira-filter -params 2 -docstring %{
    peneira-filter <lines> <cmd>: filter <lines> and then run <cmd> with its first argument set to the selected line.
} %{
    edit -scratch *peneira*
    set-register dquote %sh{ printf '%s\n' $1  }
    execute-keys '%Rgg'

    prompt -on-change %{
        peneira-replace-buffer "%val{text}" "%arg{1}"
        execute-keys '<a-;>gg'

    } -on-abort %{
        delete-buffer *peneira*

    } 'Filter: ' %{
        evaluate-commands -save-regs ac %{
            execute-keys -buffer *peneira* ggx_\"ay
            set-register c "%arg{2}"
            peneira-call "%reg{a}"
        }

        delete-buffer *peneira*
    }
}

define-command -hidden peneira-replace-buffer -params 2 %{
    # arg1: prompt text
    # arg2: original lines
    evaluate-commands -buffer *peneira* %{
        lua %opt{peneira_path} %arg{@} %{
            local peneira_path, prompt, lines = args()

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
