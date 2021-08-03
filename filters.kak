# This file defines some ready-to-be-used filters

declare-option str peneira_files_command "fd --type file"

define-command peneira-files -docstring %{
    peneira-files: select a file in the current directory tree, ignoring already opened ones.
} %{
    lua %val{buflist} %opt{peneira_files_command} %{
        local command = table.remove(arg)
        -- Do not list already opened files
        command = string.format("%s | grep -Fxv '%s'", command, table.concat(arg, "\n"))
        kak.peneira("files: ", command, "edit %arg{1}")
    }
}

define-command peneira-local-files -docstring %{
    peneira-local-files: select a file in the directory tree of the current file, ignoring already opened ones.
} %{
    lua %val{buflist} %val{bufname} %opt{peneira_files_command} %{
        local command = table.remove(arg)
        local current_file = table.remove(arg)
        local local_dir = current_file:gsub("[^/]+$", "")

        -- Remove dir prefix from buffers names
        for i, buffer in ipairs(arg) do
            local _, last = buffer:find(local_dir, 1, true)

            if last then
                arg[i] = buffer:sub(last + 1)
            end
        end

        command = string.format([[
            current=$(pwd)
            cd %s
            # Do not list already opened files
            %s | grep -Fxv '%s'
            cd $current
        ]], local_dir, command, table.concat(arg, "\n"))

        kak.peneira("files: ", command, [[
            edit %sh{
                printf "%s/%s" $(dirname $kak_bufname) $1
            }
        ]])
    }
}

define-command peneira-tags -docstring %{
    peneira-tags: select a symbol definition for the current buffer
} %{
    peneira 'tags: ' %{ ctags -f - $kak_buffile | sed -r 's/^([^\t]+).+/\1/g' } %{
        lua %val{bufname} %arg{1} %{
            local buffer, tag = args()
            local pattern = "^" .. tag .. "\t.+/^([^/]+)$/"

            local ctags = io.popen("ctags --pattern-length-limit=0 -f - " .. buffer)

            for line in ctags:lines() do
                -- Extract everything between /^ and $/
                local match = line:match(pattern)

                if match then
                    -- Interpret the matched string literally
                    local search = [[\Q]] .. match .. [[\E]]

                    -- Kakoune interprets everything between angle brackets as
                    -- a key (like <ret> and <esc>), so searching for thing like
                    -- Vec<i64> won't work. Thus, we need to cheat a little.
                    search = search:gsub("<", [[\E.\Q]])
                    kak.execute_keys("/" .. search .. "<ret>")
                    kak.execute_keys("s" .. tag .. "<ret>vv")
                    return
                end
            end
        }
    }
}

define-command peneira-lines -docstring %{
    peneira-lines: select a line in the current buffer
} %{
    evaluate-commands -save-regs dquote %{
        execute-keys -draft -save-regs '' '%y'
        peneira 'lines: ' %{ printf "%s\n" $kak_quoted_reg_dquote } %{
            echo %arg{1}
        }
    }
}
