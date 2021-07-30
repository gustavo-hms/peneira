# This file defines some ready-to-be-used filters

declare-option str peneira_files_command "fd --type file"

define-command peneira-files -docstring %{
    peneira-files: select a file in the current directory tree
} %{
    lua %val{buflist} %opt{peneira_files_command} %{
        local command = table.remove(arg)
        command = string.format("%s | grep -Fxv '%s'", command, table.concat(arg, "\n"))
        kak.peneira("files: ", command, "edit %arg{1}")
    }
}

define-command peneira-local-files -docstring %{
    peneira-local-files: select a file in the directory tree of the current file
} %{
    lua %val{buflist} %val{bufname} %opt{peneira_files_command} %{
        local command = table.remove(arg)
        local current_file = table.remove(arg)
        local local_dir = current_file:gsub("[^/]+$", "")

        for i, buffer in ipairs(arg) do
            local _, last = buffer:find(local_dir, 1, true)

            if last then
                arg[i] = buffer:sub(last + 1)
            end
        end

        command = string.format([[
            current=$(pwd)
            cd $(dirname %s)
            %s | grep -Fxv '%s'
            cd $current
        ]], current_file, command, table.concat(arg, "\n"))

        kak.peneira("files: ", command, [[
            edit %sh{
                printf "%s/%s" $(dirname ${kak_bufname}) $1
            }
        ]])
    }
}
