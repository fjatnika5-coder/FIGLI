

local CastingSystem = {}
CastingSystem.__index = CastingSystem

CastingSystem._activeBeamsByRodPart = setmetatable({}, { __mode = "k" })
CastingSystem._BEAM_TAG_ATTR = "__FishingBeam"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

-- ✅ ADDED: Object Pooling Engine (for Hooks only)
local EasyPool = require(game:GetService("ReplicatedStorage"):WaitForChild("ObjectPoolingEngine"):WaitForChild("Shared"):WaitForChild("EasyPool"))

-- ✅ ADDED: Hook template for pooling
local hookTemplate = Instance.new("Part")
hookTemplate.Name = "Hook"
hookTemplate.Shape = Enum.PartType.Ball
hookTemplate.Size = Vector3.new(0.45, 0.45, 0.45)
hookTemplate.CanCollide = false
hookTemplate.Massless = true
hookTemplate.Anchored = false
hookTemplate.Transparency = 1 -- keep invisible until placed

local _hookBeamTarget = Instance.new("Attachment")
_hookBeamTarget.Name = "BeamTarget"
_hookBeamTarget.Parent = hookTemplate

-- =========================
-- SAFE HasTag (anti "Argument 1 missing or nil")
-- =========================
local function HasTagSafe(inst, tag)
	if typeof(inst) ~= "Instance" then return false end
	local ok, res = pcall(function()
		return CollectionService:HasTag(inst, tag)
	end)
	return ok and res == true
end

-- =========================
-- small helpers
-- =========================
local function ensureList(self, rodPart)
	local t = self._activeBeamsByRodPart[rodPart]
	if type(t) ~= "table" then
		t = {}
		self._activeBeamsByRodPart[rodPart] = t
	end
	return t
end

local function ensureAttachment(parent, name)
	if not parent then return nil end
	local a = parent:FindFirstChild(name)
	if a and not a:IsA("Attachment") then
		a:Destroy()
		a = nil
	end
	if not a then
		a = Instance.new("Attachment")
		a.Name = name
		a.Parent = parent
	end
	return a
end

local function findAttachment0(rodPart)
	if not rodPart then return nil end
	local names = { "0", "Attachment0", "RodLineAtt0", "LineAttachment", "LineAtt0" }
	for _, n in ipairs(names) do
		local a = rodPart:FindFirstChild(n)
		if a and a:IsA("Attachment") then return a end
	end
	for _, ch in ipairs(rodPart:GetChildren()) do
		if ch:IsA("Attachment") then return ch end
	end
	for _, d in ipairs(rodPart:GetDescendants()) do
		if d:IsA("Attachment") then return d end
	end
	return nil
end

local function getRodBeamFolder()
	local fs = ReplicatedStorage:FindFirstChild("FishingSystem")
	if not fs then return nil end
	return fs:FindFirstChild("RodBeams")
end

local function collectBeamTemplatesFromInstance(container)
	local templates = {}
	if not container then return templates end
	if container:IsA("Beam") then
		table.insert(templates, container)
		return templates
	end
	for _, d in ipairs(container:GetDescendants()) do
		if d:IsA("Beam") then
			table.insert(templates, d)
		end
	end
	return templates
end

local function isBeamCreatedByModule(self, beam)
	return beam and beam:IsA("Beam") and beam:GetAttribute(self._BEAM_TAG_ATTR) == true
end

local function getBeamTemplatesForRod(self, rodName, rodPart)
	local templates = {}

	local beamFolder = getRodBeamFolder()
	if beamFolder and rodName then
		local byName =
			beamFolder:FindFirstChild(rodName)
			or beamFolder:FindFirstChild(rodName .. "Beam")
			or beamFolder:FindFirstChild(rodName .. "_Beam")

		if byName then
			templates = collectBeamTemplatesFromInstance(byName)
			if #templates > 0 then
				return templates
			end
		end
	end

	if rodPart then
		for _, d in ipairs(rodPart:GetDescendants()) do
			if d:IsA("Beam") and not isBeamCreatedByModule(self, d) then
				table.insert(templates, d)
			end
		end
	end

	return templates
end

local function makeFallbackBeam()
	local b = Instance.new("Beam")
	b.Name = "Line"
	b.Width0 = 0.05
	b.Width1 = 0.05
	b.FaceCamera = true
	b.Enabled = true
	return b
end

local function isWaterInstance(inst, material)
	if not inst then return false end

	if inst:IsA("Terrain") and material == Enum.Material.Water then
		return true
	end

	if inst:IsA("BasePart") then
		if inst.Material == Enum.Material.Water then
			return true
		end
		if HasTagSafe(inst, "Water") then
			return true
		end
	end

	return false
end

local function makeRayParams(ignoreList)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.IgnoreWater = false
	rp.FilterDescendantsInstances = (type(ignoreList) == "table") and ignoreList or {}
	return rp
end

-- =========================
-- Public API
-- =========================
function CastingSystem:GetBestRodAttachment0(rodPart)
	return findAttachment0(rodPart)
end

function CastingSystem:GetRodBeams(rodPart)
	local list = self._activeBeamsByRodPart[rodPart]
	if type(list) ~= "table" then return {} end

	local out = {}
	for _, b in ipairs(list) do
		if b and b.Parent then
			table.insert(out, b)
		end
	end
	self._activeBeamsByRodPart[rodPart] = out
	return out
end

-- ✅ IMPROVED: Better cleanup with pcall protection
function CastingSystem:DetachBeamsFromRod(rodPart)
	if not rodPart then return end

	-- 🆕 TRACK DESTROYED BEAMS (PREVENT DOUBLE DESTROY)
	local destroyedBeams = {}

	-- Cleanup tracked beams
	local beams = self:GetRodBeams(rodPart)
	for _, beam in ipairs(beams) do
		if beam and beam.Parent then
			pcall(function()
				beam.Enabled = false
				beam.Attachment1 = nil
				beam:Destroy()
			end)
			destroyedBeams[beam] = true
		end
	end
	self._activeBeamsByRodPart[rodPart] = {}

	-- 🆕 CLEANUP ORPHANED BEAMS (SKIP ALREADY DESTROYED)
	for _, d in ipairs(rodPart:GetDescendants()) do
		if d:IsA("Beam") 
			and d:GetAttribute(self._BEAM_TAG_ATTR) == true 
			and not destroyedBeams[d] then

			pcall(function()
				d.Enabled = false
				d.Attachment1 = nil
				d:Destroy()
			end)
		end
	end
end

function CastingSystem:CreateBeam(rodPart, att0, att1, rodName)
	if not rodPart or not att1 then return nil end

	self:DetachBeamsFromRod(rodPart)

	if not att0 then att0 = findAttachment0(rodPart) end
	if not att0 then att0 = ensureAttachment(rodPart, "RodLineAtt0") end

	local templates = getBeamTemplatesForRod(self, rodName, rodPart)

	local created = {}
	if #templates > 0 then
		for _, tpl in ipairs(templates) do
			-- 🆕 ADD PCALL PROTECTION
			local success, beam = pcall(function()
				local b = tpl:Clone()
				b.Name = "Line"
				b.Attachment0 = att0
				b.Attachment1 = att1
				b.Enabled = true
				b:SetAttribute(self._BEAM_TAG_ATTR, true)
				b.Parent = rodPart
				return b
			end)

			if success and beam then
				table.insert(created, beam)
			end
		end
	else
		local beam = makeFallbackBeam()
		beam.Attachment0 = att0
		beam.Attachment1 = att1
		beam:SetAttribute(self._BEAM_TAG_ATTR, true)
		beam.Parent = rodPart
		table.insert(created, beam)
	end

	local list = ensureList(self, rodPart)
	for _, b in ipairs(created) do
		table.insert(list, b)
	end

	return created
end

-- ✅ CHANGED: Hook now uses EasyPool instead of Instance.new
-- pcall protection: pool may return destroyed instances (cleanup/eviction)
function CastingSystem:CreateHook(pos)
	local hook = EasyPool.Get("Fishing_Hook", hookTemplate)

	local poolSuccess = false
	if hook then
		-- pcall: pool instance may have been destroyed by cleanup timer
		local ok = pcall(function()
			hook.Anchored = false
			hook.CanCollide = false
			hook.Massless = true
			hook.AssemblyLinearVelocity = Vector3.zero
			hook.AssemblyAngularVelocity = Vector3.zero
			hook.Position = pos
			hook.Parent = workspace
		end)

		if ok then
			poolSuccess = true
			-- Ensure BeamTarget attachment exists (should persist from template)
			if not hook:FindFirstChild("BeamTarget") then
				ensureAttachment(hook, "BeamTarget")
			end
		end
	end

	if not poolSuccess then
		-- Fallback: create manually if pool fails or returns destroyed object
		hook = Instance.new("Part")
		hook.Name = "Hook"
		hook.Shape = Enum.PartType.Ball
		hook.Size = Vector3.new(0.45, 0.45, 0.45)
		hook.CanCollide = false
		hook.Massless = true
		hook.Anchored = false
		hook.Position = pos
		hook.Parent = workspace
		ensureAttachment(hook, "BeamTarget")
	end

	return hook
end

-- ✅ ADDED: Return hook to pool (call this instead of hook:Destroy())
function CastingSystem:ReturnHook(hook)
	if not hook then return end
	pcall(function()
		-- Stop physics before returning to pool
		hook.Anchored = true
		hook.AssemblyLinearVelocity = Vector3.zero
		hook.AssemblyAngularVelocity = Vector3.zero

		if not EasyPool.Return(hook) then
			hook:Destroy() -- Fallback if not pooled
		end
	end)
end

function CastingSystem:IsPositionInWater(pos, ignoreList, probeDepth)
	local depth = math.clamp(tonumber(probeDepth) or 3.5, 1.5, 14)
	local from = pos + Vector3.new(0, 0.8, 0)
	local dir = Vector3.new(0, -depth, 0)

	local rp = makeRayParams(ignoreList)
	local result = Workspace:Raycast(from, dir, rp)
	if result and result.Instance then
		return isWaterInstance(result.Instance, result.Material)
	end
	return false
end

function CastingSystem:GetWaterSurfaceY(x, z, ignoreList)
	local rp = makeRayParams(ignoreList)

	local y = 600
	local steps = 60
	local stepDown = 22
	local scanLen = 60

	for _ = 1, steps do
		local from = Vector3.new(x, y, z)
		local dir = Vector3.new(0, -scanLen, 0)
		local result = Workspace:Raycast(from, dir, rp)

		if not (result and result.Instance) then
			y -= stepDown
		else
			if result.Instance:IsA("Terrain") and result.Material == Enum.Material.Water then
				return result.Position.Y
			end

			if result.Instance:IsA("BasePart") and isWaterInstance(result.Instance, result.Material) then
				return result.Instance.Position.Y + (result.Instance.Size.Y * 0.5)
			end

			y = result.Position.Y - 0.25
		end

		if y < -200 then break end
	end

	return nil
end

function CastingSystem:CalculateVelocity(originPos, lookVector, power, maxDistance)
	if typeof(originPos) ~= "Vector3" then
		return Vector3.zero
	end

	local lv = (typeof(lookVector) == "Vector3" and lookVector.Magnitude > 0.001) and lookVector.Unit or Vector3.new(0, 0, -1)
	local p = math.clamp(tonumber(power) or 50, 1, 100)
	local maxDist = tonumber(maxDistance) or 65

	local dist = maxDist * (0.45 + 0.75 * (p / 100))
	dist = math.clamp(dist, 18, maxDist)

	local targetPos = originPos + lv * dist
	local displacement = targetPos - originPos
	local d = displacement.Magnitude

	local t = math.clamp(d / 115, 0.48, 0.85)

	local g = Vector3.new(0, -workspace.Gravity, 0)
	local v = (displacement - 0.5 * g * (t * t)) / t

	v = Vector3.new(v.X, math.clamp(v.Y, 8, 26), v.Z)
	return v
end

return CastingSystem
