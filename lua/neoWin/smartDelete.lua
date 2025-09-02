local terminals = require('neoWin.terminals')
local M = {}

---Close and reopen the terminal pane before/after deleting a buffer
---This avoids annoying behavior where the terminals take over the entire window
function M.smartDelete(force) 
  if vim.o.filetype == 'Terminal' then
    print('Do not close terminal buffers with bdelete - exit the terminal process')
    return
  end
  local hasTerm = terminals:termVisible() 
  if hasTerm then
    terminals:toggle()
  end

  local cmd = 'bdelete'
  if force then
    cmd = cmd .. '!'
  end
  vim.cmd(cmd)

  if hasTerm then
    terminals:toggle()
    -- print('feeding keys')
    vim.api.nvim_feedkeys('<C-\\><C-n><C-w>j', 'n', true)
  end
end

return M
