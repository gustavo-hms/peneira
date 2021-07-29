declare-option -hidden str peneira_path %sh{ dirname $kak_source }
declare-option -hidden int peneira_selected_line 1 # used to track the selected line
declare-option -hidden line-specs peneira_flag # used to flag selected line
declare-option -hidden range-specs peneira_matches # used to highlight matches
declare-option -hidden str peneira_previous_prompt # used to track changes in prompt
declare-option -hidden str peneira_temp_file # name of the temp file in sync with buffer contents

set-face global PeneiraSelected default,rgba:1c1d2122
set-face global PeneiraFlag LineNumberCursor
set-face global PeneiraMatches value

define-command peneira -params 3 -docstring %{
    peneira <prompt> <candidates> <cmd>: filter <candidates> and then run <cmd> with its first argument set to the selected candidate.
} %{
    edit -scratch "*peneira%sh{ echo $kak_client | cut -c 7- }*"

    set-option buffer peneira_temp_file %sh{
        file=$(mktemp)
        # Execute command that generates candidates, and populate temp file
        $2 > $file
        # Write temp file name to peneira_temp_file option
        printf "%s" $file
    }

    peneira-fill-buffer
    peneira-configure-buffer

    prompt -on-change %{
        peneira-filter-buffer "%val{text}"

        # Save current prompt contents to be compared against the prompt of the
        # next iteration
        set-option buffer peneira_previous_prompt "%val{text}"
        peneira-select-line %opt{peneira_selected_line}

		# It may happen that, filtering out some candidates, the line marked as
		# selected overflows the buffer.
		peneira-avoid-buffer-overflow

    } -on-abort %{
        nop %sh{ rm $kak_opt_peneira_temp_file }
        # Go back to the previous buffer
        execute-keys ga
        delete-buffer "*peneira%sh{ echo $kak_client | cut -c 7- }*"

    } %arg{1} %{
        nop %sh{ rm $kak_opt_peneira_temp_file }

        # Go back to the previous buffer
        execute-keys ga

        evaluate-commands -save-regs ac %{
            # Copy selected line to register a
            evaluate-commands -buffer "*peneira%sh{ echo $kak_client | cut -c 7- }*" %{
                execute-keys %opt{peneira_selected_line}gx_\"ay
            }

            # Copy <cmd> to register c
            set-register c "%arg{3}"
            peneira-call "%reg{a}"
        }

        delete-buffer "*peneira%sh{ echo $kak_client | cut -c 7- }*"
    }
}

define-command -hidden peneira-fill-buffer %{
    # Populate *peneira* buffer with the contents of the temp file
    execute-keys "%%| cat %opt{peneira_temp_file}<ret>"
    peneira-select-line %opt{peneira_selected_line}
    set-option buffer peneira_matches
}

# Configure highlighters and mappings
define-command -hidden peneira-configure-buffer %{
	remove-highlighter window/number-lines
    add-highlighter buffer/peneira-matches ranges peneira_matches
    add-highlighter buffer/peneira-flag flag-lines @PeneiraFlag peneira_flag
	face window PrimaryCursor @PeneiraSelected

	map buffer prompt <down> "<a-;>: peneira-select-next-line<ret>"
	map buffer prompt <tab> "<a-;>: peneira-select-next-line<ret>"
	map buffer prompt <c-n> "<a-;>: peneira-select-next-line<ret>"
	map buffer prompt <up> "<a-;>: peneira-select-previous-line<ret>"
	map buffer prompt <s-tab> "<a-;>: peneira-select-previous-line<ret>"
	map buffer prompt <c-p> "<a-;>: peneira-select-previous-line<ret>"
}

define-command -hidden peneira-select-line -params 1 %{
    execute-keys "<a-;>%arg{1}g"
    set-option buffer peneira_flag %val{timestamp} "%arg{1}| ❯ "
    set-option buffer peneira_selected_line %arg{1}
	add-highlighter -override buffer/current-line line %arg{1} PeneiraSelected
}

define-command -hidden peneira-select-previous-line %{
    lua %opt{peneira_selected_line} %val{buf_line_count} %{
        local selected, line_count = args()
        selected = selected > 1 and selected - 1 or line_count
        kak.peneira_select_line(selected)
    }
}

define-command -hidden peneira-select-next-line %{
    lua %opt{peneira_selected_line} %val{buf_line_count} %{
        local selected, line_count = args()
        selected = selected % line_count + 1
        kak.peneira_select_line(selected)
    }
}

define-command -hidden peneira-avoid-buffer-overflow %{
    lua %opt{peneira_selected_line} %val{buf_line_count} %{
        local selected, line_count = args()

        if selected > line_count then
            kak.peneira_select_line(line_count)
        end
    }
}

# The actual filtering happens here.
# arg: prompt text
define-command -hidden peneira-filter-buffer -params 1 %{
    evaluate-commands -buffer "*peneira%sh{ echo $kak_client | cut -c 7- }*" -save-regs dquote %{
        lua %opt{peneira_path} %opt{peneira_temp_file} %opt{peneira_previous_prompt} %arg{1} %{
            local peneira_path, filename, previous_prompt, prompt = args()

            if prompt == previous_prompt then
                return
            end

            if #prompt == 0 then
                kak.peneira_fill_buffer()
                return
            end

            -- Add plugin path to the list of path to be searched by `require`
            package.path = string.format("%s/?.lua;%s", peneira_path, package.path)
            local peneira = require "peneira"

            local lines, positions = peneira.filter(filename, prompt)

            if not lines then
                kak.execute_keys("%d")
                return
            end

            kak.set_register("dquote", table.concat(lines, "\n"))
    		kak.execute_keys("%R")

            local range_specs = peneira.range_specs(positions)
            unpack = unpack or table.unpack -- make it compatible with both lua and luajit
    		kak.peneira_highlight_matches(unpack(range_specs))
    	}
    }
}

# arg: range specs
define-command -hidden peneira-highlight-matches -params 1.. %{
	lua %arg{@} %val{timestamp} %{
		local timestamp = table.remove(arg)
        unpack = unpack or table.unpack
        kak.set_option("buffer", "peneira_matches", timestamp, unpack(arg))
	}
}

# Call the command stored in the c register. This way, that command can use the
# %arg{1} expansion
define-command -hidden peneira-call -params 1 %{
    evaluate-commands "%reg{c}"
}

## Some ready to be used filters

define-command peneira-files -docstring %{
    peneira-files: select a file in the current directory tree
} %{
    peneira 'files: ' %{ fd --type file } %{
        edit %arg{1}
    }
}
