local util = require('neoWin.util')
local settings = require('neoWin.settings')

local LOG_LEVELS = {
  INFO = vim.log.levels.INFO,
  DEBUG = vim.log.levels.DEBUG,
  WARNING = vim.log.levels.WARN,
  WARN = vim.log.levels.WARN,
  ERROR = vim.log.levels.ERROR,
}

local LOG_LEVEL_STRINGS = {}
for str, enumLvl in pairs(LOG_LEVELS) do LOG_LEVEL_STRINGS[enumLvl] = str end


local function createFilterFunction(conditions)
  return function(logAttrs)
    local meetsFilter = true
    for k, v in pairs(conditions) do
      meetsFilter = meetsFilter and logAttrs[k] == v
    end
    return meetsFilter
  end
end


local function getLoggerConf(loggerLabel)
  local loggingConf = settings.CONF.logging or {}
  -- local loggingConf = util.getDynamicConf('logging')
  local loggerConf = loggingConf[loggerLabel] or loggingConf['GLOBAL'] or {}
  loggerConf = vim.tbl_deep_extend('force', settings.DEFAULT_LOG_OPTS, loggerConf)
  return loggerConf
end

---@param loggerLabel string
local function getLevel(loggerLabel) 
  local loggerConf = getLoggerConf(loggerLabel)
  local strLevel = loggerConf['level'] or ""
  return LOG_LEVELS[strLevel] or settings.DEFAULT_LEVEL
end


---@class LogOpts
---@field level vim.log.levels?
---@field attrs {[string]: string}
---@field format string?
---list of filter objects - each list element constitutes a set of filter-conditions which are AND-gated together.
---If any of these condition-sets evaluates to true, the message will get logged (regardless of the level).
---If *none* of the condition-sets evaluate to true, then we proceed with normal filtering 
---(ie. filter by the level, and then apply any withinLevelFilters)
---@field levelOverrideFilters {[string]: string}[]? 
---list of filter objects - each list element constitutes a set of filter-conditions which are AND-gated together.
---If any of these condition-sets evaluates to true AND the logs level meets the level-filter, the message will get logged.
---But if *none* of the condition-sets evaluate to true, then the message will not be logged (regardless of meeting the level-filter)
---@field withinLevelFilters {[string]: string}[]? 



---@class Logger
---@field level vim.log.levels
---@field label string
---@field attrs {[string]: string}
---@field format string
---@field withinLevelFilters function[]
---@field levelOverrideFilters function[]
---@field opts LogOpts?
local Logger = {}


---@param label string
---@param opts LogOpts?
function Logger:new(label, opts) 
  local level = getLevel(label)
  local loggerConf = getLoggerConf(label) or {}
  opts = opts or vim.tbl_deep_extend('force', settings.DEFAULT_LOG_OPTS, loggerConf)

  local andFilterConditions = opts.withinLevelFilters or loggerConf['withinLevelFilters'] or {}
  local orFilterConditions = opts.levelOverrideFilters or loggerConf['levelOverrideFilters'] or {}

  local inst = {
    label=label,
    level=level,
    attrs = opts.attrs or {},
    format=opts.format or loggerConf['format'] or settings.DEFAULT_FORMAT,
    withinLevelFilters = vim.tbl_map(createFilterFunction, andFilterConditions),
    levelOverrideFilters = vim.tbl_map(createFilterFunction, orFilterConditions),
    -- retain the opts so we can reconstruct loggers whenever neoconf is updated
    opts=opts
  }
  self.__index = self
  setmetatable(inst, self)
  return inst
end


---@param self Logger
---@param attrs {[string]: string}
function Logger:withAttrs(attrs) 
  local replAttrs = vim.deepcopy(self.attrs)
  for k, v in pairs(attrs) do
    replAttrs[k] = v
  end
  local opts = vim.tbl_extend('force', self.opts, {attrs=replAttrs})
  return Logger:new(self.label, opts)
end


---@param self Logger
function Logger:log(...)
  local args = { ... }
  local level = args[1]

  local needsOrFilter = #self.levelOverrideFilters > 0
  local meetsOrFilter = false
  for _, filt in ipairs(self.levelOverrideFilters) do
    meetsOrFilter = meetsOrFilter or filt(self.attrs) 
  end

  local insufficientLevel = level < self.level
  if insufficientLevel then
    if (not meetsOrFilter and needsOrFilter) then
      return
    -- if no levelOverrideFilters are specified,
    -- there is no way for a message with an insufficient level to be logged
    elseif not needsOrFilter then
      return
    end
  end

  -- if no and filters, start with true and do nothing
  -- if any and filters exist, start with false and OR it
  local meetsAndFilter = #self.withinLevelFilters == 0;
  for _, filt in ipairs(self.withinLevelFilters) do
    meetsAndFilter = meetsAndFilter or filt(self.attrs)
  end
  if not meetsAndFilter then return end

  local msg = ''
  for i = 2,#args do
    msg = msg .. ' ' .. vim.inspect(args[i])
  end

  local strLevel = LOG_LEVEL_STRINGS[level]
  local formatted = self.format:gsub('{msg}', msg)
                               :gsub('{label}', self.label)
                               :gsub('{level}', strLevel)
                               :gsub('{attrs}', vim.inspect(self.attrs))
  for find, repl in pairs(self.attrs) do
    if find == 'attrs' then
      vim.notify('LOGGING ERROR - "attrs" is not a valid key name in the attrs table')
    else
      local findToken = '{' .. find .. '}'
      formatted = formatted:gsub(findToken, repl)
    end
  end
  vim.notify(formatted, level)
end

function Logger:info(...)
  self:log(vim.log.levels.INFO, ...)
end

function Logger:debug(...)
  self:log(vim.log.levels.DEBUG, ...)
end

function Logger:warn(...)
  self:log(vim.log.levels.WARN, ...)
end

function Logger:error(...)
  self:log(vim.log.levels.ERROR, ...)
end

return Logger
