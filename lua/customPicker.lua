local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local actions = require "telescope.actions"
local previewers = require'telescope.previewers'
-- local custom = require('telescope.previewers').buffer_previewer
local action_state = require "telescope.actions.state"
local api = vim.api
local autoTerm = require'autoTerm'
local Terminals = autoTerm.Terminals

-- print(vim.inspect(Terminals.bufs))
-- our picker function: colors
function TermPick(opts)
  opts = opts or {}
  pickers.new(opts, {
    prompt_title = "Terminals",
    finder = finders.new_table {
        results = Terminals.bufs,
        entry_maker = function(entry)
            return {value = entry, display = entry.name, ordinal=entry.name}
        end
    },

    sorter = conf.generic_sorter(opts),

    attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
            actions.close(prompt_bufnr)
            local entry = action_state.get_selected_entry()
            api.nvim_set_current_buf(entry.value.number)
        end)
        -- Attach to current window
        -- Create new split
        -- Attach to existing term window
        -- Rename
        map("n", "r", function(prompt_bufnr)
            local entry = action_state.get_selected_entry()
            local newName = autoTerm.rename(entry.value.index)
            entry.display = newName
            entry.ordinal = newName
            local picker = action_state.get_current_picker(prompt_bufnr)
            picker:refresh(picker.finder)
            print(vim.inspect(entry))
        end)

        return true
    end,
    previewer = previewers.new({
        setup = function(self) 
            return {winid = self.winid}
        end,
        teardown=nil,
        preview_fn = function(self, entry, status)
            local newBuf = api.nvim_create_buf(false, true)
            local termBuf = entry.value.number
            local lineCount = api.nvim_buf_line_count(termBuf)
            local lines = api.nvim_buf_get_lines(termBuf, 0, lineCount, false)
            api.nvim_buf_set_lines(newBuf, 0, lineCount, false, lines)
            api.nvim_win_set_buf(status.preview_win, newBuf)
        end
    })

    --[[ previewer = previewers.new_buffer_previewer({
        keep_last_buf = false,
        define_preview = function(self, entry, status)
            api.nvim_win_set_buf(status.preview_win, entry.value.number)
        end}),
 ]]
  }):find()
end

-- to execute the function
-- colors()
