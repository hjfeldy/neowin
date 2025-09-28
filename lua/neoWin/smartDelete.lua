local terminals = require('neoWin.terminals')
local api = vim.api

local M = {}

local function listedBufs()
  local out = {}
  for _, buf in ipairs(api.nvim_list_bufs()) do
    local listed = api.nvim_get_option_value('buflisted', {buf=buf})
    local name = api.nvim_buf_get_name(buf)
    if listed then
      out[#out+1] = name
    end
  end
  return out
end

function M.smartDelete(force) 
  if vim.o.filetype == 'Terminal' then
    vim.notify('Do not close terminal buffers with bdelete - exit the terminal process explicitly', vim.log.levels.WARN)
    return
  end
  local delCmd = 'bdelete'
  if force then
    delCmd = delCmd .. '!'
  end

  local listed = listedBufs()
  if #listed == 1 then
    return vim.cmd(delCmd)
  end

  -- cycle away from the current buffer that we want to delete 
  -- (such that the "#" alternate buffer resolves to it afterwards)
  delCmd = delCmd .. ' #' -- delete the previously focused buffer (the 'alternate' buffer in vim-speak)
  vim.cmd('BufferLineCyclePrev')
  return vim.cmd(delCmd)
end

function M.smartCloseWin(force)
  local tabWins = api.nvim_tabpage_list_wins(0)
  local numWins = 0
  for _, win in ipairs(tabWins) do
    local buf = vim.api.nvim_win_get_buf(win)
    local bufListed = vim.api.nvim_get_option_value('buflisted', {buf=buf})
    if bufListed then 
      numWins = numWins+1
    end
  end

  if numWins > 1 or force then
    vim.cmd('close')
  end
end

return M
