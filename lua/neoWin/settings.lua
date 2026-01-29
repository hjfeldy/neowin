---@class NeowinOpts 
--- Should .env files be automatically parsed and sourced into new Terminal buffers?
---@field useDotenv boolean? 
--- Custom environment variables (if useDotenv=true, the .env file takes precedence)
---@field env {[string]: string}? 
---Logging options (per-logger - global logger conf should be under the "GLOBAL" logger)
---@field logging {[string]: LogOpts}?

local M = {}

M.DEFAULT_LEVEL = vim.log.levels.INFO
M.DEFAULT_FORMAT = "[{label}] {msg}"

---@type LogOpts
M.DEFAULT_LOG_OPTS = {
  level = M.DEFAULT_LEVEL,
  attrs = {},
  format=M.DEFAULT_FORMAT,
  withinLevelFilters=nil,
  levelOverrideFilters=nil
}

---@type NeowinOpts
M.CONF = {}

---@type NeowinOpts
local DEFAULT_OPTS = {
  useDotenv = true,
  env = {},
  logging = {GLOBAL = M.DEFAULT_LOG_OPTS}
}


---@param opts NeowinOpts?
M.setup = function(opts) 
  local logger = require('neoWin.logger'):new("Settings")
  logger:debug("Setting up neoWin with options: " .. vim.inspect(opts))
  opts = opts or {}
  opts = vim.tbl_deep_extend('force', DEFAULT_OPTS, opts)
  M.CONF = opts
end
return M
