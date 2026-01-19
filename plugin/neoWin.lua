local api = vim.api
-- local terminals = require('neoWin.terminals')
-- local winSizing = require('neoWin.winSizing')
-- local customPicker = require('neoWin.customPicker')
-- local smartDelete = require('neoWin.smartDelete')
-- local util = require('neoWin.util')

--[[ Autocommands ]]
-- Whenever a window/buffer is closed through some user action external to this API,
-- we need to keep track of those changes (ie. delete terminals from the "bufs" and "bufsById" variables).
-- We also need to keep track of which terminal window was last focused 
-- for _, event in pairs({
--   'TermClose',
--   'BufWinEnter',
--   'WinEnter',
--   'WinLeave',
-- }) do
--   api.nvim_create_autocmd(event, {
--     pattern = {'*'},
--     callback = function(ev)
--       util.debug('Caught event ' .. event .. ' - setting current terminal')
--       terminals:refresh()
--     end
--   })
-- end

-- for _, event in pairs({
--   -- 'TermClose',
--   'WinEnter',
--   -- 'WinLeave',
--   -- 'WinNew',
-- }) do
--   api.nvim_create_autocmd(event, {
--     pattern = {'*'},
--     callback = function(ev)
--       util.debug('Caught event ' .. event .. ' - setting current terminal')
--       terminals:refresh()
--     end
--   })
-- end

-- for _, event in pairs({'TermClose', 'WinNew'}) do
  -- api.nvim_create_autocmd(event, {
--api.nvim_create_autocmd('TermClose', {
--  pattern = {'*'},
--  callback = function(ev)
--    winSizing.winInfo()
--    vim.schedule(function() require('neoWin.terminals').refresh() end)
--  end
--})
---- end
--
--for _, eventName in pairs({'BufEnter', 'WinEnter'}) do
--  api.nvim_create_autocmd(eventName,
--    {
--      pattern = {'*'},
--      callback = function(event)
--        util.debug('Caught ' .. eventName .. ' event for buf ' .. event.buf)
--        local tab = api.nvim_tabpage_get_number(0)
--        local ft = vim.bo[0].filetype
--        local blacklist = {'qf', 'Terminal', 'noice', 'Noice'}
--        if not vim.tbl_contains(blacklist, ft) then
--          smartDelete.updateLastBuf(tab, event.buf)
--        end
--      end
--    }
--  )
--end

--[[ User commands ]]
api.nvim_create_user_command('RenameTerm', function() require('neoWin.terminals').renameTerm() end, {})
api.nvim_create_user_command('NextTerm', function() require('neoWin.terminals').nextTerm() end, {})
api.nvim_create_user_command('PrevTerm', function() require('neoWin.terminals').prevTerm() end, {})
api.nvim_create_user_command('NewTerm', function() require('neoWin.terminals').newTerm()  end, {})
api.nvim_create_user_command('ShowTerms', function() require('neoWin.terminals').show() end, {})
api.nvim_create_user_command('ToggleTerm', function() require('neoWin.terminals').toggle() end, {}) 
-- api.nvim_create_user_command('ToggleZoom', require('neowin.winSizing').toggleZoom, {})
api.nvim_create_user_command('Terminals', require('neoWin.customPicker').termPick, {})
