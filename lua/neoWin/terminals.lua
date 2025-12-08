local util = require('neoWin.util')
local winSizing = require('neoWin.winSizing')
local api = vim.api

local pathSep = package.config:sub(1,1)
local isWindows = pathSep == '\\'
local shell = isWindows and 'powershell' or os.getenv('SHELL')

--- Open a terminal buffer in the current window
local function makeTerm()
    return vim.cmd('e term://' .. shell)
end


local function termName(termIndex)
  -- local prefix = "(" .. util.getTabName() .. ")"
  return 'Terminal ' .. termIndex
end

--- Terminal Buffer Metadata
---@class TermBuffer
---@field focused boolean When Terminals are toggled, is this terminal in view?
---@field name string Name of the buffer
---@field bufNr integer Buffer ID
---@field index integer Terminal Index (the i'th Terminal)
---@field tabNum integer Tab to which this terminal belongs

--- Terminals API Class (tab-scoped)
--- Create/delete terminals, 
--- toggle the terminal window pane,
--- switch between and rename terminals
---@class Terminals
---@field numTerms number Current count of terminals
---@field bufs table<integer, TermBuffer> Map of terminal buffers by their index
---@field bufsById table<integer, TermBuffer> Map of terminal buffers by their ID
---@field toggled boolean Is the terminal pane toggled?
---@field tabNum integer Tab to which this terminal API belongs
local Terminals = {}

function Terminals:new(tabNum)
  local instance = {
    tabNum = tabNum,
    numTerms = 0,
    bufs = {},
    bufsById = {},
    recent=nil,
    toggled=false,
  }
  self.__index = self
  setmetatable(instance, self)
  return instance
end

--- Create a new Terminal
function Terminals:createTerm()
  self.numTerms = self.numTerms + 1
  -- util.debug('Set numTerms to ' .. self.numTerms)
  local newBuf = api.nvim_create_buf(false, false)
  local name = termName(self.numTerms)
  api.nvim_buf_call(newBuf, makeTerm)
  api.nvim_set_option_value('filetype', 'Terminal', {buf=newBuf})
  api.nvim_set_option_value('buflisted', false, {buf=newBuf})
  -- util.debug('Setting terminal buffer ' .. newBuf .. ' name to ' .. name)
  api.nvim_buf_set_name(newBuf, name)
  local buf = {
    focused = true,
    name = name,
    bufNr = newBuf,
    index = self.numTerms,
    tabNum = self.tabNum
  }
  self.bufs[self.numTerms] = buf
  self.bufsById[buf.bufNr] = buf
  util.debug('Created terminal ' .. self.numTerms .. ' for buffer ' .. buf.bufNr)
end


---Create and attach a new terminal window
function Terminals:newTerm()
  -- util.debug('Creating terminal')
    self:createTerm()
    self:attach(self.numTerms)
end


--- Rename a terminal buffer
function Terminals:renameTerm(termIndex)
    termIndex = termIndex or self.recent
    local newName = vim.fn.input('New name for ' .. self.bufs[termIndex].name .. ': ')
    api.nvim_buf_set_name(self.bufs[termIndex].bufNr, newName)
    self.bufs[termIndex].name = newName
end


--- Debug - show the current state of the terminal buffers
function Terminals:show()
    print(vim.inspect(self.bufs))
end


--- Attach a terminal buffer to the terminal pane
--- (add a new window containing the terminal buffer)
function Terminals:attach(termIndex)
    util.debug('Attaching terminal ' .. (vim.inspect(termIndex) or 'nil'))
    self.toggled = true
    termIndex = termIndex or self.recent
    local buf = self.bufs[termIndex]

    -- If the terminal is attached already, just focus it
    local winBuf = self:getWindowId(termIndex)
    if winBuf ~= nil then
      util.debug('Terminal #' .. termIndex .. ' is already attached to window ' .. winBuf .. '- focusing the window...') 
      buf.focused = true 
      api.nvim_set_current_win(winBuf)
      return
    end

    -- If we have *another* terminal window focused already,
    -- then vsplit with that terminal window before focusing the existing term.
    -- Otherwise, hsplit a new terminal to the top.
    local visibleTermWin = self:firstWindowId() 
    if visibleTermWin ~= nil then
      local currWin = api.nvim_get_current_win()
      api.nvim_set_current_win(visibleTermWin)
      vim.cmd('vsplit')
      vim.api.nvim_set_current_win(currWin)
    else
      vim.cmd('topleft split')

      -- Schedule this, in case we want to call newTerm within window-related autocommand callbacks 
      -- the resize gets overridden by default vim stuff that might be happening in relation to the autocommand
      vim.schedule(function()
        local lines = vim.o.lines
        local toResize = .25 * lines
        util.debug('Resizing terminal ' .. termIndex .. ' to size ' .. toResize)
        vim.cmd('resize ' .. toResize)
      end)
    end

    -- At this point you're residing in the window that should hold the new term
    -- So we just assign the terminal buffer to window-0
    buf.focused = true
    util.debug('Setting current-window buffer to ' .. buf.bufNr)
    api.nvim_win_set_buf(0, buf.bufNr)
    self.recent = termIndex
    -- scroll to bottom of terminal 
    vim.cmd('goto 99999999')
end


--- Toggle the terminal pane at the top of the buffer
function Terminals:toggle()
  self:refresh()
  if self.numTerms == 0 then
    util.debug('Creating new term (nothing to toggle on)')
    self:newTerm()
    self.toggled = true
    return
  end

  -- toggle on
  if not self.toggled then
    local found = false
    self.toggled = true
    for index, buf in pairs(self.bufs) do
      if buf.focused then
        found = true
        -- util.debug('Attaching terminal ' .. index)
        self:attach(index)
      end
    end

    -- fallback - attach the most recently focused terminal 
    if not found then
      self:attach()
    end

  -- toggle off
  else
    self.toggled = false
    local winBufs = util.windowBufs()
    for bufId, winId in pairs(winBufs) do
      if self.bufsById[bufId] ~= nil then
        api.nvim_win_close(winId, true)
      end
    end
  end
end


--- Delete the local record of a terminal buffer (specified by its index)
--- Defalt to the most recently open terminal
--- @param termIndex integer
function Terminals:delete(termIndex)
  util.debug('Deleting terminal ' .. termIndex)
  termIndex = termIndex or self.recent
  self.numTerms = self.numTerms - 1
  local buf = self.bufs[termIndex]
  table.remove(self.bufs, termIndex)
  table.remove(self.bufsById, buf.bufNr)
  local ok, _ = pcall(api.nvim_buf_delete(buf.bufNr, {force=true}))

  -- Rename remaining default-named terminals
  self:renameDefaults()
end


--- Cycle the current window's terminal buffer
--- @param plus boolean true for right, false for left
function Terminals:cycleTerm(plus)
  if self.numTerms == 0 then return end
  local thisBuf = api.nvim_get_current_buf()
  local bufIndex = self.bufsById[thisBuf].index
  local offset = plus and 1 or -1
  local wrapAround = plus and 1 or #self.bufs
  local nextBuf = self.bufs[bufIndex+offset] or self.bufs[wrapAround]
  api.nvim_win_set_buf(0, nextBuf.bufNr)
  util.debug('Setting current (cycleTerm())')
  self:refresh()
end


--- Cycle the current terminal window to the next terminal buffer 
function Terminals:nextTerm()
  self:cycleTerm(true)
end


--- Cycle the current terminal window to the previous terminal buffer 
function Terminals:prevTerm()
  self:cycleTerm(false)
end


--- Check if a terminal at index {termIndex} is currently in view
--- if it is, return its window ID 
function Terminals:getWindowId(termIndex)
  util.debug('Getting window ID for terminal # ' .. termIndex)
  local buf = self.bufs[termIndex]
  if buf == nil then return nil end

  util.debug('Terminal Buf:', buf)
  local winBufs = util.windowBufs()

  local winId = winBufs[buf.bufNr]
  util.debug('Terminal #' .. termIndex .. ' Buffer=' .. buf.bufNr .. ', Window=' .. (winId or 'nil'))
  return winId
end


--- Grab the first in-view terminal's window id.
--- Serves as a quick check to see if at least one terimnal is visible 
function Terminals:firstWindowId()
  for i = 1,self.numTerms do
    local win = self:getWindowId(i)
    if win ~= nil then return win end
  end
end


--- Refresher function to track the terminal which most recently held the cursor
function Terminals:setRecent()
  local thisBuf = api.nvim_get_current_buf()

  if self.bufsById[thisBuf] ~= nil then
    self.recent = self.bufsById[thisBuf].index
    util.debug('Set recent terminal-buffer index to ' .. self.recent)
  end
end


--- Refresher function to track the state of the terminals and perform periodic cleanup
function Terminals:cleanup()
  local openBufs = util.openBufs()
  for index, buf in pairs(self.bufs) do
    if openBufs[buf.bufNr] == nil then
      self:delete(index)
    end
  end
end


--- Refresher function to track the focus of the terminals
--- If any terminal is in view, mark it as focused
--- (so that on the next toggle-on, a window is opened for this terminal)
function Terminals:setFocus()
  local visibleTermWin = self:firstWindowId() 
  if not self.toggled then
    return
  end
  if visibleTermWin == nil then
    return
  end

  for index, buf in pairs(self.bufs) do
    local winId = self:getWindowId(index)
    if winId == nil then
      buf.focused = false
    else
      buf.focused = true
    end
  end
end


---Refresh function to rename the default-named buffers 
---Prefix with the tab index / name
function Terminals:renameDefaults()
  local namePat = '^Terminal %d+$'
  for index, buf in pairs(self.bufs) do
    if string.match(buf.name, namePat) then
      local baseName = termName(index)
      if buf.name == baseName then
        local newName = "(" .. util.getTabName(buf.tabNum) .. ") " .. baseName
        api.nvim_buf_set_name(buf.bufNr, newName)
      end
    end
  end
end


--- Refresh the terminal state
function Terminals:refresh()
  self:cleanup()
  self:setRecent()
  self:setFocus()
  self:renameDefaults()
end


local tabMap = {}
local M = {}

--- Create a Terminals API for a tab
function M.registerTab(tabNum)
  -- util.debug('Registering tab ' .. tabNum)
  local newTerminalsApi = Terminals:new(tabNum)
  tabMap[tabNum] = newTerminalsApi
  return newTerminalsApi
end

--- Delete the Terminals API for a tab (ie. after deleting that tab)
function M.deregisterTab(tabNum)
  tabMap[tabNum] = nil
end

--- Get (or create, if necessary) the Terminals API for the active tab
local function getTerminalsApi()
    local tabNum = vim.api.nvim_get_current_tabpage()
    local terminals = tabMap[tabNum]
    if terminals == nil then
      -- util.debug('Registering terminals API for tab ' .. tabNum)
      terminals = M.registerTab(tabNum)
    end
    return terminals
end

--- Create a wrapped version of a Terminals API method
--- which automatically calls the relevant Terminals API instance for the active tab
local function wrapForTab(func)
  local wrapped = function(...) 
    local terminals = getTerminalsApi()
    return func(terminals, ...)
  end
  return wrapped
end

M.createTerm    =  wrapForTab(Terminals.createTerm)
M.newTerm       =  wrapForTab(Terminals.newTerm)
M.renameTerm    =  wrapForTab(Terminals.renameTerm)
M.show          =  wrapForTab(Terminals.show)
M.attach        =  wrapForTab(Terminals.attach)
M.toggle        =  wrapForTab(Terminals.toggle)
M.delete        =  wrapForTab(Terminals.delete)
M.cycleTerm     =  wrapForTab(Terminals.cycleTerm)
M.nextTerm      =  wrapForTab(Terminals.nextTerm)
M.prevTerm      =  wrapForTab(Terminals.prevTerm)
M.getWindowId   =  wrapForTab(Terminals.getWindowId)
M.firstWindowId =  wrapForTab(Terminals.firstWindowId)
M.setRecent     =  wrapForTab(Terminals.setRecent)
M.cleanup       =  wrapForTab(Terminals.cleanup)
M.setFocus      =  wrapForTab(Terminals.setFocus)
M.refresh       =  wrapForTab(Terminals.refresh)

--- Get the current map of terminal buffers
--- @param localTab boolean? Should the results be tab-local?
function M.getTerminalBufs(localTab)
  if localTab then
    local terminals = getTerminalsApi()
    return terminals.bufs
  else
    local bufs = {}
    for tabWin, terminals in pairs(tabMap) do
      for _, buf in ipairs(terminals.bufs) do
        bufs[#bufs+1] = buf
      end
    end
    return bufs
  end
end

--- Get the current map of terminal buffers
--- @param localTab boolean? Should the results be tab-local?
function M.getTerminalBufsById(localTab)
  if localTab then
    local terminals = getTerminalsApi()
    return terminals.bufsById
  else
    local bufs = {}
    for tabWin, terminals in pairs(tabMap) do
      for bufId, buf in pairs(terminals.bufsById) do
        bufs[bufId] = buf
      end
    end
    return bufs
  end
end

return M
