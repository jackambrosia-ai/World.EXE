--!strict
-- EnvironmentResponseClient (Phase 8A-2c): static, client-side environmental responses to active
-- patches and combinations. Presentation only; nothing here is replicated or server-authoritative.
--
-- Input: the replicated match Snapshot through MatchStateClient.OnChanged (MatchStateClient stays the
-- only reader of the Snapshot attribute). Only ACTIVE patches of the current match count (WARNING has
-- no environmental response, owner decision), plus the running combinations in Snapshot.Interactions,
-- and only while the match is ACTIVE or FINAL_PHASE. Outside that, everything is at baseline.
--
-- Hooks: instances tagged "EnvFX_<EFFECT_ID>" by tools/studio/phase8a2c/0_build.luau. Each hook has an
-- "EnvFX_Role" (which style applies) and builder-written baseline attributes (Base_Color,
-- Base_Transparency, Base_Material, Base_Brightness, Base_Range, Base_LightEnabled, Base_BeamEnabled).
-- A hook's desired value = its baseline, overlaid by every active effect that tags it, in a fixed
-- precedence order (the ten patches, then the five combinations; later wins, so a combination
-- overrides its sources). Restoring always reads the Base_* attributes, never client-cached values,
-- so hooks that stream out and back in (or are re-parented) are always correct.
--
-- Event-driven: work happens only when the effective patch/combination key changes (the Snapshot is
-- also republished for timers, stability, objectives and participants; those are skipped), or when a
-- hook streams in. There are no per-frame connections. Only decorative properties are written:
-- BasePart Color/Transparency/Material (Color only on collidable parts), Light Enabled/Color/
-- Brightness/Range, Beam Enabled. Lighting is never touched (BLACKOUT belongs to WorldModifierService).

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("WORLD_EXE"):WaitForChild("Shared"):WaitForChild("Config"))

local EnvironmentResponseClient = {}

-- Precedence: later entries win when two active effects style the same hook property.
local ORDER = table.freeze({
	"ZERO_G", "DECAY", "DRONE_SWARM", "SUPPLY_DROP", "BOUNCY", "SLIPPERY", "BLACKOUT", "MAGNETIC", "CORRUPTION", "FLOOD",
	"SUPER_BOUNCE", "HUNTER_SCAN", "FLOATING_DEBRIS", "RAPID_DECAY", "SLIDE_FIELD",
})
local TAG_PREFIX = "EnvFX_"

local rgb = Color3.fromRGB
local VIOLET_BRIGHT = rgb(172, 96, 255)
local VIOLET_MAX = rgb(200, 140, 255)
local CORAL = rgb(255, 111, 97)
local CYAN = rgb(40, 190, 230)
local ICE = rgb(190, 235, 255)
local TEAL = rgb(0, 190, 170)

type Style = { [string]: any }
-- STYLES[effect][role] = property overrides. Roles and managed properties match the builder.
local STYLES: { [string]: { [string]: Style } } = {
	ZERO_G = {
		CoilTrim = { Color = VIOLET_BRIGHT },
		CoilLight = { Color = VIOLET_BRIGHT, Brightness = 3.5 },
	},
	DECAY = {
		Skylight = { Color = rgb(44, 14, 66), Transparency = 0.3 },
		Inlay = { Color = rgb(112, 42, 176), Material = "Neon" },
	},
	DRONE_SWARM = {
		SpireBeacon = { Color = CORAL },
		SpireLight = { Color = CORAL, Brightness = 2.4 },
	},
	SUPPLY_DROP = {
		HubRing = { Color = CYAN },
		Oculus = { Color = CYAN },
	},
	BOUNCY = {
		BounceRim = { Transparency = 0 },
	},
	SLIPPERY = {
		Pipe = { Color = ICE, Material = "Glass", Transparency = 0.15 },
		SlipRim = { Transparency = 0.2 },
	},
	BLACKOUT = {
		Seam = { Color = rgb(22, 26, 38), Material = "Metal" },
	},
	MAGNETIC = {
		CableTray = { Color = rgb(96, 44, 160) },
		MagCoil = { Transparency = 0 },
		MagLight = { Enabled = true },
	},
	CORRUPTION = {
		GlitchA = { Transparency = 0 },
		GlitchB = { Transparency = 0.15 },
	},
	FLOOD = {
		IntakeGrate = { Color = TEAL },
		IntakeLight = { Brightness = 2, Range = 24 },
		PumpRing = { Color = TEAL },
		TurbineCasing = { Color = rgb(18, 112, 118) },
	},
	SUPER_BOUNCE = {
		CoilTrim = { Color = VIOLET_MAX },
		CoilLight = { Color = VIOLET_MAX, Brightness = 5 },
		BounceRim = { Transparency = 0, Color = VIOLET_MAX },
	},
	HUNTER_SCAN = {
		ScanBeam = { Enabled = true },
	},
	FLOATING_DEBRIS = {
		Debris = { Transparency = 0 },
		DebrisChip = { Transparency = 0 },
		DebrisLight = { Enabled = true },
	},
	RAPID_DECAY = {
		Skylight = { Color = rgb(20, 6, 28), Transparency = 0.12 },
		CraneWarning = { Color = rgb(255, 196, 40) },
		CraneLight = { Brightness = 3, Range = 16 },
	},
	SLIDE_FIELD = {
		SlipRim = { Color = rgb(138, 43, 226), Material = "Neon", Transparency = 0 },
	},
}

-- Properties each role may change (union over all effects), validated once. The style tables are
-- frozen and exposed read-only (EnvironmentResponseClient.Styles / .Order) for tests.
local ROLE_PROPS: { [string]: { string } } = {}
do
	for _, roles in STYLES do
		for _, style in roles do
			table.freeze(style)
		end
		table.freeze(roles)
	end
	table.freeze(STYLES)
	local seen: { [string]: { [string]: boolean } } = {}
	for _, roles in STYLES do
		for role, style in roles do
			seen[role] = seen[role] or {}
			for prop in style do
				seen[role][prop] = true
			end
		end
	end
	for role, props in seen do
		local list = {}
		for p in props do
			table.insert(list, p)
		end
		table.sort(list)
		ROLE_PROPS[role] = list
	end
end

local LIVE_STATES = { [Config.MatchStates.Active] = true, [Config.MatchStates.FinalPhase] = true }
local ACTIVE = Config.PatchStates.Active

local started = false
local hooks: { [Instance]: boolean } = {}
local activeList: { string } = {}
local currentKey: string? = nil
local connections: { RBXScriptConnection } = {}
local unsubscribe: (() -> ())? = nil
local warned: { [string]: boolean } = {}
local stats = { Applies = 0, Skipped = 0, Writes = 0, HooksAdded = 0, HooksRemoved = 0, Diagnostics = 0 }
local statsQueued = false

local function diagnostic(key: string, message: string)
	if warned[key] then
		return
	end
	warned[key] = true
	stats.Diagnostics += 1
	warn(`[WORLD_EXE] EnvFX: {message}`)
end

local function baseAttribute(inst: Instance, prop: string): string
	if prop == "Enabled" then
		return if inst:IsA("Beam") then "Base_BeamEnabled" else "Base_LightEnabled"
	end
	return "Base_" .. prop
end

-- Reads and type-checks a hook's baseline for one property; nil (with a diagnostic) when invalid.
local function baseValue(inst: Instance, prop: string): any
	local attr = baseAttribute(inst, prop)
	local v = inst:GetAttribute(attr)
	local ok = false
	if prop == "Color" then
		ok = typeof(v) == "Color3"
	elseif prop == "Transparency" or prop == "Brightness" or prop == "Range" then
		ok = typeof(v) == "number" and v == v
	elseif prop == "Enabled" then
		ok = typeof(v) == "boolean"
	elseif prop == "Material" then
		if typeof(v) == "string" then
			local found, item = pcall(function()
				return (Enum.Material :: any)[v]
			end)
			if found and typeof(item) == "EnumItem" then
				return item
			end
		end
	end
	if not ok then
		diagnostic(inst:GetFullName() .. attr, `missing or invalid {attr} on {inst:GetFullName()}; property left untouched`)
		return nil
	end
	return v
end

-- Whether this hook class may have this property written at all.
local function allowed(inst: Instance, prop: string): boolean
	if inst:IsA("BasePart") then
		if prop == "Color" then
			return true
		end
		return (prop == "Transparency" or prop == "Material") and not inst.CanCollide
	elseif inst:IsA("Light") then
		return prop == "Enabled" or prop == "Color" or prop == "Brightness" or prop == "Range"
	elseif inst:IsA("Beam") then
		return prop == "Enabled"
	end
	return false
end

local function queueStats()
	if statsQueued or not RunService:IsStudio() then
		return
	end
	statsQueued = true
	task.defer(function()
		statsQueued = false
		local count = 0
		for _ in hooks do
			count += 1
		end
		script:SetAttribute("EnvFX_Stats", HttpService:JSONEncode({
			Key = currentKey or "",
			Hooks = count,
			Connections = #connections,
			Applies = stats.Applies,
			Skipped = stats.Skipped,
			Writes = stats.Writes,
			HooksAdded = stats.HooksAdded,
			HooksRemoved = stats.HooksRemoved,
			Diagnostics = stats.Diagnostics,
		}))
	end)
end

-- Computes and writes one hook's desired properties (writes only properties that differ).
local function apply(inst: Instance)
	local role = inst:GetAttribute("EnvFX_Role")
	local props = if typeof(role) == "string" then ROLE_PROPS[role] else nil
	if not props then
		diagnostic(inst:GetFullName() .. "role", `unknown EnvFX_Role on {inst:GetFullName()}`)
		return
	end
	local overrides: Style = {}
	for _, effect in activeList do
		if CollectionService:HasTag(inst, TAG_PREFIX .. effect) then
			local style = STYLES[effect][role :: string]
			if style then
				for k, v in style do
					overrides[k] = v
				end
			end
		end
	end
	for _, prop in props do
		if not allowed(inst, prop) then
			diagnostic(inst:GetFullName() .. prop, `{prop} may not be changed on {inst:GetFullName()}`)
			continue
		end
		local base = baseValue(inst, prop)
		if base == nil then
			continue
		end
		local want = overrides[prop]
		if want == nil then
			want = base
		elseif prop == "Material" then
			want = (Enum.Material :: any)[want]
		end
		local target = inst :: any
		if target[prop] ~= want then
			target[prop] = want
			stats.Writes += 1
		end
	end
end

local function hasEnvTag(inst: Instance): boolean
	for _, t in CollectionService:GetTags(inst) do
		if t:sub(1, #TAG_PREFIX) == TAG_PREFIX then
			return true
		end
	end
	return false
end

local function track(inst: Instance)
	if not inst:IsDescendantOf(workspace) then
		return
	end
	if not hooks[inst] then
		hooks[inst] = true
		stats.HooksAdded += 1
	end
	apply(inst) -- current desired state, also for hooks that stream in after activation
	queueStats()
end

-- Drops the reference (streamed out, destroyed or untagged). If the instance is in fact still in the
-- workspace with another EnvFX tag, it is picked up again after the signal settles.
local function untrack(inst: Instance)
	if hooks[inst] then
		hooks[inst] = nil
		stats.HooksRemoved += 1
		queueStats()
	end
	task.defer(function()
		if started and not hooks[inst] and inst:IsDescendantOf(workspace) and hasEnvTag(inst) then
			track(inst)
		end
	end)
end

-- Effective active effects (precedence order) and their key for one Snapshot.
local function effective(snap: { [string]: any }): ({ string }, string)
	local set: { [string]: boolean } = {}
	if LIVE_STATES[snap.State] then
		if typeof(snap.Patches) == "table" then
			for _, p in snap.Patches do
				if typeof(p) == "table" and p.State == ACTIVE and p.MatchId == snap.MatchId and typeof(p.PatchId) == "string" then
					set[p.PatchId] = true
				end
			end
		end
		if typeof(snap.Interactions) == "table" then
			for _, c in snap.Interactions do
				if typeof(c) == "table" and typeof(c.Id) == "string" then
					set[c.Id] = true
				end
			end
		end
	end
	local list = {}
	for _, id in ORDER do
		if set[id] then
			table.insert(list, id)
		end
	end
	return list, table.concat(list, ",")
end

local function onSnapshot(snap: { [string]: any })
	local list, key = effective(snap)
	if key == currentKey then
		stats.Skipped += 1
		return
	end
	currentKey = key
	activeList = list
	stats.Applies += 1
	for inst in hooks do
		apply(inst)
	end
	queueStats()
end

-- matchState: the MatchStateClient module (already started).
function EnvironmentResponseClient.Start(matchState: any)
	if started then
		return
	end
	started = true
	for _, effect in ORDER do
		local tag = TAG_PREFIX .. effect
		table.insert(connections, CollectionService:GetInstanceAddedSignal(tag):Connect(track))
		table.insert(connections, CollectionService:GetInstanceRemovedSignal(tag):Connect(untrack))
	end
	unsubscribe = matchState.OnChanged(onSnapshot)
	-- Apply the newest accepted Snapshot first (the client may start mid-patch), then pick up the
	-- hooks that are already streamed in.
	onSnapshot(matchState.Get())
	for _, effect in ORDER do
		for _, inst in CollectionService:GetTagged(TAG_PREFIX .. effect) do
			track(inst)
		end
	end
	queueStats()
end

-- Disconnects everything and restores every tracked hook to its baseline (tests / shutdown).
function EnvironmentResponseClient.Stop()
	if not started then
		return
	end
	started = false
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	if unsubscribe then
		unsubscribe()
		unsubscribe = nil
	end
	activeList = {}
	currentKey = nil
	for inst in hooks do
		if inst:IsDescendantOf(workspace) then
			apply(inst)
		end
	end
	table.clear(hooks)
	queueStats()
end

EnvironmentResponseClient.Styles = STYLES
EnvironmentResponseClient.Order = ORDER

function EnvironmentResponseClient.GetStats(): { [string]: any }
	local count = 0
	for _ in hooks do
		count += 1
	end
	local copy = table.clone(stats) :: { [string]: any }
	copy.Key = currentKey or ""
	copy.Hooks = count
	copy.Connections = #connections
	return copy
end

return EnvironmentResponseClient
