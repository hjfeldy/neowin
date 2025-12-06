local util = require('neoWin.util')
local api = vim.api

local M = {}

--- Data structure for most-recently-touched buffers
local Stack = {}

--- @param len integer
--- @param existingItems any[]
function Stack:new(len, existingItems)
  util.debug('CREATING Stack')
  existingItems = existingItems or {}
  local inst = {len=len, count=#existingItems, items=existingItems}
  setmetatable(inst, self)
  self.__index = self
  return inst
end

--- Remove the last item in the stack (ie the oldest historical buffer-touched event)
--- We do this simply to avoid leaking memory, no other reason
function Stack:popBack() 
  if self.count == 0 then return end
  local back = self.items[self.count]
  self.items[self.count] = nil
  self.count = self.count - 1
  util.debug('Popped back item ' .. back .. ' - Current items: ' .. vim.inspect(self.items))
end

--- Remove all instances of a particular value from the stack
--- @param val
function Stack:removeInstancesOf(val)
  self.count = 0
  local _items = {}
  for i, item in ipairs(self.items) do
    if item ~= val then 
      _items[#_items+1] = item
      self.count = self.count + 1
    end
  end
  self.items = _items
end

--- Remove the first item in the stack
--- @return integer?
function Stack:popFront() 
  if self.count == 0 then return end
  local _items = {}
  local front = self.items[1]
  self.count = 0
  for i, item in ipairs(self.items) do
    if i ~= 1 then
      _items[#_items+1] = item
      self.count = self.count + 1
    end
  end
  self.items = _items
  util.debug('Popped front item ' .. front .. ' - Current items: ' .. vim.inspect(self.items))
  return front
end

--- Add an item to the stack
--- @param item integer
function Stack:push(item) 
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


--- TabNum -> Stack of most recent buffers
M.LAST_BUFS = {}
function M.deserialize(bufsMap)
  local deserialized = {}
  local bufNrs = util.getBufsByName()
  util.debug('BUF NAMES:\n' .. vim.inspect(bufNrs))
  for tabNr, bufNames in pairs(bufsMap) do 
    local bufs = {}
    if bufNames ~= nil and bufNames ~= vim.NIL then
      util.debug('DESERIALIZING BUF NAMES FOR TAB ' .. tabNr .. ': ' .. vim.inspect(bufNames) .. '(' .. type(bufNames) .. ')')
      for i, bufName in ipairs(bufNames) do
        bufs[i] = bufNrs[bufName]
      end
      deserialized[tabNr] = Stack:new(999, bufs)
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


--- Record the current buffer in the last-buffer history
--- @param tabNr integer
--- @param bufNr integer
function M.updateLastBuf(tabNr, bufNr) 
  if not vim.bo[bufNr].buflisted then
    return
  end
  if M.LAST_BUFS[tabNr] == nil then
    util.debug('Setting up LAST_BUFS object for tabNr ' .. tabNr)
    M.LAST_BUFS[tabNr] = Stack:new(999)
  end

  local lastBuf
  lastBuf = M.LAST_BUFS[tabNr]
  local bufName = vim.api.nvim_buf_get_name(bufNr)
  if bufName ~= nil then
    local origName = bufName
    bufName = bufName:match("([^\\]+)$") 
    if bufName == nil or bufName == "" then bufName = origName end
    util.debug('Pushing buf number ' .. bufNr .. ' (name=' .. (bufName or 'nil') .. ') to tab ' .. tabNr)
    lastBuf:push(bufNr)
  end
end

--- Retrieve the most recently touched buffer for a given tab
--- @param tabNr integer
function M.getLastBuf(tabNr)
  local lastBuf = M.LAST_BUFS[tabNr]
  util.debug('Last buf exists? ' .. (lastBuf == nil and 'no' or 'yes'))
  return lastBuf and lastBuf.items[1]
end

--- Delete the buffer in the current window, preserving the window itself
--- Cycle back to the most recently touched buffer
--- @param force boolean
function M.smartDelete(force) 
  if vim.o.filetype == 'Terminal' then
    vim.notify('Do not close terminal buffers with bdelete - exit the terminal process explicitly', vim.log.levels.WARN)
    return
  end

  local currBuf = api.nvim_get_current_buf()

  local tab = vim.api.nvim_tabpage_get_number(0)
  util.debug('Smart-deleting current buf: ' .. currBuf .. '(current tab = ' .. tab .. ')')

  local recentBufs = M.LAST_BUFS[tab]
  if recentBufs ~= nil then 
    util.debug('POPPING FRONT')
    local front = recentBufs:popFront()
    recentBufs:removeInstancesOf(front) -- remove duplicates - we can't cycle back to a buffer we just closed
    local lastBuf = M.getLastBuf(tab)
    util.debug('Last buf: ' .. (lastBuf or 'nil'))
    vim.api.nvim_win_set_buf(0, lastBuf)
  end
  vim.api.nvim_buf_delete(currBuf, {force=force})
end

--- Close the current window, but not if it is the last window in a tab 
--- (unless the force option is specified)
--- @param force boolean 
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
