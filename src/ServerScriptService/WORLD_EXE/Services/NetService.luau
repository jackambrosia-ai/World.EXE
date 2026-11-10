--!strict
-- NetService (Phase 2, server only): creates the WORLD_EXE RemoteEvents at runtime.
-- Clients only send intent; every payload is validated by the receiving service.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("Config"))

local NetService = {}

local remotes: { [string]: RemoteEvent } = {}

function NetService.Init()
	local shared = ReplicatedStorage:WaitForChild("WORLD_EXE")
	local folder = shared:FindFirstChild("Remotes")
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = shared
	end
	assert(folder:IsA("Folder"), "ReplicatedStorage.WORLD_EXE.Remotes must be a Folder")
	for _, name in Config.Remotes do
		local existing = folder:FindFirstChild(name)
		if existing and not existing:IsA("RemoteEvent") then
			error(`ReplicatedStorage.WORLD_EXE.Remotes.{name} exists but is a {existing.ClassName}`)
		end
		local remote = (existing or Instance.new("RemoteEvent")) :: RemoteEvent
		remote.Name = name
		remote.Parent = folder
		remotes[name] = remote
	end
end

function NetService.Get(name: string): RemoteEvent
	local remote = remotes[name]
	assert(remote, `unknown remote {name} (NetService.Init not called?)`)
	return remote
end

return NetService
