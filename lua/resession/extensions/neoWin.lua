---@require('resession')
local smartDelete = require('neoWin.smartDelete')

local M = {}

---Get the saved data for this extension
---@param opts resession.Extension.OnSaveOpts Information about the session being saved
---@return any
M.on_save = function(opts)
  local out = smartDelete.serialize()
  return out
end

---Restore the extension state
---@param data {[integer]: integer[]} The value returned from on_save
M.on_post_load = function(data)
  smartDelete.deserialize(data)
end

return M
