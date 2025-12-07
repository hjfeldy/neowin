
local util = require('util')


--- @class StackNode 
--- @field val integer
--- @field prev StackNode
--- @field next StackNode
--- @field id integer
local StackNode = {}


local NODE_ID = 0

--- @param val integer
function StackNode:new(val)
  NODE_ID = NODE_ID + 1
  local inst = {val=val, prev=nil, next=nil, id=NODE_ID}
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

function StackNode:remove()
  if self.prev ~= nil then
    self.prev.next = self.next
  end
  if self.next ~= nil then
    self.next.prev = self.prev
  end
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
  util.debug('CREATED NODE WITH COUNT ' .. inst.count)
  setmetatable(inst, self)
  self.__index = self

  if #existingItems > maxLen then 
    existingItems = vim.list_slice(existingItems, 0, maxLen)
  end
  for _, item in ipairs(existingItems) do
    inst:add(item)
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

--- @param node StackNode
function Stack:remove(node)
  if node.id == self.head.id then
    self.head = node.prev
  end
  node:remove()
  self.count = self.count - 1
end

--- @param removeValue integer
function Stack:removeInstancesOf(removeValue)
  local node = self.head
  local isHead = true
  print('REMOVING VALUES - current array = ' .. vim.inspect(self:toArray()))
  local i = 0
  while node ~= nil do
    i = i + 1
    if node.val == removeValue then
      print('REMOVING VALUE FROM NODE ' .. i .. ': ' .. node.val) 
      if i == self.count then
        self:removeTail()
      else
        self:remove(node)
      end
    end
    print('NEW ARRAY: ' .. vim.inspect(self:toArray()))

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
