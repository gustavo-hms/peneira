define-command peneira-filter -params 1 -docstring %{
    peneira-filter <lines> <cmd>: filter <lines> and then run <cmd> with its first argument set to the selected line.
} %{
    edit -scratch *peneira*
    set-option -remove buffer autocomplete insert

    lua "%arg{1}" %{
        kak.hook("-group", "peneira", "buffer", "InsertKey", ".*", string.format("peneira-update-buffer '%s'", arg[1]))
    }

    map buffer insert <del> %{
        <esc>x_y: lua %
    }

    execute-keys "o%arg{1}<esc>ggi❯ <esc>"

    # lua %arg{1} %{
    #     local lines = arg[1]
    #     local on_key_press = [[
    #         execute-keys -buffer *peneira* ggx_"ay
    #         set-register dquote %%sh{ printf '%%s\n' '%s' | fzf -f "$kak_reg_a" }
    #         execute-keys -buffer *peneira* '2gGeRgggl'
    #     ]]

    #     kak.hook("-group", "peneira", "buffer", "InsertKey", ".*", string.format(on_key_press, lines, lines))
    # }
}

# Receive the unfiltered lines
define-command -hidden peneira-update-buffer -params 1 %{
    evaluate-commands -save-regs ab %{
        # Copy prompt contents to register a
        execute-keys -buffer *peneira* 'ggxH"ay'

        # Copy filtered lines to register b
        lua %reg{a} %arg{1} %{
            local prompt, lines = args()
            prompt = prompt:gsub("❯ ", "")
         	local command = string.format("printf '%%s\n' '%s' | fzf -f '%s'", lines, prompt)
         	local filtered = io.popen(command):read("a")
         	kak.set_register("b", filtered)
        }

        # Delete all but the prompt line and paste lines
        try %{
            execute-keys -buffer *peneira* '%<a-s>)<a-space>d'
        }

        execute-keys -buffer *peneira* 'gg"bp'
    }
}

define-command peneira-files -docstring %{
    peneira-files: select a file in the current directory tree
} %{
    peneira-filter %sh{ fd }
}
