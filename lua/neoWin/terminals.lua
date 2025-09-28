local util = require('neoWin.util')
local winSizing = require('neoWin.winSizing')
local api = vim.api

local pathSep = package.config:sub(1,1)
local isWindows = pathSep == '\\'
local shell = isWindows and 'powershell' or os.getenv('SHELL')

local function makeTerm()
    return vim.cmd('e term://' .. shell)
end

local M = {}


--- Terminal Buffer Metadata
---@class TermBuffer
---@field focused boolean When Terminals are toggled, is this terminal in view?
---@field name string Name of the buffer
---@field bufNr integer Buffer ID
---@field index integer Terminal Index (the i'th Terminal)

--- Terminals API Singleton Class
--- Manages which terminals show up in the Terminal pane,
--- and toggles the Terminal pane itself
---@class Terminals
---@field numTerms number Current count of terminals
---@field bufs table<integer, TermBuffer> Map of terminal buffers by their index
---@field bufsById table<integer, TermBuffer> Map of terminal buffers by their ID
---@field toggled boolean Is the terminal pane toggled?

local Terminals = {
  numTerms = 0,
  bufs = {},
  bufsById = {},
  recent=nil,
  toggled=false
}

function Terminals:new()
  local instance = {
    numTerms = 0,
    bufs = {},
    bufsById = {},
    recent=nil,
    toggled=false
  }
  setmetatable(instance, self)
  instance.__index = instance
end

--- Create a new Terminal
function Terminals:createTerm()
  self.numTerms = self.numTerms + 1
  local newBuf = api.nvim_create_buf(false, false)
  local name = 'Terminal ' .. self.numTerms
  api.nvim_buf_call(newBuf, makeTerm)
  api.nvim_set_option_value('filetype', 'Terminal', {buf=newBuf})
  api.nvim_set_option_value('buflisted', false, {buf=newBuf})
  api.nvim_buf_set_name(newBuf, name)
  local buf = {
    focused = true,
    name = name,
    bufNr = newBuf,
    index = self.numTerms
  }
  self.bufs[self.numTerms] = buf
  self.bufsById[buf.bufNr] = buf
  util.debug('Created terminal ' .. self.numTerms .. ' for buffer ' .. buf.bufNr)
end

--- Get the bufnumber of the first terminal window 
--- (used to determine whether >0 Terminals are in view)
function Terminals:termVisible()
  local winBufs = util.windowBufs()
  for _, buf in pairs(self.bufs) do
    if winBufs[buf.bufNr] ~= nil then
      return true
    end
  end
  return false
end

--- Set the currently occupied window as the current terminal buffer (if it is a terminal buffer)
--- Deletes the record of any terminals that were closed outside of the neoWin API (ie. via the terminal process exiting)
function Terminals:setCurrent()
  local thisBuf = api.nvim_get_current_buf()

  if self.bufsById[thisBuf] ~= nil then
    self.recent = self.bufsById[thisBuf].index
    util.debug('Set recent terminal-buffer index to ' .. self.recent)
  end

  local openBufs = util.openBufs()
  -- util.debug('Open buffers:', openBufs)
  -- util.debug('Termbuf records:', self.bufs)

  for index, buf in pairs(self.bufs) do
    if openBufs[buf.bufNr] == nil then
      util.debug('Terminal buffer ' .. buf.index .. ' (ID ' .. buf.bufNr .. ') does not exist - deleting the terminal record')
      self:delete(index)
    end
  end
end

function Terminals:setFocus(reason)
  util.debug('SETTING FOCUS - ' .. (reason or 'nil'))
  local visibleTermWin = self:firstWindowId() 
  if not self.toggled then
    util.debug('Terminal Pane is not toggled - aborting setFocus()')
    return
  end
  if visibleTermWin == nil then
    util.debug('No terminals are visible - aborting setFocus()')
    return
  end
  for index, buf in pairs(self.bufs) do
    util.debug('Getting window id for buf:', buf)
    local winId = self:getWindowId(index)
    util.debug('Window ID for terminal #' .. index .. ': ' .. (winId or 'nil'))
    if winId == nil then
      util.debug('Terminal ' .. index .. ' (Buffer ' .. buf.bufNr .. ') is not in view - marking it as unfocused')
      buf.focused = false
    else
      util.debug('Terminal ' .. index .. ' (Buffer ' .. buf.bufNr .. ') is in view - marking it as focused')
      buf.focused = true
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

  -- Rename remaining default-named terminals
  local namePat = '^Terminal %d+$'
  for index, buf in pairs(self.bufs) do
    if string.match(buf.name, namePat) then
      local newName = 'Terminal ' .. index
      buf.name = newName
      api.nvim_buf_set_name(buf.bufNr, newName)
    end
  end
end

--- Check if a terminal at index {termIndex} is currently in view
--- if it is, return its window ID 
function Terminals:getWindowId(termIndex)
  util.debug('Getting window ID for terminal # ' .. termIndex)
  local buf = self.bufs[termIndex]
  util.debug('Terminal Buf:', buf)
  local winBufs = util.windowBufs()

  local winId = winBufs[buf.bufNr]
  util.debug('Terminal #' .. termIndex .. ' Buffer=' .. buf.bufNr .. ', Window=' .. (winId or 'nil'))
  return winId
  end

function Terminals:firstWindowId()
  for i = 1,self.numTerms do
    local win = self:getWindowId(i)
    if win ~= nil then return win end
  end
end

---Create and attach a new terminal window
function Terminals:newTerm()
    self:createTerm()
    self:attach(self.numTerms)
end

function Terminals:attach(termIndex)
    util.debug('Attaching terminal ' .. (termIndex or 'nil'))
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
      local lines = vim.o.lines
      local toResize = .25 * lines
      vim.cmd('resize ' .. toResize)
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

function Terminals:cycleTerm(plus)
  if self.numTerms == 0 then return end
  local thisBuf = api.nvim_get_current_buf()
  local bufIndex = self.bufsById[thisBuf].index
  local offset = plus and 1 or -1
  local wrapAround = plus and 1 or #self.bufs
  local nextBuf = self.bufs[bufIndex+offset] or self.bufs[wrapAround]
  api.nvim_win_set_buf(0, nextBuf.bufNr)
  util.debug('Setting current (cycleTerm())')
  self:setCurrent()
  self:setFocus('cycleTerm')
end

--- Cycle the current terminal window to the next terminal buffer 
function Terminals:nextTerm()
  self:cycleTerm(true)
end


--- Cycle the current terminal window to the previous terminal buffer 
function Terminals:prevTerm()
  self:cycleTerm(false)
end


--- Toggle the terminal pane at the top of the buffer
function Terminals:toggle()
  util.debug('Setting current (toggle())')
  self:setCurrent()
  if self.numTerms == 0 then
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
        self:attach(index)
      end
    end

    -- fallback - attach the most recently focused terminal 
    if not found then
      self:attach()
    end

  -- toggle off
  else
    -- self:setFocus('toggle')
    self.toggled = false
    local winBufs = util.windowBufs()
    for bufId, winId in pairs(winBufs) do
      if self.bufsById[bufId] ~= nil then
        api.nvim_win_close(winId, true)
      end
    end
  end
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

local tabMap = {}

function M.registerTab(tabNum)
  util.debug('Registering tab ' .. tabNum)
  tabMap[tabNum] = Terminals:new()
end

function M.deregisterTab(tabNum)
  util.debug('Deregistering tab ' .. tabNum)
  tabMap[tabNum] = nil
end

function wrapForTab(func)
  local function wrapped()
    local terminals = tabMap[vim.api.nvim_get_current_tabpage()]
    func(terminals)
  end
  return wrapped
end

M.renameTerm = wrapForTab(Terminals.renameTerm)
M.nextTerm = wrapForTab(Terminals.nextTerm)
M.prevTerm = wrapForTab(Terminals.renameTerm)
M.newTerm = wrapForTab(Terminals.newTerm)
M.toggleTerm = wrapForTab(Terminals.toggleTerm)
M.showTerm = wrapForTab(Terminals.showTerm)

return M
