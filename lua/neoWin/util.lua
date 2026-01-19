local api = vim.api

local M = {}

--- Emit a debug log (if debug logging for neowin is enabled)
--- @return nil
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

--- Toggle debug logging 
--- @return nil
function M.toggleDebug() 
  vim.g.NEOWIN_DEBUG = not vim.g.NEOWIN_DEBUG
  local tf = vim.g.NEOWIN_DEBUG and 'true' or 'false'
  vim.notify('Toggled neoWin debug logging to ' .. tf)
end

--- Generate a map of bufferId->windowId for all visible windows
--- @reteurn { [integer]: integer }
function M.windowBufs()
  local out = {}
  for _, win in pairs(api.nvim_tabpage_list_wins(0)) do
    local buf = api.nvim_win_get_buf(win)
    out[buf] = win
  end
  return out
end

--- Get a map of buffer IDs -> names 
--- @return { [integer]: string }
function M.openBufs() 
  local openBufs = {}
  -- util.debug('FINDING BUFFERS')
  for _, bufNr in pairs(api.nvim_list_bufs()) do
    -- util.debug('Found open buffer ' .. bufNr)
    openBufs[bufNr] = api.nvim_buf_get_name(bufNr)
  end
  return openBufs
end

--- Get the tab name set by bufferline, or a default "Tab N" name
--- @param tabNum integer
--- @return string
function M.getTabName(tabNum)
  if tabNum == nil then tabNum = 0 end
  local ok, name = pcall(api.nvim_tabpage_get_var, tabNum, 'name')
  return ok and name or ("Tab " .. tabNum)
end

--- Get a map of buffer names -> IDs
--- @return { [string]: integer }
function M.getBufsByName()
  --- @type { [string]: integer }
  local nameMap = {}
  for _, bufNr in ipairs(vim.api.nvim_list_bufs()) do
    local buflisted = vim.bo[bufNr].buflisted
    local bufName = vim.api.nvim_buf_get_name(bufNr)
    if bufName ~= nil and buflisted then
      nameMap[bufName] = bufNr
    end
  end
  nameMap[1] = "s"
  return nameMap
end

function M.dotEnv()
  local env = {}
  local dotEnvPath = vim.uv.cwd() .. '/.env'
  for ln in io.lines(dotEnvPath) do
    local split = vim.split(ln, '=')
    local key, val = split[1], split[2]
    env[key] = val
  end
  return env
end

return M
