local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local actions = require "telescope.actions"
local previewers = require'telescope.previewers'
local action_state = require "telescope.actions.state"
local terminals = require('neoWin.terminals')
local util = require('neoWin.util')
local api = vim.api

local M = {}


--- Attach terminal buffer at the top of the screen
--- (toggle the terminal pane if necessary)
local function selectTerminal(prompt_bufnr)
  util.showBufs('(SELECT TERMINAL) ')
  actions.close(prompt_bufnr)
  local entry = action_state.get_selected_entry()
  util.debug('(prompt_bufnr = ' .. prompt_bufnr .. ') Selecting current picker entry: Terminal #' .. entry.value.index .. ', Buffer #' .. entry.value.bufNr)
  util.debug('Entry:\n' .. vim.inspect(entry.value))
  terminals:attach(entry.value.index)
end

--- Attach terminal buffer in place 
--- (in the buffer occupied when Telescope was opened)
local function attachInPlace(prompt_bufnr)
  local entry = action_state.get_selected_entry()
  actions.close(prompt_bufnr)
  api.nvim_set_current_buf(entry.value.bufNr)
end


--- Delete terminal buffer
local function deleteTerminal(prompt_bufnr)
  local entry = action_state.get_selected_entry()
  local termBuf = terminals.bufsById[entry.value.bufNr]
  actions.close(prompt_bufnr)
  terminals:delete(termBuf.index)
end

--- Rename terminal buffer
local function renameTerminal(prompt_bufnr)
  local promptWin = api.nvim_get_current_win()
  local entry = action_state.get_selected_entry()
  local newName = terminals:renameTerm(entry.value.index)
  entry.name = newName
  entry.ordinal = newName
  local picker = action_state.get_current_picker(prompt_bufnr)
  local newFinder = getFinder()
  -- api.nvim_set_current_win(promptWin)
  picker:refresh(newFinder)
end

--- Preview a terminal entry 
local function previewTerm(entry, status)
  local newBuf = api.nvim_create_buf(false, true)
  local termBuf = entry.value.bufNr
  local lineCount = api.nvim_buf_line_count(termBuf)
  local previewHeight = api.nvim_win_get_height(status.preview_win)
  local lineStart = lineCount - previewHeight
  if lineStart < 0 then
    lineStart = 0
  end
  -- print('Previewing lines from ' .. lineStart .. ' to ' .. lineStart + previewHeight .. '(' .. lineCount .. ' lines total)')
  local lines = api.nvim_buf_get_lines(termBuf, lineStart, lineStart + previewHeight, false)
  util.debug('Previewing Lines:\n' .. vim.inspect(lines))
  api.nvim_buf_set_lines(newBuf, 0, 0, false, lines)
  api.nvim_win_set_buf(status.preview_win, newBuf)
  api.nvim_set_option_value('wrap', false, {win=status.preview_win})
  require('telescope.previewers.utils').regex_highlighter(newBuf, 'Terminal')
end

--- Generate a finder whose results are the current terminals 
local function getFinder()
  return finders.new_table {
    results = terminals.bufs,
    entry_maker = function(entry)
      return {
        value = entry,
        display = entry.name,
        ordinal=entry.name
      }
    end
  }
end


function M.termPick(opts)
  util.debug('Setting current (termPick())')
  terminals:setCurrent()
  opts = opts or {}
  opts.dynamic_preview_title = true
  pickers.new(opts, {
    prompt_title = "Terminals",
    sorter = conf.generic_sorter(opts),
    finder = getFinder(),
    attach_mappings = function(prompt_bufnr, map)
      util.debug('Attaching mappings for prompt_bufnr ' .. prompt_bufnr)
      actions.select_default:replace(selectTerminal)
      map("n", "n", attachInPlace)
      map("n", "d", deleteTerminal)
      map("n", "r", renameTerminal)
      return true
    end,

    -- previewer = require("telescope.config").values.grep_previewer(opts)
    previewer = previewers.new({
      setup = function(self)
        util.showBufs('(NEW-PREVIEWER) ')
        return {winid = self.winid}
      end,
      teardown=nil,
      dynamic_title = function(self, entry)
        return entry.name
      end,
      -- preview_fn = function(self, entry, status) return previewTerm(entry, status) end
      -- preview_fn = function(self, entry, status) return previewTerm(entry, status) end
    })
}):find()
end

return M
