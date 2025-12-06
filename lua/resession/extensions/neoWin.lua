print('LOADING NEOWIN EXTENSION')
local smartDelete = require('neoWin.smartDelete')
--
local M = {}

---Get the saved data for this extension
---@param opts resession.Extension.OnSaveOpts Information about the session being saved
---@return any
M.on_save = function(opts)
  -- vim.fn.writefile({'yes'}, 'C:/Users/RC12664/AppData/Local/nvim/beganSave')
  local out = smartDelete.serialize()
  -- vim.fn.writefile({'yes'}, 'C:/Users/RC12664/AppData/Local/nvim/endedSave')
  return out
end

---Restore the extension state
---@param data The value returned from on_save
M.on_post_load = function(data)
  -- vim.fn.writefile({'yes'}, 'C:/Users/RC12664/AppData/Local/nvim/beganLoad')
  smartDelete.deserialize(data)
  -- vim.fn.writefile({'yes'}, 'C:/Users/RC12664/AppData/Local/nvim/endedLoad')
end

return M
