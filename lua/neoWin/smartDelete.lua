local util = require('util')
local api = vim.api

local M = {}

local PopArray = {}

function PopArray:new(len, existingItems)
  util.debug('CREATING POPARRAY')
  existingItems = existingItems or {}
  local inst = {len=len, count=#existingItems, items=existingItems}
  setmetatable(inst, self)
  self.__index = self
  return inst
end

function PopArray:contains(checkItem) 
  for i, item in pairs(self.items) do
    if checkItem == item then return true end
  end
  return false
end

function PopArray:popBack() 
  if self.count == 0 then return end
  local back = self.items[self.count]
  self.items[self.count] = nil
  self.count = self.count - 1
  util.debug('Popped back item ' .. back .. ' - Current items: ' .. vim.inspect(self.items))
end

function PopArray:popFront() 
  if self.count == 0 then return end
  local _items = {}
  local front = self.items[1]
  self.count = 0
  for i, item in ipairs(self.items) do
    if i ~= 1 and item ~= front then 
      _items[#_items+1] = item
      self.count = self.count + 1
    end
  end
  self.items = _items
  util.debug('Popped front item ' .. front .. ' - Current items: ' .. vim.inspect(self.items))
end

function PopArray:push(item) 
  if item == self.items[1] then 
    util.debug('Refusing to push item ' .. item .. ' (it is already the front) - Current items: ' .. vim.inspect(self.items))
    return
  end
  if self.count + 1 > self.len then
    self:popBack()
  end

  local _items = {item};
  for i, item in ipairs(self.items) do
    _items[i+1] = item
  end
  self.items = _items
  self.count = self.count + 1
  util.debug('Pushed item ' .. item .. ' - Current items: ' .. vim.inspect(self.items))
end

local function getBufsByName() 
  local nameMap = {}
  for _, bufNr in ipairs(vim.api.nvim_list_bufs()) do
    local buflisted = vim.bo[bufNr].buflisted
    local bufName = vim.api.nvim_buf_get_name(bufNr)
    if bufName ~= nil and buflisted then
      nameMap[bufName] = bufNr
    end
  end
  return nameMap
end

--- TabNum -> array of most recent buffers
M.LAST_BUFS = {}
function M.deserialize(bufsMap)
  local deserialized = {}
  local bufNrs = getBufsByName()
  util.debug('BUF NAMES:\n' .. vim.inspect(bufNrs))
  for tabNr, bufNames in pairs(bufsMap) do 
    local bufs = {}
    if bufNames ~= nil and bufNames ~= vim.NIL then
      util.debug('DESERIALIZING BUF NAMES FOR TAB ' .. tabNr .. ': ' .. vim.inspect(bufNames) .. '(' .. type(bufNames) .. ')')
      for i, bufName in ipairs(bufNames) do
        bufs[i] = bufNrs[bufName]
      end
      deserialized[tabNr] = PopArray:new(999, bufs)
    end
  end
  M.LAST_BUFS = deserialized
  for tabNr, lastBuf in pairs(M.LAST_BUFS) do
    util.debug('DESERIALIZED SESSION (tab ' .. tabNr .. '): ' .. vim.inspect(lastBuf.items) .. '')
  end
  vim.fn.writefile({vim.inspect(M.LAST_BUFS)}, 'C:\\Users\\RC12664\\Repos\\neoWin\\deserialized')
end

function M.serialize() 
  local serialized = {}
  for tabNr, lastBuf in pairs(M.LAST_BUFS) do 
    local bufNames = {}
    for i, bufNr in ipairs(lastBuf.items) do 
      bufNames[i] = vim.api.nvim_buf_get_name(bufNr)
    end
    serialized[tabNr] = bufNames
  end
  return serialized
end



function M.updateLastBuf(tabNr, bufNr) 
  if not vim.bo[bufNr].buflisted then
    return
  end
  if M.LAST_BUFS[tabNr] == nil then
    util.debug('Setting up LAST_BUFS object for tabNr ' .. tabNr)
    M.LAST_BUFS[tabNr] = PopArray:new(999)
  end
  local lastBuf

  lastBuf = M.LAST_BUFS[tabNr]
  -- if not lastBuf:contains(bufNr) then
  local bufName = vim.api.nvim_buf_get_name(bufNr)
  if bufName ~= nil then
    local origName = bufName
    bufName = bufName:match("([^\\]+)$") 
    if bufName == nil or bufName == "" then bufName = origName end
    util.debug('Pushing buf number ' .. bufNr .. ' (name=' .. (bufName or 'nil') .. ') to tab ' .. tabNr)

    lastBuf:push(bufNr)
    -- end
  end
end

function M.getLastBuf(tabNr)
  local lastBuf = M.LAST_BUFS[tabNr]
  util.debug('Last buf exists? ' .. (lastBuf == nil and 'no' or 'yes'))
  return lastBuf and lastBuf.items[1]
end

function M.smartDelete(force) 
  if vim.o.filetype == 'Terminal' then
    vim.notify('Do not close terminal buffers with bdelete - exit the terminal process explicitly', vim.log.levels.WARN)
    return
  end
  -- local delCmd = 'bdelete'
  -- if force then
  --   delCmd = delCmd .. '!'
  -- end

  -- local listed = listedBufs()
  -- vim.cmd(delCmd)
  -- if #listed == 1 then
  --   return
  -- end
  --
  local currBuf = api.nvim_get_current_buf()

  local tab = vim.api.nvim_tabpage_get_number(0)
  util.debug('Smart-deleting current buf: ' .. currBuf .. '(current tab = ' .. tab .. ')')

  local recentBufs = M.LAST_BUFS[tab]
  if recentBufs ~= nil then 
    util.debug('POPPING FRONT')
    recentBufs:popFront()
    local lastBuf = M.getLastBuf(tab)
    util.debug('Last buf: ' .. (lastBuf or 'nil'))
    vim.api.nvim_win_set_buf(0, lastBuf)
  end
  vim.api.nvim_buf_delete(currBuf, {force=force})

  -- cycle away from the current buffer that we want to delete 
  -- (such that the "#" alternate buffer resolves to it afterwards)
  -- delCmd = delCmd .. ' #' -- delete the previously focused buffer (the 'alternate' buffer in vim-speak)
  -- vim.cmd('b#')
  -- return vim.cmd(delCmd)
end

function M.smartCloseWin(force)
  local tabWins = api.nvim_tabpage_list_wins(0)
  local numWins = 0
  for _, win in ipairs(tabWins) do
    local buf = vim.api.nvim_win_get_buf(win)
    local bo = vim.bo[buf]
    local whitelist = {
      ['qf'] = true,
      ['Terminal'] = true,
      ['fugitive'] = true,
      ['help'] = true
    }
    if bo.buflisted or whitelist[bo.filetype] then 
      numWins = numWins+1
    end
  end

  if numWins > 1 or force then
    vim.cmd('close')
  end
end

return M
