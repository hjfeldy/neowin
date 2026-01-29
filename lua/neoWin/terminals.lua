local util = require('neoWin.util')
local settings = require('neoWin.settings')
local api = vim.api
local Logger = require('neoWin.logger')
local Stack = require('neoWin.stack')

local pathSep = package.config:sub(1,1)
local isWindows = pathSep == '\\'
local shell = isWindows and 'powershell' or os.getenv('SHELL') or "bash"


local function termName(termIndex)
  -- local prefix = "(" .. util.getTabName() .. ")"
  return 'Terminal ' .. termIndex
end

--- Terminal Buffer Metadata
---@class TermBuffer
---@field channel integer the channel ID of the shell job
---@field focused boolean When Terminals are toggled, is this terminal in view?
---@field name string Name of the buffer
---@field bufNr integer Buffer ID
---@field index integer Terminal Index (the i'th Terminal)
---@field tabNum integer Tab to which this terminal belongs
local TermBuffer = {}

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
---@field recent Stack most recently viewed buffers 
local Terminals = {
  logger = Logger:new("Terminals")
}


--- Open a terminal buffer in the current window
local function makeTerm()
  local logger = Logger:new('Terminals'):withAttrs({logMethod="makeTerm"})
  -- vim.cmd('e term://' .. shell)
  local env = settings.CONF.env or {}
  if settings.CONF.useDotenv then
    env = vim.tbl_extend('force', env, util.dotEnv() or {}) 
  end
  local jobOpts = {term=true, pty=true}
  if not vim.tbl_isempty(env) then
    jobOpts.env = env
  end

  local chanId = vim.fn.jobstart(shell, jobOpts)
  local name = vim.api.nvim_buf_get_name(0)
  logger:debug('Default name: ' .. name)
  return chanId
end


---@return Terminals
function Terminals:new(tabNum)
  local instance = {
    tabNum = tabNum,
    numTerms = 0,
    bufs = {},
    bufsById = {},
    recent=Stack:new(999),
    toggled=false,
  }
  self.__index = self
  setmetatable(instance, self)
  return instance
end

function Terminals:nextTermIndex()
  local logger = self.logger:withAttrs({logMethod="nextTermIndex"});
  local termIndex = 0
  for i, buf in ipairs(self.bufs) do
    termIndex = i
    if buf.index > termIndex then
      logger:debug('Found gap at terminal index ' .. buf.index)
      return termIndex
    end
  end
  logger:debug('No gaps - setting termIndex ' .. (termIndex+1))
  return termIndex+1
end


--- Create a new Terminal
function Terminals:createTerm()
  local logger = self.logger:withAttrs({logMethod="createTerm"})
  self:refresh()
  self.numTerms = self.numTerms + 1
  logger:debug('Set numTerms to ' .. self.numTerms)

  local newBuf = api.nvim_create_buf(false, false)
  local nextIndex = self:nextTermIndex()
  logger:debug('Creating terminal #' .. nextIndex)
  local name = 'Terminal ' .. nextIndex
  local fullName = "(" .. util.getTabName(self.tabNum) .. ") " .. name
  local chanId = api.nvim_buf_call(newBuf, makeTerm)

  api.nvim_set_option_value('filetype', 'Terminal', {buf=newBuf})
  api.nvim_set_option_value('buflisted', false, {buf=newBuf})
  self.logger:debug('Setting terminal buffer ' .. newBuf .. ' name to ' .. name)
  api.nvim_buf_set_name(newBuf, fullName)
  local buf = {
    -- pid = pid,
    channel=chanId,
    focused = true,
    name = fullName,
    bufNr = newBuf,
    index = nextIndex,
    tabNum = self.tabNum
  }
  self.bufs[self.numTerms] = buf
  self.bufsById[buf.bufNr] = buf
  logger:debug('Created terminal ' .. self.numTerms .. ' for buffer ' .. buf.bufNr)
  self:refresh()
  -- self:sendKeys(nextIndex, '. ./.env')
end

---@param termIndex integer
---@param keys string
function Terminals:sendKeys(termIndex, keys)
  local buf = self.bufs[termIndex]
  local chanId = vim.bo[buf.bufNr].channel
  vim.api.nvim_chan_send(chanId, keys)
end


---Create and attach a new terminal window
function Terminals:newTerm()
  local logger = self.logger:withAttrs({logMethod='newTerm'})
  self:refresh()
  logger:debug('Creating terminal')
  local nextIndex = self:nextTermIndex()
  self:createTerm()
  self:attach(nextIndex)
  self:refresh()
end


--- Rename a terminal buffer
function Terminals:renameTerm(termIndex)
  if termIndex == nil then
    local currBuf = vim.api.nvim_get_current_buf()
    local buf = self.bufsById[currBuf]
    if buf == nil then
      vim.notify('Unable to find terminal for buffer ' .. currBuf, vim.log.levels.ERROR)
      return
    end
    termIndex = buf.index
  end
  local newName = vim.fn.input('New name for ' .. self.bufs[termIndex].name .. ': ')
  local prefix = "(" .. util.getTabName(self.tabNum) .. ")"
  local fullName = prefix .. ' ' .. newName
  api.nvim_buf_set_name(self.bufs[termIndex].bufNr, fullName)
  self.bufs[termIndex].name = fullName
end


--- Debug - show the current state of the terminal buffers
function Terminals:show()
    print(vim.inspect(self.bufs))
end


--- Attach a terminal buffer to the terminal pane
--- (add a new window containing the terminal buffer)
function Terminals:attach(termIndex)
    local logger = self.logger:withAttrs({logMethod='attach'})
    logger:debug('Attaching terminal ' .. (vim.inspect(termIndex) or 'nil'))
    self.toggled = true
    termIndex = termIndex or self.recent.head.val
    local buf = self.bufs[termIndex]
    while buf == nil and termIndex ~= nil and self.recent.count > 0 do
      self.recent:removeInstancesOf(termIndex)
      termIndex = self.recent.head.val
      buf = self.bufs[termIndex]
    end
    if buf == nil and #self.bufs > 0 then
      logger:debug("Recent buffer was deleted - falling back to most recently created buffer")
      buf = self.bufs[#self.bufs]
    end

    -- If the terminal is attached already, just focus it
    local winBuf = self:getWindowId(termIndex)
    if winBuf ~= nil then
      logger:debug('Terminal #' .. termIndex .. ' is already attached to window ' .. winBuf .. '- focusing the window...')
      buf.focused = true
      api.nvim_set_current_win(winBuf)
      return
    end

    -- If we have *another* terminal window focused already,
    -- then vsplit with that terminal window before focusing the existing term.
    -- Otherwise, hsplit a new terminal to the top.
    local visibleTermWin = self:lastWindowId()
    if visibleTermWin ~= nil then
      api.nvim_set_current_win(visibleTermWin)
      vim.cmd('vsplit')
      vim.cmd('wincmd l')
    else
      vim.cmd('topleft split')

      -- Schedule this, in case we want to call newTerm within window-related autocommand callbacks 
      -- the resize gets overridden by default vim stuff that might be happening in relation to the autocommand
      vim.schedule(function()
        local lines = vim.o.lines
        local toResize = .25 * lines
        logger:debug('Resizing terminal ' .. termIndex .. ' to size ' .. toResize)
        vim.cmd('resize ' .. toResize)
      end)
    end

    if buf ~= nil then 
      -- At this point you're residing in the window that should hold the new term
      -- So we just assign the terminal buffer to window-0
      buf.focused = true
      logger:debug('Setting current-window buffer to ' .. buf.bufNr)
      api.nvim_win_set_buf(0, buf.bufNr)
      self.recent:add(termIndex)
      -- scroll to bottom of terminal 
      vim.cmd('goto 99999999')

      local termHL = vim.api.nvim_get_hl(0, {name='Terminal'})
      if not vim.tbl_isempty(termHL) then
        vim.wo[0].winhighlight = 'Normal:Terminal'
      end
    end

end


--- Toggle the terminal pane at the top of the buffer
function Terminals:toggle()
  local logger = self.logger:withAttrs({logMethod="toggle"})
  self:refresh()
  if self.numTerms == 0 then
    logger:debug('Creating new term (nothing to toggle on)')
    self:newTerm()
    self.toggled = true
    return
  end

  local visibleTermWin = self:lastWindowId()

  -- toggle on
  if visibleTermWin == nil then
    local found = false
    self.toggled = true
    for index, buf in pairs(self.bufs) do
      if buf.focused then
        found = true
        logger:debug('Attaching terminal ' .. index)
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
    for winId, bufId in pairs(winBufs) do
      if self.bufsById[bufId] ~= nil then
        api.nvim_win_close(winId, true)
      end
    end
  end
end


function Terminals:deleteMissing()
  local logger = self.logger:withAttrs({logMethod="deleteMissing"})
  local openBufs = util.openBufs()
  local offset = 0
  for termIndex = 1,#self.bufs do
  -- for termIndex, buf in ipairs(self.bufs) do
    local buf = self.bufs[termIndex-offset]
    if openBufs[buf.bufNr] == nil then
      logger:debug("Buffer " .. buf.bufNr .. " is not open - clearing record of it")
      table.remove(self.bufs, termIndex-offset)
      table.remove(self.bufsById, buf.bufNr)
      offset = offset+1
      self.numTerms = self.numTerms - 1
    end
  end
  -- Rename remaining default-named terminals
  self:renameDefaults()
end


--- Cycle the current window's terminal buffer
--- @param plus boolean true for right, false for left
function Terminals:cycleTerm(plus)
  local logger = self.logger:withAttrs({logMethod="cycleTerm"})
  local direction = plus and "forwards" or "backwards"
  logger:debug('Cycling terminal ' .. direction)

  if self.numTerms == 0 then return end
  local thisBuf = api.nvim_get_current_buf()
  -- local termBuf = self.bufsById[thisBuf]
  -- the "index" field of the TermBuffer may not actually be the true array index 
  -- (ie. if we have terminals 1,2,3 and then delete terminal 2,
  -- then "terminal 3" is the *2nd* terminal)
  local thisBufTermIndex = 0
  for termIndex, buf in ipairs(self.bufs) do
    if buf.bufNr == thisBuf then
      thisBufTermIndex = termIndex
    end
  end
  if thisBufTermIndex == 0 then
    logger:error("Could not find this terminal's index!")
    return
  end

  -- local bufIndex = self.bufsById[thisBuf].index
  local offset = plus and 1 or -1
  local wrapAround = plus and 1 or #self.bufs
  local nextBuf = self.bufs[thisBufTermIndex+offset] or self.bufs[wrapAround]
  api.nvim_win_set_buf(0, nextBuf.bufNr)
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
  local logger = self.logger:withAttrs({logMethod="getWindowId"})
  logger:debug('Getting window ID for terminal # ' .. termIndex)
  local buf = self.bufs[termIndex]
  if buf == nil then return nil end

  logger:debug('Terminal Buf:', buf)
  local winBufs = util.windowBufs()
  local bufWins = {}
  for winId, bufId in pairs(winBufs) do 
    bufWins[bufId] = winId
  end

  local winId = bufWins[buf.bufNr]
  logger:debug('Terminal #' .. termIndex .. ' Buffer=' .. buf.bufNr .. ', Window=' .. (winId or 'nil'))
  if winId == nil then
    logger:debug('No window for terminal ' .. termIndex .. ' (buffer ' .. buf.bufNr .. ')')
  end
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

function Terminals:lastWindowId()
  for i = self.numTerms,1,-1 do
    local win = self:getWindowId(i)
    if win ~= nil then return win end
  end
end


--- Refresher function to track the terminal which most recently held the cursor
function Terminals:setRecent()
  local logger = self.logger:withAttrs({logMethod="setRecent"})
  local thisBuf = api.nvim_get_current_buf()

  if self.bufsById[thisBuf] ~= nil then
    self.recent:add(self.bufsById[thisBuf].index)
    logger:debug('Set recent terminal-buffer index to ' .. self.recent.head.val)
  end
end



--- Refresher function to track the focus of the terminals
--- If any terminal is in view, mark it as focused and all other as non-focused
--- (so that on the next toggle-on, a window is opened for this terminal)
-- -@param excludeWindow integer? Optionally exclude 
function Terminals:setFocus()
  local visibleTermWin = self:firstWindowId()
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
  local openBufs = util.openBufs()
  for index, buf in pairs(self.bufs) do
    if string.match(buf.name, namePat) then
      local baseName = termName(index)
      if buf.name == baseName and openBufs[buf.bufNr] ~= nil then
        local newName = "(" .. util.getTabName(buf.tabNum) .. ") " .. baseName
        api.nvim_buf_set_name(buf.bufNr, newName)
      end
    end
  end
end


--- Refresh the terminal state
function Terminals:refresh()
  -- self:cleanup()
  self:deleteMissing()
  self:setRecent()
  self:setFocus()
  table.sort(self.bufs,
    function(buf, otherBuf)
      return buf.index < otherBuf.index
    end
  )

  -- self:renameDefaults()
end


---@type {[integer]: Terminals}
local tabMap = {}

local M = {}

--- Create a Terminals API for a tab
---@return Terminals
function M.registerTab(tabNum)
  local logger = Terminals.logger:withAttrs({logMethod="registerTab"})
  logger:debug('Registering tab ' .. tabNum)
  local newTerminalsApi = Terminals:new(tabNum)
  tabMap[tabNum] = newTerminalsApi
  return newTerminalsApi
end

--- Delete the Terminals API for a tab (ie. after deleting that tab)
function M.deregisterTab(tabNum)
  tabMap[tabNum] = nil
end

--- Get (or create, if necessary) the Terminals API for the active tab
---@return Terminals
function M.getTerminalsApi()
    local logger = Terminals.logger:withAttrs({logMethod="getTerminalsApi"})
    local tabNum = vim.api.nvim_get_current_tabpage()
    local terminals = tabMap[tabNum]
    if terminals == nil then
      logger:debug('Registering terminals API for tab ' .. tabNum)
      terminals = M.registerTab(tabNum)
    end
    return terminals
end

--- Create a wrapped version of a Terminals API method
--- which automatically calls the relevant Terminals API instance for the active tab
local function wrapForTab(func)
  local wrapped = function(...)
    local terminals = M.getTerminalsApi()
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
M.cycleTerm     =  wrapForTab(Terminals.cycleTerm)
M.nextTerm      =  wrapForTab(Terminals.nextTerm)
M.prevTerm      =  wrapForTab(Terminals.prevTerm)
M.getWindowId   =  wrapForTab(Terminals.getWindowId)
M.firstWindowId =  wrapForTab(Terminals.firstWindowId)
M.setRecent     =  wrapForTab(Terminals.setRecent)
M.setFocus      =  wrapForTab(Terminals.setFocus)
M.refresh       =  wrapForTab(Terminals.refresh)
M.sendKeys      =  wrapForTab(Terminals.sendKeys)


--- Get the current map of terminal buffers
--- @param localTab boolean? Should the results be tab-local?
function M.getTerminalBufs(localTab)
  if localTab then
    local terminals = M.getTerminalsApi()
    return terminals.bufs
  else
    local bufs = {}
    for _, terminals in pairs(tabMap) do
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
    local terminals = M.getTerminalsApi()
    return terminals.bufsById
  else
    local bufs = {}
    for _, terminals in pairs(tabMap) do
      for bufId, buf in pairs(terminals.bufsById) do
        bufs[bufId] = buf
      end
    end
    return bufs
  end
end

return M
