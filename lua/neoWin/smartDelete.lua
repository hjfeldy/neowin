local util = require('neoWin.util')
local api = vim.api
local Stack = require('neoWin.stack')

local M = {}

--- Data structure for most-recently-touched buffers

--- TabNum -> Stack of most recent buffers
--- @type { [integer]: Stack } 
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
      util.debug('DESERIALIZING STACK FOR TAB ' .. tabNr)
      deserialized[tabNr] = Stack:new(999, bufs)
    end
  end
  M.LAST_BUFS = deserialized
  for tabNr, lastBuf in pairs(M.LAST_BUFS) do
    util.debug('DESERIALIZED SESSION (tab ' .. tabNr .. '): ' .. vim.inspect(lastBuf:toArray()) .. '')
  end
  vim.fn.writefile({vim.inspect(M.LAST_BUFS)}, 'C:\\Users\\RC12664\\Repos\\neoWin\\deserialized')
end

function M.serialize() 
  local serialized = {}
  for tabNr, lastBuf in pairs(M.LAST_BUFS) do 
    local bufNames = {}
    for i, bufNr in ipairs(lastBuf:toArray()) do 
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
  if (lastBuf.head and lastBuf.head.val) == bufNr then
    util.debug("Refusing to push buffer " .. bufNr .. " to stack - it is already at the front")
    return
  end
  local bufName = vim.api.nvim_buf_get_name(bufNr)
  if bufName ~= nil and bufName ~= "" and bufName ~= '[No Name]' then
    local origName = bufName
    bufName = bufName:match("([^\\]+)$") 
    if bufName == nil or bufName == "" then bufName = origName end
    util.debug('Pushing buf number ' .. bufNr .. ' (name=' .. (bufName or 'nil') .. ') to tab ' .. tabNr .. ' - current head value = ' .. (lastBuf.head and lastBuf.head.val or 'nil'))
    lastBuf:add(bufNr)
    util.debug('Current Items (after push): ' .. vim.inspect(lastBuf:toArray()) .. ' (count = ' .. lastBuf.count .. ')')
  end
end


--- Retrieve the most recently touched buffer for a given tab
--- @param tabNr integer
function M.getLastBuf(tabNr)
  local lastBuf = M.LAST_BUFS[tabNr]
  util.debug('Last buf exists? ' .. (lastBuf == nil and 'no' or 'yes'))
  return lastBuf and lastBuf.head and lastBuf.head.val
end


function M.smartDeleteBuffer(force, bufnr) 
  if vim.o.filetype == 'Terminal' then
    vim.notify('Do not close terminal buffers with bdelete - exit the terminal process explicitly', vim.log.levels.WARN)
    return
  end

  local tab = vim.api.nvim_tabpage_get_number(0)
  util.debug('Smart-deleting current buf: ' .. bufnr .. '(current tab = ' .. tab .. ')')

  local recentBufs = M.LAST_BUFS[tab]
  if recentBufs == nil then 
    return vim.notify('No recent buffers for this tab! This is a bug!', vim.log.levels.WARN)
  end

  if vim.bo[bufnr].modified and not force then
    return vim.notify('Buffer has unwritten changes', vim.log.levels.WARN)
  end

  if recentBufs.count == 1 and not force then
    return vim.notify('This is tab ' .. tab .. "'s last buffer!", vim.log.levels.WARN)
  end

  util.debug('POPPING FRONT')
  -- local front = recentBufs:popFront()
  recentBufs:removeInstancesOf(bufnr) -- remove duplicates - we can't cycle back to a buffer we just closed
  util.debug('Current Items (after removal): ' .. vim.inspect(recentBufs:toArray()) .. ' (count = ' .. recentBufs.count .. ')')
  local lastBuf = M.getLastBuf(tab)
  util.debug('Last buf: ' .. (lastBuf or 'nil'))
  if lastBuf ~= nil then
    vim.api.nvim_win_set_buf(0, lastBuf)
  end
  vim.api.nvim_buf_delete(bufnr, {force=force})
end


--- Delete the buffer in the current window, preserving the window itself
--- Cycle back to the most recently touched buffer
--- @param force boolean?
function M.smartDelete(force) 
  return M.smartDeleteBuffer(force, vim.api.nvim_get_current_buf())
end

--- Close the current window, but not if it is the last window in a tab 
--- (unless the force option is specified)
--- @param force boolean? 
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
