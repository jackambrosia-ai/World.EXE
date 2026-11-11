--!strict
-- MatchStateClient: the only reader of replicated match state on the client.
-- The server publishes the whole state as one JSON attribute with a monotonically increasing
-- Version, so a reader never sees half of an update. Older or malformed versions are ignored.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("Config"))

export type Snapshot = { [string]: any }

local MatchStateClient = {}

local EMPTY_TURN = table.freeze({
	ArchitectUserId = 0,
	ArchitectName = "",
	TurnMatchId = 0,
	TurnNumber = 0,
	TurnEndsAt = 0,
	OfferedPatches = table.freeze({}),
	NextTurnAt = 0,
})

local latest: Snapshot = {
	Version = 0,
	State = Config.MatchStates.Lobby,
	MatchId = 0,
	StateEndsAt = 0,
	ParticipantCount = 0,
	MinPlayers = 0,
	Turn = EMPTY_TURN,
}
local ignoredStale = 0
local listeners: { (Snapshot) -> () } = {}
local started = false

local function read(folder: Instance)
	local raw = folder:GetAttribute(Config.MatchSnapshotAttribute)
	if typeof(raw) ~= "string" then
		return
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or typeof(data) ~= "table" or typeof(data.Version) ~= "number" then
		return
	end
	if data.Version <= latest.Version then
		ignoredStale += 1
		return
	end
	if typeof(data.Turn) ~= "table" then
		data.Turn = EMPTY_TURN
	end
	latest = data
	-- Phase 8A-2c: notify subscribers only after a valid, newer Snapshot is fully accepted.
	for _, listener in table.clone(listeners) do
		local okCall, err = pcall(listener, latest)
		if not okCall then
			warn(`[WORLD_EXE] MatchStateClient listener failed: {err}`)
		end
	end
end

function MatchStateClient.Start(folder: Instance)
	if started then
		return
	end
	started = true
	read(folder)
	folder:GetAttributeChangedSignal(Config.MatchSnapshotAttribute):Connect(function()
		read(folder)
	end)
end

-- Subscribes to accepted Snapshots (Phase 8A-2c). The callback receives the new Snapshot (read-only)
-- after it replaced the previous one; Get() returns the same table. A function already subscribed is
-- not added twice. Returns an idempotent unsubscribe function.
function MatchStateClient.OnChanged(callback: (Snapshot) -> ()): () -> ()
	if not table.find(listeners, callback) then
		table.insert(listeners, callback)
	end
	return function()
		local index = table.find(listeners, callback)
		if index then
			table.remove(listeners, index)
		end
	end
end

-- Latest accepted snapshot (treat as read-only).
function MatchStateClient.Get(): Snapshot
	return latest
end

-- Turn identity: match id + turn number (turn numbers restart every match).
function MatchStateClient.TurnKey(matchRef: any, turnRef: any): string
	return `{tostring(matchRef)}:{tostring(turnRef)}`
end

function MatchStateClient.GetIgnoredStaleCount(): number
	return ignoredStale
end

return MatchStateClient
