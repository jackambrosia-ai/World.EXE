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
end

function MatchStateClient.Start(folder: Instance)
	read(folder)
	folder:GetAttributeChangedSignal(Config.MatchSnapshotAttribute):Connect(function()
		read(folder)
	end)
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
