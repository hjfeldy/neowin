local api = vim.api
local Terminals = require('neoWin.terminals')
local winSizing = require('neoWin.winSizing')
local customPicker = require('neoWin.customPicker')
local util = require('neoWin.util')

--[[ Autocommands ]]
-- Whenever a window/buffer is closed through some user action external to this API,
-- we need to keep track of those changes (ie. delete terminals from the "bufs" and "bufsById" variables).
-- We also need to keep track of which terminal window was last focused 
for _, event in pairs({
  'TermClose',
  'BufWinEnter',
  'WinEnter',
  'WinLeave',
}) do
  api.nvim_create_autocmd(event, {
    pattern = {'*'},
    callback = function(ev)
      util.debug('Caught event ' .. event .. ' - setting current terminal')
      Terminals:setCurrent()
    end
  })
end

for _, event in pairs({'TermClose', 'WinNew'}) do
  api.nvim_create_autocmd(event, {
    pattern = {'*'},
    callback = function(ev)
      winSizing.winInfo()
    end
  })
end


--[[ User commands ]]
api.nvim_create_user_command('RenameTerm', function() Terminals:renameTerm() end, {})
api.nvim_create_user_command('NextTerm', function() Terminals:nextTerm() end, {})
api.nvim_create_user_command('PrevTerm', function() Terminals:prevTerm() end, {})
api.nvim_create_user_command('NewTerm', function() Terminals:newTerm()  end, {})
api.nvim_create_user_command('ShowTerms', function() Terminals:show() end, {})
api.nvim_create_user_command('ToggleTerm', function() Terminals:toggle() end, {}) 
api.nvim_create_user_command('ToggleZoom', winSizing.toggleZoom, {})
api.nvim_create_user_command('Terminals', customPicker.termPick, {})
