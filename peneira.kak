define-command peneira-filter -params 2 -docstring %{
    peneira-filter <lines> <cmd>: filter <lines> and then run <cmd> with its first argument set to the selected line.
} %{
    edit -scratch *peneira*
    set-register dquote %sh{ printf '%s\n' $1  }
    execute-keys '%Rgg'

    prompt -on-change %{
        evaluate-commands -buffer *peneira* %{
            lua %val{text} %arg{1} %{
                local search, lines = args()

                if #search > 0 then
                	local commands = [[ printf "%%s\n" "%s" | fzf -f "%s" ]]
                	local filtered = io.popen(commands:format(lines, search)):read("a")
                	kak.execute_keys(string.format("%%c%s<esc>", filtered))

                else
                	kak.execute_keys(string.format("%%c%s<esc>", lines))
                end
            }
        }

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
