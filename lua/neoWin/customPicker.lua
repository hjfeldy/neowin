local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local actions = require "telescope.actions"
local previewers = require'telescope.previewers'
local action_state = require "telescope.actions.state"
local api = vim.api

local M = {}

M.termPick = function(opts)
    require'neoWin.terminals'.terminals:setCurrent()
    opts = opts or {}
    opts.dynamic_preview_title = true
    pickers.new(opts, {
    prompt_title = "Terminals",
    sorter = conf.generic_sorter(opts),
    finder = finders.new_table {
        results = require'neoWin.terminals'.terminals.bufs,
        entry_maker = function(entry)
            return {value = entry, display = entry.name, ordinal=entry.name}
        end
    },

    attach_mappings = function(prompt_bufnr, map)
        -- Attach terminal buffer at the top of the screen
        actions.select_default:replace(function()
            actions.close(prompt_bufnr)
            local entry = action_state.get_selected_entry()
            require'neoWin.terminals'.terminals:attach(entry.value.index)
        end)

        -- Attach terminal buffer in place
        map("n", "n", function(prompt_bufnr)
            local entry = action_state.get_selected_entry()
            actions.close(prompt_bufnr)
            api.nvim_set_current_buf(entry.value.bufNr)
        end)

        -- Delete terminal buffer
        map("n", "d", function(prompt_bufnr)
            local entry = action_state.get_selected_entry()
            actions.close(prompt_bufnr)
            local bufNr
            for _, win in pairs(api.nvim_list_wins()) do
                bufNr = api.nvim_win_get_buf(win)
                if bufNr == entry.value.bufNr then
                    api.nvim_win_close(win, true)
                end
            end
            -- require'neoWin.terminals'.terminals:delete(entry.value.index)
            api.nvim_buf_delete(entry.value.bufNr, {force=true})
            require'neoWin.terminals'.terminals:setCurrent()

        end)

        -- Rename terminal buffer
        map("n", "r", function(prompt_bufnr)
            local promptWin = api.nvim_get_current_win()
            local entry = action_state.get_selected_entry()
            local newName = require'neoWin.terminals'.terminals:renameTerm(entry.value.index)
            entry.name = newName
            entry.ordinal = newName
            local picker = action_state.get_current_picker(prompt_bufnr)
            local newFinder = finders.new_table {
                            results = require'neoWin.terminals'.terminals.bufs,
                            entry_maker = function(entry)
                                return {value = entry,
                                        display = entry.name,
                                        ordinal=entry.name}
                                end
                            }
            -- api.nvim_set_current_win(promptWin)
            picker:refresh(newFinder)
        end)
        return true
    end,

    previewer = previewers.new({
        setup = function(self)
            return {winid = self.winid}
        end,
        teardown=nil,
        dynamic_title  = function(self, entry)
            return entry.name
        end,
        preview_fn = function(self, entry, status)
            local newBuf = api.nvim_create_buf(false, true)
            local termBuf = entry.value.bufNr
            local lineCount = api.nvim_buf_line_count(termBuf)
            local previewHeight = api.nvim_win_get_height(status.preview_win)
            local lineStart = lineCount - previewHeight
            if lineStart < 0 then
                lineStart = 0
            end
            print('Previewing lines from ' .. lineStart .. ' to ' .. lineStart + previewHeight .. '(' .. lineCount .. ' lines total)')
            local lines = api.nvim_buf_get_lines(termBuf, lineStart, lineStart + previewHeight, false)
            print(vim.inspect(lines))
            api.nvim_buf_set_lines(newBuf, 0, 0, false, lines)
            api.nvim_win_set_buf(status.preview_win, newBuf)
            api.nvim_win_set_option(status.preview_win, "wrap", false)
            require('telescope.previewers.utils').regex_highlighter(newBuf, 'Terminal')
        end
    })
  }):find()
end

return M
