-- The addon namespace.
local addon, ns = ...

-- Define the linked list class and put it in the addon namespace.
local LinkedList = {}
local LinkedListMetatable = { __index = LinkedList }
ns.LinkedList = LinkedList

-- Constructor.
function LinkedList:new(manager)
	local self = {}
	setmetatable(self, LinkedListMetatable)
	
	self.Head = nil
	
	return self
end

-- Add a value to the list.
function LinkedList:Add(value)
	local systemTime = GetTime()

	-- Add new item to the front of the linked list.
	self.Head = { next = self.Head, amount = value, time = systemTime }
end

-- Sum items until we reach one that is more than the specified number of seconds old. When that happens, we remove the tail of the list.
function LinkedList:Sum(seconds)
	local systemTime = GetTime()
	local sum = 0
	local current = self.Head
	while current do
		if systemTime - current.time > 6 then
			current.next = nil
		else
			sum = sum + current.amount
		end
		current = current.next
	end
	return sum
end