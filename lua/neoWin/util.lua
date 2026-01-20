local api = vim.api
local settings = require('neoWin.settings').CONF

local M = {}


--- Generate a map of windowId->bufferId for all visible windows
--- @reteurn { [integer]: integer }
function M.windowBufs()
  local out = {}
  for _, win in pairs(api.nvim_tabpage_list_wins(0)) do
    local buf = api.nvim_win_get_buf(win)
    out[win] = buf
  end
  return out
end

--- Get a map of buffer IDs -> names 
--- @return { [integer]: string }
function M.openBufs() 
  local openBufs = {}
  for _, bufNr in pairs(api.nvim_list_bufs()) do
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

  local ok, lines = pcall(io.lines, dotEnvPath)
  if not ok then return env end

  for ln in io.lines(dotEnvPath) do
    local split = vim.split(ln, '=')
    local key, val = split[1], split[2]
    env[key] = val
  end
  return env
end

---@param confKey string
function M.getDynamicConf(confKey)
  local hasNeoconf, neoconf = pcall(require, 'neoconf')
  -- local hasNeoconf = true
  -- local neoconf = require('neoconf')
  local confSection = hasNeoconf and neoconf.get(confKey)
  -- if no dynamic config available, fallback to settings 
  confSection = confSection or settings[confKey] or {}
  return confSection
  -- return confSection[loggerLabel] or confSection['GLOBAL'] or {}
end

return M
