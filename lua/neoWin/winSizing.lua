local a = vim.api


---@class WindowDimension
---@field width integer Window Width
---@field height integer Window Height
---@field zoomed? boolean Is the window zoomed?

---@type table<integer, WindowDimension>
local windowDimensions = {}

---Record the dimensions of all visible windows 
local function winInfo()
  local wins = a.nvim_list_wins()
  local width, height
  windowDimensions = {}
  for _, window in ipairs(wins) do
    width = a.nvim_win_get_width(window)
    height = a.nvim_win_get_height(window)
    windowDimensions[window] = {width=width, height=height}
  end
end

---Check if a window is zoomed 
local function zoomedExists()
  local wins = a.nvim_list_wins()
  for _, window in ipairs(wins) do
    if windowDimensions[window].zoomed then
      return true
    end
  end
  return false
end

--- Zoom a window out
local function zoomOut()
    local width, height
    for win, dim in pairs(windowDimensions) do
        width, height = dim.width, dim.height
        a.nvim_win_set_width(win, width)
        a.nvim_win_set_height(win, height)
        dim.zoomed = false
    end
    winInfo()
end

--- Zoom a window in
local function zoomIn()
  if zoomedExists() then
    zoomOut()
  else
    winInfo()
  end
  local ui = a.nvim_list_uis()[1]
  local width, height = ui.width, ui.height
  local win = a.nvim_get_current_win()
  windowDimensions[win].zoomed = true
  a.nvim_win_set_width(0, width)
  a.nvim_win_set_height(0, height)
end

---Toggle the zoom status of a window
local function toggleZoom()
  local thisWin = a.nvim_get_current_win()
  local wins = a.nvim_list_wins()
  local numWins = 0
  for _, _ in ipairs(wins) do
    numWins = numWins + 1
  end
  if numWins == 1 then
    return
  end

  if windowDimensions[thisWin].zoomed then
    zoomOut()
  else
    zoomIn()
  end
end

return {
  toggleZoom=toggleZoom,
  winInfo=winInfo
}
