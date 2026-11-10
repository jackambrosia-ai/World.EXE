--!strict
-- CleanupService (Phase 3, server only): resource bags with idempotent cleanup.
-- A bag tracks instances, connections, threads, callbacks and objects with :Destroy(). Cleanup
-- releases items in reverse order, each under pcall, and is safe to call any number of times.
-- Anything added after cleanup is released immediately, so a late callback cannot leak.

export type Bag = {
	Label: string,
	Add: (self: Bag, item: any) -> any,
	Cleanup: (self: Bag) -> (number, { string }),
	IsCleaned: (self: Bag) -> boolean,
	Count: (self: Bag) -> number,
}

local CleanupService = {}

local function release(item: any)
	local kind = typeof(item)
	if kind == "Instance" then
		item:Destroy()
	elseif kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "thread" then
		if coroutine.status(item) ~= "dead" then
			task.cancel(item)
		end
	elseif kind == "function" then
		item()
	elseif kind == "table" and typeof(item.Destroy) == "function" then
		item:Destroy()
	else
		error(`unsupported cleanup item: {kind}`)
	end
end

local BagMethods = {}
BagMethods.__index = BagMethods

function BagMethods.Add(self: any, item: any): any
	if self.cleaned then
		local ok, err = pcall(release, item)
		if not ok then
			warn(`[WORLD_EXE] Cleanup {self.Label}: late item release failed: {err}`)
		end
		return item
	end
	table.insert(self.items, item)
	return item
end

-- Returns how many items were released and any release errors (never throws).
function BagMethods.Cleanup(self: any): (number, { string })
	if self.cleaned then
		return 0, {}
	end
	self.cleaned = true
	local items = self.items
	self.items = {}
	local errors = {}
	for i = #items, 1, -1 do
		local ok, err = pcall(release, items[i])
		if not ok then
			table.insert(errors, tostring(err))
		end
	end
	return #items, errors
end

function BagMethods.IsCleaned(self: any): boolean
	return self.cleaned
end

function BagMethods.Count(self: any): number
	return #self.items
end

function CleanupService.new(label: string): Bag
	return setmetatable({ Label = label, items = {}, cleaned = false }, BagMethods) :: any
end

return CleanupService
