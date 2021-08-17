provide-module peneira %{

require-module peneira-core

# This file defines some built-in filters

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

define-command peneira-symbols -docstring %{
    peneira-symbols: select a symbol definition for the current buffer
} %{
    peneira-symbols-configure-buffer

    peneira 'symbols: ' %{
        export LUA_PATH="$kak_opt_peneira_path/?.lua"
        env lua=$kak_opt_luar_interpreter "$kak_opt_peneira_path/filters" symbols "$kak_buffile"
    } %{
        lua %arg{1} %val{buffile} %opt{peneira_path} %{
            addpackagepath(arg[3])
            local peneira = require "peneira"

            local selected, file = args()
            local index = tonumber(selected:match("%d+$"))
            local tags = peneira.read_tags(file)
            local tag = tags[index]

            kak.execute_keys(tag.line .. "gx")

            -- Interpret name literally
            local name = [[\Q]] .. tag.name .. [[\E]]

            -- Ctags may insert spaces in the name in some cases. For instance,
            -- if the tag name is `operator==`, ctags converts it to
            -- `operator ==`. In such cases, a search in the document for
            -- that name would fail. Thus, we need to make the spaces optional.
            name = name:gsub("%s", [[\E\s?\Q]])

            -- Kakoune interprets everything between angle brackets as
            -- a key (like <ret> and <esc>), so searching for thing like
            -- Vec<i64> won't work. Thus, we need to cheat a little.
            name = name:gsub("<", [[\E.\Q]])
            kak.execute_keys("s" .. name .. "<ret>vv")
        }
    }
}

define-command -hidden peneira-symbols-configure-buffer %{
    hook -once global WinCreate "\*peneira%sh{ echo $kak_client | cut -c 7- }\*" %{
        # The format of each line is: tag kind( : type)?( (scope))? index
        add-highlighter window/ regex '\S+ (\w+)(?: : ([^()]+))?(?: (\(\S+\)))? (\d+)' 1:keyword 2:type 3:comment 4:+di@BufferPadding
        # We need to specify peneira-matches highlighter again to overwrite the
        # highlighter in the above line.
        add-highlighter window/peneira-matches ranges peneira_matches
    }
}

define-command peneira-lines -docstring %{
    peneira-lines: select a line in the current buffer
} %{
    evaluate-commands -save-regs '"fg' %{
        # Save filetype of current buffer to apply its highlighters to *peneira*
        # buffer.
        set-register f %opt{filetype}
        # Save current line to make *peneira* buffer also selects it.
        set-register g %val{cursor_line}
        peneira-lines-configure-buffer

        # Copy buffer contents to a temporary file.
        set-register dquote %sh{ mktemp }
        execute-keys -draft '%<a-|> cat > $kak_reg_dquote<ret>'

        peneira -no-rank 'lines: ' %{
            export LUA_PATH="$kak_opt_peneira_path/?.lua"
            env lua=$kak_opt_luar_interpreter "$kak_opt_peneira_path/filters" lines $kak_reg_dquote
        } %{
            execute-keys %sh{ echo $1 | awk '{ print $1 }' }gx
        }

        nop %sh{ rm $kak_reg_dquote }
    }
}

define-command -hidden peneira-lines-configure-buffer %{
    hook -once global WinCreate "\*peneira%sh{ echo $kak_client | cut -c 7- }\*" %{
        lua %reg{f} %{
            local filetype = arg[1] == "kak" and "kakrc" or arg[1]
            kak.add_highlighter("window/", "ref", filetype)
        }

        add-highlighter window/ regex ^\s*\d+\s 0:@LineNumbers

        # The default face isn't that readable with the filetype highlighter
        # enabled.
        set-face window PeneiraMatches default,rgba:34363e22+ib

        # Start the filter with the current line selected.
        peneira-select-line %reg{g}
    }
}

}

