local api = vim.api

local M = {}

function M.debug(...)
  local msgs = { ... }
  local s = ''
  for _, msg in pairs(msgs) do
    if type(msg) == 'table' then
      s = s .. '\n' .. vim.inspect(msg) .. '\n'
    else
      s = s .. tostring(msg) .. ' '
    end
  end
  if not vim.g.NEOWIN_DEBUG then
    return
  end
  vim.notify(s, vim.log.levels.DEBUG)
end

function M.toggleDebug() 
  vim.g.NEOWIN_DEBUG = not vim.g.NEOWIN_DEBUG
  local tf = vim.g.NEOWIN_DEBUG and 'true' or 'false'
  vim.notify('Toggled neoWin debug logging to ' .. tf)
end

function M.showBufs(prefix)
  prefix = prefix or ''
  local s = 'Current buffers:'
  for _, buf in pairs(api.nvim_list_bufs()) do
    s = s .. '\n' .. buf .. ': ' .. api.nvim_buf_get_name(buf)
  end
  M.debug(prefix .. s)
end

---Generate a map of bufferId->windowId for all visible windows
function M.windowBufs()
  local out = {}
  for _, win in pairs(api.nvim_list_wins()) do
    local buf = api.nvim_win_get_buf(win)
    out[buf] = win
  end
  return out
end

function M.openBufs() 
  local openBufs = {}
  -- util.debug('FINDING BUFFERS')
  for _, bufNr in pairs(api.nvim_list_bufs()) do
    -- util.debug('Found open buffer ' .. bufNr)
    openBufs[bufNr] = api.nvim_buf_get_name(bufNr)
  end
  return openBufs
end

-- function M.
return M
