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


--- Generate a finder whose results are the current NeoWin terminals 
--- @param localTab boolean? Should the results be tab-local?
local function getFinder(localTab)
  return finders.new_table {
    results = terminals.getTerminalBufs(localTab),
    entry_maker = function(entry)
      local prefix = "(" .. util.getTabName(entry.tabNum) .. ")"
      local fullName = prefix .. " " .. entry.name
      return {
        value = entry,
        display = localTab and entry.name or fullName,
        ordinal = entry.name
      }
    end
  }
end

--- Preview a terminal entry 
--- (attach the terminal buffer directly to the preview window,
--- and scroll to the bottom)
local function previewTerm(self, entry, status)
  local termBuf = entry.value.bufNr
  api.nvim_win_set_buf(status.preview_win, termBuf)
  local lineCount = api.nvim_buf_line_count(termBuf)
  api.nvim_win_set_cursor(status.preview_win, {lineCount, 1})
end


---Detach the terminal buffer from the preview window
---Telescope automatically kills the buffer that was in the preview window, when a selection is made.
---So we attach a scratch buffer to the preview window right before closing,
---thereby preserving the terminal buffer itself
local function detachPreviewer(prompt_bufnr)
  local picker = action_state.get_current_picker(prompt_bufnr)
  local scratchBuf = api.nvim_create_buf(false, true)
  if(picker.preview_win ~= nil) then
    api.nvim_win_set_buf(picker.preview_win, scratchBuf)
  end
end


--- Telescope Action: attach selected terminal to the terminal pane
--- (toggle the terminal pane if necessary)
local function selectTerminal(prompt_bufnr)
  local lastPreviewBuf = require('telescope.state').get_global_key("last_preview_bufnr")
  local entry = action_state.get_selected_entry()
  detachPreviewer(prompt_bufnr)
  actions.close(prompt_bufnr)
  terminals.refresh()
  if api.nvim_get_current_tabpage() ~= entry.value.tabNum then
    api.nvim_set_current_tabpage(entry.value.tabNum)
    terminals.refresh()
  end
  terminals.attach(entry.value.index)
  terminals.setFocus()
end


--- Telescope Action: Attach terminal buffer in place 
--- (to the buffer from which Telescope was opened)
local function attachInPlace(prompt_bufnr)
  local entry = action_state.get_selected_entry()
  detachPreviewer(prompt_bufnr)
  actions.close(prompt_bufnr)
  api.nvim_set_current_buf(entry.value.bufNr)
end


--- Telescope Action: Delete terminal buffer
local function deleteTerminal(prompt_bufnr)
  local entry = action_state.get_selected_entry()
  local termBuf = terminals.getTerminalBufsById(false)[entry.value.bufNr]
  detachPreviewer(prompt_bufnr)
  -- actions.close(prompt_bufnr)
  terminals.delete(termBuf.index)
  local picker = action_state.get_current_picker(prompt_bufnr)
  picker:refresh(getFinder())
end


--- Telescope Action: Rename terminal buffer
local function renameTerminal(prompt_bufnr)
  local promptWin = api.nvim_get_current_win()
  local entry = action_state.get_selected_entry()
  local newName = terminals.renameTerm(entry.value.index)
  entry.name = newName
  entry.ordinal = newName
  local picker = action_state.get_current_picker(prompt_bufnr)
  picker:refresh(getFinder())
end

function M.closePicker(prompt_bufnr)
  detachPreviewer(prompt_bufnr)
  actions.close(prompt_bufnr)
end

function M.termPick(opts)
  terminals.refresh()
  opts = opts or {}
  opts.dynamic_preview_title = true
  pickers.new(opts, {
    prompt_title = "Terminals",
    sorter = conf.generic_sorter(opts),
    finder = getFinder(opts.localTab),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(selectTerminal)
      map("n", "n", attachInPlace)
      map("n", "dd", deleteTerminal)
      map("n", "r", renameTerminal)
      map("n", "<Esc>", M.closePicker)
      map("n", "<C-c>", M.closePicker)
      map("i", "<C-c>", M.closePicker)
      return true
    end,
    previewer = previewers.new({
      dynamic_title = function(self, entry)
        return entry.name
      end,
      preview_fn = previewTerm
    })
}):find()
end

return M
