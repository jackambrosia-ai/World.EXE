--!strict
-- HackTargets (wrist-hacking prototype, server): resolves a client-supplied target id to a live
-- character model and checks eligibility. Ids:
--   "player:<UserId>"   another player's character
--   "npc:<name>"        a Model tagged HackTarget with attribute HackTargetId = "npc:<name>"
--   "boss:<name>"       the same, also tagged HackBoss
-- Client ids are only lookup keys; range, line of sight and state are always checked here.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HackCatalog = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("HackCatalog"))
local A = HackCatalog.Attr

export type Target = {
	Id: string,
	Kind: string, -- "player" | "npc" | "boss"
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Player: Player?,
}

local HackTargets = {}

local MAX_ID_LENGTH = 64

function HackTargets.IdForPlayer(player: Player): string
	return "player:" .. tostring(player.UserId)
end

local function fromModel(model: Model, id: string, kind: string, player: Player?): Target?
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not hum or not root or not root:IsA("BasePart") or hum.Health <= 0 then
		return nil
	end
	return { Id = id, Kind = kind, Model = model, Humanoid = hum, Root = root, Player = player }
end

function HackTargets.Resolve(id: any): Target?
	if typeof(id) ~= "string" or #id == 0 or #id > MAX_ID_LENGTH then
		return nil
	end
	local userId = string.match(id, "^player:(%d+)$")
	if userId then
		local player = Players:GetPlayerByUserId(tonumber(userId) :: number)
		local character = player and player.Character
		if player and character then
			return fromModel(character, id, "player", player)
		end
		return nil
	end
	for _, inst in CollectionService:GetTagged(HackCatalog.TargetTag) do
		if inst:IsA("Model") and inst:GetAttribute(A.TargetId) == id and inst:IsDescendantOf(workspace) then
			return fromModel(inst, id, if CollectionService:HasTag(inst, HackCatalog.BossTag) then "boss" else "npc", nil)
		end
	end
	return nil
end

-- Clear line between two points: only collidable geometry blocks, both characters are ignored.
function HackTargets.LineOfSight(fromModel: Model, target: Target): boolean
	local fromRoot = fromModel:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not fromRoot then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { fromModel, target.Model }
	params.RespectCanCollide = true
	local a = fromRoot.Position + Vector3.new(0, 1.5, 0)
	local b = target.Root.Position + Vector3.new(0, 1.5, 0)
	return workspace:Raycast(a, b - a, params) == nil
end

return HackTargets
