--!strict
-- CoreNet (Core Round Step 1, shared): the prototype's two remotes, created by the server.
--   Request (client -> server): Request:FireServer(op: string, payload: table)
--   Event   (server -> client): Event:FireClient / FireAllClients(kind: string, data: table)
-- Ops and kinds are documented in CoreRound.server.luau. Folder: ReplicatedStorage.WORLD_EXE.CoreRound.Net

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CoreNet = {}

local function folder(): Folder
	local root = ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("CoreRound")
	if RunService:IsServer() then
		local f = root:FindFirstChild("Net")
		if not f then
			f = Instance.new("Folder")
			f.Name = "Net"
			for _, n in { "Request", "Event" } do
				local r = Instance.new("RemoteEvent")
				r.Name = n
				r.Parent = f
			end
			f.Parent = root
		end
		return f :: Folder
	end
	return root:WaitForChild("Net") :: Folder
end

function CoreNet.Request(): RemoteEvent
	return folder():WaitForChild("Request") :: RemoteEvent
end

function CoreNet.Event(): RemoteEvent
	return folder():WaitForChild("Event") :: RemoteEvent
end

return CoreNet
