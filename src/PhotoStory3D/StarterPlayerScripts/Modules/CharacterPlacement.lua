--!nonstrict
-- CharacterPlacement: tempatkan model di permukaan tanah/part DI BAWAH titik.
-- GirlPoint/BoyPoint = patokan X/Z + arah hadap (rotasi Y), BUKAN posisi kaki final.
-- Raycast turun cari lantai anchored/terrain -> kaki nempel (tidak melayang / tidak nembus).
-- Return: ok(boolean), grounded(boolean). grounded=false artinya tidak ada lantai (fallback ke titik).

local Players   = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local CharacterPlacement = {}

local CLONE_PREFIX = "PhotoStoryClone_"

local function pointCFrame(point)
	if not point then return nil end
	if point:IsA("BasePart") then return point.CFrame
	elseif point:IsA("Attachment") then return point.WorldCFrame
	elseif point:IsA("Model") then return point:GetPivot() end
	return nil
end

-- arah hadap saja (buang pitch/roll, jaga tegak)
local function yawOnly(cf)
	local _, y, _ = cf:ToEulerAnglesYXZ()
	return CFrame.Angles(0, y, 0)
end

local function buildIgnore(selfModel)
	local ignore = { selfModel }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then ignore[#ignore + 1] = p.Character end
	end
	for _, c in ipairs(Workspace:GetChildren()) do
		if c:IsA("Model") and string.sub(c.Name, 1, #CLONE_PREFIX) == CLONE_PREFIX and c ~= selfModel then
			ignore[#ignore + 1] = c
		end
	end
	return ignore
end

-- ResolveGroundedCFrame + apply. model harus sudah punya parent (untuk GetBoundingBox).
function CharacterPlacement.PlaceModel(model, point)
	local base = pointCFrame(point)
	if not base or not model then return false, false end

	if model.Parent == nil then
		model.Parent = Workspace
	end

	-- Set arah hadap dulu (tegak, yaw dari titik) di posisi titik untuk ukur bounding box.
	local upright = CFrame.new(base.Position) * yawOnly(base)
	model:PivotTo(upright)

	-- Raycast turun dari atas titik (titik bisa ditaruh tinggi -> player tetap turun ke lantai).
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = buildIgnore(model)
	rp.IgnoreWater = false

	local origin = base.Position + Vector3.new(0, 50, 0)
	local result = Workspace:Raycast(origin, Vector3.new(0, -250, 0), rp)

	local grounded = false
	local groundY  = base.Position.Y
	if result then
		local inst = result.Instance
		-- hanya lantai stabil: terrain atau part anchored
		if inst == nil or inst:IsA("Terrain") or (inst:IsA("BasePart") and inst.Anchored) then
			groundY  = result.Position.Y
			grounded = true
		end
	end

	-- Angkat/turunkan supaya BAWAH rig (kaki) = groundY.
	local bbCF, bbSize = model:GetBoundingBox()
	local bottomY = bbCF.Position.Y - bbSize.Y * 0.5
	local lift = groundY - bottomY
	model:PivotTo(CFrame.new(0, lift, 0) * model:GetPivot())

	-- Clone diam di tempat (root anchored, limb tetap dianimasikan Motor6D).
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp then hrp.Anchored = true end

	return true, grounded
end

return CharacterPlacement
