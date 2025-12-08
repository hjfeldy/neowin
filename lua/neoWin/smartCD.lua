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

--- change-directory jumplist
M.JUMP_LIST = TraversableLinkedList:new()
--- local-window change-directory jumplist
M.LOCAL_JUMP_LIST = TraversableLinkedList:new()
--- Was the most recent explicit directory change a local-window change?
M.LOCAL_WINDOW = true

--- Change directory to the current buffer's base directory
--- Record the change in the relevant jumplist
--- @param localWindow boolean use the command "lcd" instead of "cd"
--- @return nil
function M.smartCD(localWindow)
  local jumpList = localWindow and M.LOCAL_JUMP_LIST or M.JUMP_LIST
  local dirname = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
  local cmd = localWindow and 'lcd' or 'tcd'
  if jumpList.current.val == nil then
    jumpList.current.val = vim.fn.getcwd()
    util.debug('SET ROOT VALUE to ' .. jumpList.current.val)
  end
  jumpList:addVal(dirname)

  vim.cmd(cmd .. ' ' .. dirname)
  M.LOCAL_WINDOW = localWindow
end

--- Change directory to the previous element in the cd jumplist
--- @return nil
function M.jumpBack()
  local jumpList = M.LOCAL_WINDOW and M.LOCAL_JUMP_LIST or M.JUMP_LIST
  local lastDir = jumpList:traverse(false)
  util.debug('LAST DIR: ' .. lastDir)
  local cmd = M.LOCAL_WINDOW and 'lcd' or 'tcd'
  vim.cmd(cmd .. ' ' .. lastDir)
end

--- Change directory to the next element in the cd jumplist
--- @return nil
function M.jumpForwards()
  local jumpList = M.LOCAL_WINDOW and M.LOCAL_JUMP_LIST or M.JUMP_LIST
  local nextDir = jumpList:traverse(true)
  util.debug('NEXT DIR: ' .. nextDir)
  local cmd = M.LOCAL_WINDOW and 'lcd' or 'tcd'
  vim.cmd(cmd .. ' ' .. nextDir)
end

return M
