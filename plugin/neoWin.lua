local api = vim.api
local terminals = require('neoWin.terminals')
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
      terminals:refresh()
    end
  })
end

for _, event in pairs({
  -- 'TermClose',
  'WinEnter',
  -- 'WinLeave',
  -- 'WinNew',
}) do
  api.nvim_create_autocmd(event, {
    pattern = {'*'},
    callback = function(ev)
      util.debug('Caught event ' .. event .. ' - setting current terminal')
      terminals:refresh()
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
api.nvim_create_user_command('RenameTerm', function() terminals.renameTerm() end, {})
api.nvim_create_user_command('NextTerm', function() terminals.nextTerm() end, {})
api.nvim_create_user_command('PrevTerm', function() terminals.prevTerm() end, {})
api.nvim_create_user_command('NewTerm', function() terminals.newTerm()  end, {})
api.nvim_create_user_command('ShowTerms', function() terminals.show() end, {})
api.nvim_create_user_command('ToggleTerm', function() terminals.toggle() end, {}) 
api.nvim_create_user_command('ToggleZoom', winSizing.toggleZoom, {})
api.nvim_create_user_command('Terminals', customPicker.termPick, {})
