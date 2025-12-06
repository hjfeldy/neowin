local util = require('util')

local M = {}

local Node = {}
function Node:new(val, depth)
  depth = depth or 0
  local inst = {next=nil, prev=nil, val=val, depth=depth}
  setmetatable(inst, self)
  self.__index = self
  return inst
end

function Node:addChild(val)
  local newNode = Node:new(val, self.depth+1)
  self.next = newNode
  newNode.prev = self
end

local LinkedList = {}
function LinkedList:new() 
  local root = Node:new()
  local inst = {head=root, current=root}
  setmetatable(inst, self)
  self.__index = self
  return inst
end

function LinkedList:addVal(val)
  self.current:addChild(val)
  self.current = self.current.next
  self.head = self.current
end

function LinkedList:traverse(forwards)
  if forwards and self.current.next ~= nil then
    self.current = self.current.next
  end
  if not forwards and self.current.prev ~= nil then
    self.current = self.current.prev
  end
  return self.current.val
end

M.JUMP_LIST = LinkedList:new()
M.LOCAL_JUMP_LIST = LinkedList:new()
M.LOCAL_WINDOW = true

function M.smartCD(localWindow)
  local jumpList = localWindow and M.LOCAL_JUMP_LIST or M.JUMP_LIST
  local dirname = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
  local cmd = localWindow and 'lcd' or 'ycd'
  if jumpList.current.val == nil then
    jumpList.current.val = vim.fn.getcwd()
    util.debug('SET ROOT VALUE to ' .. jumpList.current.val)
  end
  jumpList:addVal(dirname)

  vim.cmd(cmd .. ' ' .. dirname)
  M.LOCAL_WINDOW = localWindow
end

function M.jumpBack()
  local jumpList = M.LOCAL_WINDOW and M.LOCAL_JUMP_LIST or M.JUMP_LIST
  local lastDir = jumpList:traverse(false)
  util.debug('LAST DIR: ' .. lastDir)
  local cmd = M.LOCAL_WINDOW and 'lcd' or 'tcd'
  vim.cmd(cmd .. ' ' .. lastDir)
end

function M.jumpForwards()
  local jumpList = M.LOCAL_WINDOW and M.LOCAL_JUMP_LIST or M.JUMP_LIST
  local nextDir = jumpList:traverse(true)
  util.debug('NEXT DIR: ' .. nextDir)
  local cmd = M.LOCAL_WINDOW and 'lcd' or 'tcd'
  vim.cmd(cmd .. ' ' .. nextDir)
end

return M
