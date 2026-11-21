--!strict
-- CoreGeom (Core Round Step 1, shared): small pure geometry helpers for the Rebound Disc.
-- All tests are swept: a disc of radius r moving along the segment a -> b. They return the fraction
-- t in [0, 1] of the first contact, or nil. No instances, no physics.

local CoreGeom = {}

-- swept sphere (radius r) vs sphere (centre c, radius R)
function CoreGeom.SegSphere(a: Vector3, b: Vector3, c: Vector3, R: number): number?
	local d = b - a
	local f = a - c
	local A = d:Dot(d)
	local C = f:Dot(f) - R * R
	if C <= 0 then
		return 0 -- already inside
	end
	if A < 1e-9 then
		return nil
	end
	local B = 2 * f:Dot(d)
	local disc = B * B - 4 * A * C
	if disc < 0 then
		return nil
	end
	local t = (-B - math.sqrt(disc)) / (2 * A)
	if t >= 0 and t <= 1 then
		return t
	end
	return nil
end

-- closest points between segments p1-q1 and p2-q2: returns (s, t, distance)
local function segSeg(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3): (number, number, number)
	local d1, d2, r = q1 - p1, q2 - p2, p1 - p2
	local a, e, f = d1:Dot(d1), d2:Dot(d2), d2:Dot(r)
	local s, t
	if a <= 1e-9 and e <= 1e-9 then
		return 0, 0, r.Magnitude
	end
	if a <= 1e-9 then
		s = 0
		t = math.clamp(f / e, 0, 1)
	else
		local c = d1:Dot(r)
		if e <= 1e-9 then
			t = 0
			s = math.clamp(-c / a, 0, 1)
		else
			local b = d1:Dot(d2)
			local denom = a * e - b * b
			s = if denom > 1e-9 then math.clamp((b * f - c * e) / denom, 0, 1) else 0
			t = (b * s + f) / e
			if t < 0 then
				t = 0
				s = math.clamp(-c / a, 0, 1)
			elseif t > 1 then
				t = 1
				s = math.clamp((b - c) / a, 0, 1)
			end
		end
	end
	local c1 = p1 + d1 * s
	local c2 = p2 + d2 * t
	return s, t, (c1 - c2).Magnitude
end

-- swept disc (segment a -> b) vs vertical capsule (bottom..top, radius R). Returns an approximate first-contact
-- fraction (good enough at disc step sizes of a few studs).
function CoreGeom.SegCapsule(a: Vector3, b: Vector3, bottom: Vector3, top: Vector3, R: number): number?
	local s, _, dist = segSeg(a, b, bottom, top)
	if dist > R then
		return nil
	end
	-- back off from the closest point to the entry point
	local len = (b - a).Magnitude
	if len < 1e-6 then
		return 0
	end
	local back = math.sqrt(math.max(0, R * R - dist * dist)) / len
	return math.max(0, s - back)
end

-- swept point (segment a -> b, already inflated by the caller) vs a rectangle panel: centre c, unit normal n
-- (the side that blocks), unit right/up axes, half sizes hw/hh. Only blocks when travelling INTO the front face.
function CoreGeom.SegPanel(a: Vector3, b: Vector3, c: Vector3, n: Vector3, right: Vector3, up: Vector3, hw: number, hh: number): number?
	local d = b - a
	local denom = d:Dot(n)
	if denom >= 0 then
		return nil -- moving away from the front face (or parallel)
	end
	local t = (c - a):Dot(n) / denom
	if t < 0 or t > 1 then
		return nil
	end
	local p = a + d * t - c
	if math.abs(p:Dot(right)) <= hw and math.abs(p:Dot(up)) <= hh then
		return t
	end
	return nil
end

-- Disc vs one target (shared by the server judge and the client's "what I saw" record, so both use identical maths).
-- Contact: swept disc (radius r) vs head sphere and vertical body capsule, both inflated by r + tol.
-- Classification (step-size independent; Step 1 fix): on contact, take the disc's local straight line through the
-- target and compare how deep it passes inside each volume: HEAD if (closest distance to the head centre - headR) <=
-- (closest distance to the body axis - bodyR). A body throw that only grazes the inflated head volume stays BODY.
-- Returns (fraction along a -> b of first contact, "HEAD" | "BODY") or nil.
-- Step 1B: state "slide" uses lowered volumes (head at root + slideHead, body from slideBottom to slideTop), because the
-- slide pose is drawn procedurally on clients and the server's Head part does not follow it.
export type HitShape = {
	headR: number,
	bodyR: number,
	bodyTop: number,
	bodyBottom: number,
	r: number,
	tol: number,
	state: string?,
	slideHead: number?,
	slideTop: number?,
	slideBottom: number?,
	slideW: number?, -- Step 1C: 0..1 blend between standing and slide volumes (same curve as the visible pose)
}

-- Step 1C: smooth 0..1 easing shared by the slide pose (clients) and the slide hit volumes (server), so the volumes
-- lower and rise exactly as the drawn body does instead of switching in one frame.
function CoreGeom.Ease(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Step 1C: slide blend weight at time t for a slide that started at startT and (optionally) ended at endT, blending
-- over `blend` seconds. A slide that ends before it fully blended in falls back from where it reached.
function CoreGeom.SlideWeight(startT: number?, endT: number?, t: number, blend: number): number
	if not startT then
		return 0
	end
	blend = math.max(0.02, blend)
	if endT and endT >= startT then
		local reached = math.clamp((endT - startT) / blend, 0, 1)
		return CoreGeom.Ease(reached - math.clamp((t - endT) / blend, 0, 1))
	end
	return CoreGeom.Ease((t - startT) / blend)
end

-- Step 1C: the slide pose's torso / head joint targets (R15), shared so the server can compute where the drawn head is.
local R = math.rad
CoreGeom.SlidePoseR15 = {
	Root = CFrame.new(0, -1.35, 0.2) * CFrame.Angles(R(38), 0, 0), -- lower + lean back
	Waist = CFrame.Angles(R(-12), R(-8), 0), -- curl the chest forward a little
	Neck = CFrame.Angles(R(-22), 0, 0), -- keep looking ahead
}

-- Step 1C: height of the head centre above the root when the slide pose is drawn on THIS character's rig, computed from
-- its own joints (Motor6D C0/C1 or AnimationConstraint attachments) with the pose targets above. Avatars differ (Step 1C
-- two-client measurement: the default test avatar's drawn head sits ~0.19 above the root; Step 1B's fixed 0.5 came from
-- another avatar), so the server and clients use this per character instead of a fixed number. nil if the rig is not a
-- standard R15 chain (callers fall back to Slide.HeadHeight).
local function link(j: Instance?, part0: BasePart?, part1: BasePart?, t: CFrame): CFrame?
	if not j or not part0 or not part1 then
		return nil
	end
	if j:IsA("Motor6D") then
		if j.Part0 ~= part0 or j.Part1 ~= part1 then
			return nil
		end
		return j.C0 * t * j.C1:Inverse()
	elseif j:IsA("AnimationConstraint") then
		local a0, a1 = j.Attachment0, j.Attachment1
		if not a0 or not a1 or a0.Parent ~= part0 or a1.Parent ~= part1 then
			return nil
		end
		return a0.CFrame * t * a1.CFrame:Inverse()
	end
	return nil
end
function CoreGeom.PosedHeadOffset(m: Model): number?
	local hrp = m:FindFirstChild("HumanoidRootPart") :: BasePart?
	local lower = m:FindFirstChild("LowerTorso") :: BasePart?
	local upper = m:FindFirstChild("UpperTorso") :: BasePart?
	local head = m:FindFirstChild("Head") :: BasePart?
	if not hrp or not lower or not upper or not head then
		return nil
	end
	local p = CoreGeom.SlidePoseR15
	local l1 = link(lower:FindFirstChild("Root"), hrp, lower, p.Root)
	local l2 = link(upper:FindFirstChild("Waist"), lower, upper, p.Waist)
	local l3 = link(head:FindFirstChild("Neck"), upper, head, p.Neck)
	if not l1 or not l2 or not l3 then
		return nil
	end
	local y = (l1 * l2 * l3).Position.Y
	return if y == y then math.clamp(y, -0.5, 1.5) else nil
end

function CoreGeom.DiscHit(a: Vector3, b: Vector3, root: Vector3, head: Vector3, s: HitShape): (number?, string?)
	local bodyTop, bodyBottom = s.bodyTop, s.bodyBottom
	local w = s.slideW
	if w == nil then
		w = if s.state == "slide" then 1 else 0
	end
	if w > 0 then
		head = head:Lerp(root + Vector3.new(0, s.slideHead or 0.9, 0), w)
		bodyTop += ((s.slideTop or 0) - bodyTop) * w
		bodyBottom += ((s.slideBottom or -1.9) - bodyBottom) * w
	end
	local top = math.min(root.Y + bodyTop, head.Y - s.headR)
	local bottom = Vector3.new(root.X, root.Y + bodyBottom + s.bodyR, root.Z)
	local topV = Vector3.new(root.X, math.max(top, bottom.Y), root.Z)
	local th = CoreGeom.SegSphere(a, b, head, s.headR + s.r + s.tol)
	local tb = CoreGeom.SegCapsule(a, b, bottom, topV, s.bodyR + s.r + s.tol)
	if not th and not tb then
		return nil, nil
	end
	local t = math.min(th or 2, tb or 2)
	local d = b - a
	if d.Magnitude < 1e-6 then
		return t, if th then "HEAD" else "BODY"
	end
	local u = d.Unit
	local la, lb = a - u * 8, a + u * 8 -- local straight path through the target
	-- distance from the head centre to the line
	local ah = head - la
	local proj = math.clamp(ah:Dot(u), 0, 16)
	local dh = (la + u * proj - head).Magnitude
	local _, _, db = segSeg(la, lb, bottom, topV)
	local part = if (dh - s.headR) <= (db - s.bodyR) then "HEAD" else "BODY"
	return t, part
end

function CoreGeom.Flat(v: Vector3): Vector3?
	local h = Vector3.new(v.X, 0, v.Z)
	return if h.Magnitude > 1e-3 then h.Unit else nil
end

return CoreGeom
