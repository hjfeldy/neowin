
local util = require('util')


--- @class StackNode 
--- @field val integer
--- @field prev StackNode
--- @field next StackNode
local StackNode = {}

--- @param val integer
function StackNode:new(val)
  local inst = {val=val, prev=nil, next=nil}
  setmetatable(inst, self)
  self.__index = self
  return inst
end

--- @param val integer
function StackNode:add(val)
  local newNode = StackNode:new(val)
  newNode.prev = self
  self.next = newNode
  return newNode
end

--- Maximum-length front-push list
--- @class Stack
--- @field head StackNode
--- @field tail StackNode
--- @field count integer
--- @field maxLen integer
local Stack = {}

--- New Stack
--- Optionally pass an array of primitives to initialize
--- @param maxLen integer?
--- @param existingItems integer[]?
function Stack:new(maxLen, existingItems)
  existingItems = existingItems or {}
  maxLen = maxLen or 999

  local inst = {head=nil, tail=nil, count=0, maxLen=maxLen}
  setmetatable(inst, self)
  self.__index = self

  if #existingItems > maxLen then 
    existingItems = vim.list_slice(existingItems, 0, maxLen)
  end
  for _, item in ipairs(existingItems) do
    self:add(item)
  end
  return inst
end


function Stack:removeTail()
  local oldTail = self.tail
  self.tail = self.tail.next
  oldTail.next = nil
  oldTail.prev = nil
  self.count = self.count - 1
end

--- @param val integer
function Stack:add(val)
  if self.head == nil then 
    util.debug('Creating first node with val ' .. val)
    local firstNode = StackNode:new(val)
    self.tail = firstNode
    self.head = firstNode
    util.debug('First-Head value: ' .. self.head.val)
  else
    util.debug('Adding new node with val ' .. val)
    self.head = self.head:add(val)
    util.debug('New-Head value: ' .. self.head.val)
  end
  self.count = self.count + 1

  if self.count > self.maxLen then
    self:removeTail()
  end
end

-- n1 n2 n3
-- n1.next = nil, n1.prev = n2
-- n2.next = n1, n2.prev = n3
-- n3.next = n2, n3.prev = nil
--
-- n3.next = n1
-- n1.prev = n3
--
-- n1.next = nil, n1.prev = n3
-- n3.next = n1, n3.prev = nil

--- @param removeValue integer
function Stack:removeInstancesOf(removeValue)
  local node = self.head
  local isHead = true
  while node ~= nil do
    if node.val == removeValue then
      self.count = self.count - 1
      if node.prev ~= nil then
        node.prev.next = node.next
      end
      if node.next ~= nil then
        node.next.prev = node.prev
      end

      if isHead then
        self.head = node.prev
      else
        isHead = false
      end
    end

    node = node.prev
  end
end

function Stack:toArray()
  local arr = {}
  local node = self.head
  while node ~= nil do
    arr[#arr+1] = node.val
    node = node.prev
  end
  return arr
end

return Stack
