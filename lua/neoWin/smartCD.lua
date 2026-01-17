local util = require('util')

local M = {}

--- Element in a tree
local Node = {}

--- Construct a new element for a tree
--- @param val any?
--- @param depth integer?
function Node:new(val, depth)
  depth = depth or 0
  local inst = {next=nil, prev=nil, val=val, depth=depth}
  setmetatable(inst, self)
  self.__index = self
  return inst
end

--- Construct a child node for this node 
--- @param val any
--- @return nil
function Node:addChild(val)
  local newNode = Node:new(val, self.depth+1)
  self.next = newNode
  newNode.prev = self
end

--- Linked List with a "current" value in addition to a head
--- The list can be traversed up/down, but gets cut off whenever an item is added.
--- When adding a new item, the current selection becomes the new head,
--- and any of its old children are discarded. 
--- This allows us to implement a rudimentary jumplist 
--- @class TraversableLinkedList
local TraversableLinkedList = {}
function TraversableLinkedList:new() 
  local root = Node:new()
  local inst = {head=root, current=root}
  setmetatable(inst, self)
  self.__index = self
  return inst
end

--- Add a value to the linked list
--- @param val any
function TraversableLinkedList:addVal(val)
  self.current:addChild(val)
  self.current = self.current.next
  self.head = self.current
end

--- Move the current selection forwards/backwards in the list 
--- @param forwards boolean 
function TraversableLinkedList:traverse(forwards)
  if forwards and self.current.next ~= nil then
    self.current = self.current.next
  end
  if not forwards and self.current.prev ~= nil then
    self.current = self.current.prev
  end
  return self.current.val
end

-- local JumpList = {}
-- --- @ class JumpList
-- function JumpList:new(localCD) 
--   local inst = {list=TraversableLinkedList:new(), localCD=localCD}
--   setmetatable(inst, self)
--   self.__index = self
--   return inst
-- end

--- change-directory jumplist
--- @type { [integer]: TraversableLinkedList }
M.JUMP_LISTS = {}
--- local-window change-directory jumplist
--- @type { [integer]: TraversableLinkedList }
M.JUMP_LISTS = {}
--- local-window change-directory jumplist
--- @type { [integer]: TraversableLinkedList }
M.LOCAL_JUMP_LISTS = {}


--- @param localCD boolean
--- @param winOrTab integer?
local function getJumpList(localCD, winOrTab) 
  local jumpList
  local jumpListContainer
  if localCD then
    winOrTab = winOrTab or vim.api.nvim_get_current_win()
    jumpListContainer = M.LOCAL_JUMP_LISTS
    print('using window-scoped jump lists')
  else
    winOrTab = winOrTab or vim.api.nvim_get_current_tabpage()
    jumpListContainer = M.JUMP_LISTS
    print('using tab-scoped jump lists')
  end

  if jumpListContainer[winOrTab] ~= nil then
    print('jump list exists for win/tab ' .. winOrTab)
    jumpList = jumpListContainer[winOrTab]
  else
    print('jump list is null for win/tab ' .. winOrTab)
    jumpList = TraversableLinkedList:new()
    jumpListContainer[winOrTab] = jumpList
  end
  return jumpList;
end

--- Change directory to the current buffer's base directory
--- Record the change in the relevant jumplist
--- @param localCD boolean use the command "lcd" instead of "cd"
--- @return nil
function M.smartCD(localCD)

  local jumpList = getJumpList(localCD)

  local dirname = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
  local cmd = localCD and 'lcd' or 'tcd'
  if jumpList.current.val == nil then
    jumpList.current.val = vim.fn.getcwd()
    util.debug('SET ROOT VALUE to ' .. jumpList.current.val)
  end
  jumpList:addVal(dirname)

  vim.cmd(cmd .. ' ' .. dirname)
end

--- Change directory to the previous element in the cd jumplist
--- @param localCD boolean
--- @return nil
function M.jumpBack(localCD)
  local jumpList = getJumpList(localCD)
  local lastDir = jumpList:traverse(false)
  util.debug('LAST DIR: ' .. (lastDir or 'nil'))
  local cmd = localCD and 'lcd' or 'tcd'
  if lastDir ~= nil then
    vim.cmd(cmd .. ' ' .. lastDir)
  end
end

--- Change directory to the next element in the cd jumplist
--- @param localCD boolean
--- @return nil
function M.jumpForwards(localCD)
  local jumpList = getJumpList(localCD)
  local nextDir = jumpList:traverse(true)
  util.debug('NEXT DIR: ' .. (nextDir or 'nil'))
  local cmd = localCD and 'lcd' or 'tcd'
  if nextDir ~= nil then
    vim.cmd(cmd .. ' ' .. nextDir)
  end
end

return M
