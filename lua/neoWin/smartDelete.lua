local util = require('neoWin.util')
local api = vim.api
local Stack = require('neoWin.stack')
local LOGGER = require('neoWin.logger'):new('smartDelete')

local M = {}

--- Data structure for most-recently-touched buffers

--- TabNum -> Stack of most recent buffers
--- @type { [integer]: Stack } 
M.LAST_BUFS = {}

function M.deserialize(bufsMap)
  local logger = LOGGER:withAttrs({logMethod="deserialize"})
  local deserialized = {}
  local bufNrs = util.getBufsByName()
  logger:debug('BUF NAMES:\n' .. vim.inspect(bufNrs))
  for tabNr, bufNames in pairs(bufsMap) do 
    local bufs = {}
    if bufNames ~= nil and bufNames ~= vim.NIL then
      logger:debug('DESERIALIZING BUF NAMES FOR TAB ' .. tabNr .. ': ' .. vim.inspect(bufNames) .. '(' .. type(bufNames) .. ')')
      for i, bufName in ipairs(bufNames) do
        bufs[i] = bufNrs[bufName]
      end
      logger:debug('DESERIALIZING STACK FOR TAB ' .. tabNr)
      deserialized[tabNr] = Stack:new(999, bufs)
    end
  end
  M.LAST_BUFS = deserialized
  for tabNr, lastBuf in pairs(M.LAST_BUFS) do
    logger:debug('DESERIALIZED SESSION (tab ' .. tabNr .. '): ' .. vim.inspect(lastBuf:toArray()) .. '')
  end
  vim.fn.writefile({vim.inspect(M.LAST_BUFS)}, 'C:\\Users\\RC12664\\Repos\\neoWin\\deserialized')

  for _, tabNum in pairs(vim.api.nvim_list_tabpages()) do
    M.resetMissing(tabNum)
  end
  M.removeUnloaded()
end

function M.serialize() 
  local serialized = {}
  local openBufs = util.openBufs()
  for tabNr, lastBuf in pairs(M.LAST_BUFS) do 
    local bufNames = {}
    for i, bufNr in ipairs(lastBuf:toArray()) do 
      if openBufs[bufNr] ~= nil and vim.api.nvim_buf_is_loaded(bufNr) then
        bufNames[i] = vim.api.nvim_buf_get_name(bufNr)
      end
    end
    serialized[tabNr] = bufNames
  end
  return serialized
end


function M.removeUnloaded()
  local logger = LOGGER:withAttrs({logMethod="removeUnloaded"});
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if not vim.api.nvim_buf_is_loaded(buf) then
      local bufName = vim.api.nvim_buf_get_name(buf)
      logger:debug('Found unloaded buffer ' .. buf .. ' ("' .. bufName .. ')" - deleting it')
      vim.api.nvim_buf_delete(buf, {force=true})
    end
  end
end

--- Identify any open bufs which are not currently in the smartDelete history,
--- and add them to the end. This is meant to recover from corrupted states
--- (which shouldn't exist in the first place, but c'est la vie)
--- @param tabId integer?
function M.resetMissing(tabId)
  local logger = LOGGER:withAttrs({logMethod="resetMissing"})
  tabId = tabId or vim.api.nvim_get_current_tabpage()
  local tabNum = vim.api.nvim_tabpage_get_number(tabId)
  logger:debug('Resetting missing buffers for tab ' .. tabNum)
  local lastBuf = M.LAST_BUFS[tabNum]
  if lastBuf == nil then
    lastBuf = Stack:new(999)
    M.LAST_BUFS[tabNum] = lastBuf
  end
  local bufNames = {}
  for i, bufNr in ipairs(lastBuf:toArray()) do 
    bufNames[i] = vim.api.nvim_buf_get_name(bufNr)
  end

  local tabCwd = vim.fn.getcwd(-1, tabId)
  logger:debug('CWD for tab #' .. tabNum .. ': ' .. tabCwd)

  local actualBufs = vim.api.nvim_list_bufs()
  for _, buf in ipairs(actualBufs) do

    if not vim.tbl_contains(lastBuf:toArray(), buf) and vim.bo[buf].buflisted then
      local bufName = vim.api.nvim_buf_get_name(buf)
      local cwdPrefix = bufName:sub(1, tabCwd:len())
      logger:debug('CWD Prefix for "' .. bufName .. '": ' .. cwdPrefix)
      if cwdPrefix == tabCwd then
        logger:debug('Buf ' .. buf .. '("' .. bufName .. '") is not present in smartDelete history')
        lastBuf:addToEnd(buf)
      end
    end
  end
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
    bufName = bufName:match("([^\\/]+)$") 
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


--- Force-reset the touched-buffer history for a tab
--- @param tabNr integer?
function M.resetLastBufs(tabNr)
  tabNr = tabNr or vim.api.nvim_get_current_tabpage()
  local bufs = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do 
    if not vim.bo[buf].bufhidden then
      bufs[#bufs+1] = buf
    end
  end
  M.LAST_BUFS[tabNr] = Stack:new(999, bufs)
end



--- @param force boolean?
--- @param bufnr integer
--- @param cycleWindowBuf boolean
--- @param unlist boolean?
function M.smartDeleteBuffer(force, bufnr, cycleWindowBuf, unlist) 
  local logger = LOGGER:withAttrs({logMethod="smartDeleteBuffer"})

  if vim.o.filetype == 'Terminal' then
    vim.notify('Do not close terminal buffers with bdelete - exit the terminal process explicitly', vim.log.levels.WARN)
    return
  end

  local tab = vim.api.nvim_tabpage_get_number(0)
  logger:debug('Smart-deleting current buf: ' .. bufnr .. '(current tab = ' .. tab .. ')')

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

  -- local front = recentBufs:popFront()
  recentBufs:removeInstancesOf(bufnr) -- remove duplicates - we can't cycle back to a buffer we just closed
  logger:debug('Current Items (after removal): ' .. vim.inspect(recentBufs:toArray()) .. ' (count = ' .. recentBufs.count .. ')')

  -- Find any windows which currently have the buffer-to-delete in focus
  -- Set the new buffer for each of those windows to be the next in the delete history  
  -- This way we never close the buffer of a window which is currently open, thereby closing the window itself
  --
  local lastBuf = M.getLastBuf(tab)
  logger:debug('Last buf: ' .. (lastBuf or 'nil'))

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local winBuf = vim.api.nvim_win_get_buf(win)
    if cycleWindowBuf and winBuf == bufnr then
      logger:debug("Found window attached to buffer that we're deleting: " .. win)
      if lastBuf ~= nil then
        logger:debug('Setting window ' .. win .. ' buffer to ' .. lastBuf)
      vim.api.nvim_win_set_buf(win, lastBuf)
      end
    end
  end

  if unlist then
    logger:debug('Unlisting buffer ' .. bufnr)
    vim.bo[bufnr].buflisted = false
  else
    logger:debug('Deleting buffer ' .. bufnr)
    vim.api.nvim_buf_delete(bufnr, {force=force})
  end
end



--- Delete the buffer in the current window, preserving the window itself
--- Cycle back to the most recently touched buffer
--- @param force boolean?
function M.smartDelete(force) 
  local currBuf = vim.api.nvim_get_current_buf()
  return M.smartDeleteBuffer(force, currBuf, true)
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
