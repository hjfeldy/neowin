local api = vim.api
local terminals = require('neoWin.terminals')
local winSizing = require('neoWin.winSizing')
local customPicker = require('neoWin.customPicker')
local smartDelete = require('neoWin.smartDelete')
local util = require('neoWin.util')
local LOGGER = require('neoWin.logger'):new('neoWin.plugin')

--[[ Autocommands ]]
-- for _, event in pairs({'TermClose', 'WinNew'}) do
  -- api.nvim_create_autocmd(event, {
api.nvim_create_autocmd('TermClose', {
  pattern = {'*'},
  callback = function(ev)
    winSizing.winInfo()
    vim.schedule(function() require('neoWin.terminals').refresh() end)
  end
})
-- end

api.nvim_create_autocmd('WinClosed', {
  pattern = {'*'},
  callback = function(ev)
    local logger = LOGGER:withAttrs({logMethod="Buf/Win_ClosedCB"})
    if vim.bo[ev.buf].filetype == 'Terminal' then
      logger:debug('Closing terminal window')
      vim.schedule(function() require('neoWin.terminals').refresh() end)
    end
  end
})

for _, eventName in pairs({'BufEnter', 'WinEnter'}) do
  api.nvim_create_autocmd(eventName,
    {
      pattern = {'*'},
      callback = function(event)
        local logger = LOGGER:withAttrs({logMethod="Buf/Win_EnterCB"})
        logger:debug('Caught ' .. eventName .. ' event for buf ' .. event.buf)
        local tab = api.nvim_tabpage_get_number(0)
        local ft = vim.bo[0].filetype
        local blacklist = {'qf', 'Terminal', 'noice', 'Noice'}
        if not vim.tbl_contains(blacklist, ft) then
          smartDelete.updateLastBuf(tab, event.buf)
        end
      end
    }
  )
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
