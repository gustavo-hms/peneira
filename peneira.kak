define-command peneira-filter -params 1 -docstring %{
    peneira-filter <lines> <cmd>: filter <lines> and then run <cmd> with its first argument set to the selected line.
} %{
    edit -scratch *peneira*
    set-option -remove buffer autocomplete insert

    lua "%arg{1}" %{
        kak.hook("-group", "peneira", "buffer", "InsertKey", ".*", string.format("peneira-update-buffer '%s'", arg[1]))
    }

    map buffer insert <backspace> '<esc>: peneira-map-del<ret>i'

    execute-keys "o%arg{1}<esc>ggi❯ <esc>"
}

define-command -hidden peneira-map-del %{
    evaluate-commands -save-regs p %{
        peneira-copy-prompt
        lua %val{cursor_byte_offset} %{
            local prompt = "❯ "
            if arg[1] > #prompt then
            	kak.execute_keys("hd")
        	end
        }
    }
}

define-command -hidden peneira-copy-prompt %{
    # Copy prompt contents to register p
    execute-keys -buffer *peneira* 'ggxH"py'
}

# Receive the unfiltered lines
define-command -hidden peneira-update-buffer -params 1 %{
    evaluate-commands -save-regs pa %{
        peneira-copy-prompt

        # Copy filtered lines to register a
        lua %reg{p} %arg{1} %{
            local prompt, lines = args()
            prompt = prompt:gsub("❯ ", "")
         	local command = string.format("printf '%%s\n' '%s' | fzf -f '%s'", lines, prompt)
         	local filtered = io.popen(command):read("a")
         	kak.set_register("a", filtered)
        }

        # Delete all but the prompt line and paste lines
        try %{
            execute-keys -buffer *peneira* '%<a-s>)<a-space>d'
        }

        execute-keys -buffer *peneira* 'gg"ap'
    }
}

define-command peneira-files -docstring %{
    peneira-files: select a file in the current directory tree
} %{
    peneira-filter %sh{ fd }
}
