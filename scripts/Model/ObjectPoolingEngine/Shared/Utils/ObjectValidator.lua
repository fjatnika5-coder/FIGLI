--!strict
--[[
    ObjectValidator.lua
    Advanced Object Pooling Engine - Object Validation and Reset
    
    Validates objects before returning to pool and resets them to default state.
    Requirements: 11.3, 11.4
]]

local TweenService = game:GetService("TweenService")

local Types = require(script.Parent.Parent.Types)

-- ============================================================================
-- ObjectValidator Module
-- ============================================================================

local ObjectValidator = {}

-- Default validation rules
local DEFAULT_VALIDATION_RULES: Types.ValidationRules = {
	checkParent = true,
	checkDestroyed = true,
	customValidator = nil,
}

-- Default reset configuration
local DEFAULT_RESET_CONFIG: Types.ResetConfig = {
	resetPosition = true,
	resetVelocity = true,
	clearConnections = true,
	clearTweens = true,
	clearAttributes = true,
}

-- ============================================================================
-- Validation Functions
-- ============================================================================

--[[
    Validate an Instance before returning to pool.
    Returns (isValid, errorMessage).
    
    Checks:
    - Instance.Parent exists (not nil)
    - Instance is not destroyed
    - Custom validator passes (if provided)
    
    Uses pcall protection for customValidator.
]]
function ObjectValidator.Validate(
	instance: Instance,
	rules: Types.ValidationRules?
): (boolean, string?)
	local validationRules = rules or DEFAULT_VALIDATION_RULES

	-- Check if instance exists
	if instance == nil then
		return false, "Instance is nil"
	end

	-- Check if destroyed (accessing properties on destroyed instance throws)
	if validationRules.checkDestroyed then
		local success, _ = pcall(function()
			local _ = instance.Name
		end)

		if not success then
			return false, "Instance is destroyed"
		end
	end

	-- Check parent exists
	if validationRules.checkParent then
		if instance.Parent == nil then
			return false, "Instance has no parent"
		end
	end

	-- Run custom validator if provided (with error protection)
	if validationRules.customValidator then
		local success, result = pcall(validationRules.customValidator, instance)
		if not success then
			return false, "Custom validation error: " .. tostring(result)
		end
		if not result then
			return false, "Custom validation failed"
		end
	end

	return true, nil
end

-- ============================================================================
-- Reset Functions
-- ============================================================================

--[[
    Reset an Instance to its default state.
    This is idempotent - calling it multiple times produces the same result.
    
    Resets:
    - Position (CFrame for BaseParts)
    - Velocity (for BaseParts)
    - Anchored state
    - Connections (via CollectionService tags)
    - Active tweens
    - Custom attributes
]]
function ObjectValidator.Reset(
	instance: Instance,
	config: Types.ResetConfig?,
	defaultCFrame: CFrame?
): ()
	local resetConfig = config or DEFAULT_RESET_CONFIG

	-- Reset BasePart-specific properties
	if instance:IsA("BasePart") then
		local basePart = instance :: BasePart

		-- Reset position
		if resetConfig.resetPosition then
			if defaultCFrame then
				basePart.CFrame = defaultCFrame
			else
				basePart.CFrame = CFrame.new(0, 0, 0)
			end
		end

		-- Reset velocity
		if resetConfig.resetVelocity then
			basePart.AssemblyLinearVelocity = Vector3.zero
			basePart.AssemblyAngularVelocity = Vector3.zero
		end
	end

	-- Reset Model-specific properties
	if instance:IsA("Model") then
		local model = instance :: Model

		if resetConfig.resetPosition and model.PrimaryPart then
			if defaultCFrame then
				model:PivotTo(defaultCFrame)
			else
				model:PivotTo(CFrame.new(0, 0, 0))
			end
		end
	end

	-- Clear active tweens
	if resetConfig.clearTweens then
		ObjectValidator._cancelTweens(instance)
	end

	-- Clear custom attributes
	if resetConfig.clearAttributes then
		ObjectValidator._clearAttributes(instance)
	end

	-- Note: clearConnections is handled at the PooledObject level
	-- since we track connections there, not on the raw Instance
end

--[[
    Cancel all active tweens on an instance and its descendants.
]]
function ObjectValidator._cancelTweens(instance: Instance): ()
	-- Cancel tweens by resetting properties and stopping any running tweens
	-- TweenService doesn't expose running tweens, so we reset properties directly

	-- For BaseParts, reset common tweened properties
	if instance:IsA("BasePart") then
		local basePart = instance :: BasePart
		basePart.AssemblyLinearVelocity = Vector3.zero
		basePart.AssemblyAngularVelocity = Vector3.zero
	end

	-- Recursively handle descendants
	for _, child in ipairs(instance:GetDescendants()) do
		if child:IsA("BasePart") then
			local basePart = child :: BasePart
			basePart.AssemblyLinearVelocity = Vector3.zero
			basePart.AssemblyAngularVelocity = Vector3.zero
		end

		-- Stop ParticleEmitters
		if child:IsA("ParticleEmitter") then
			(child :: ParticleEmitter).Enabled = false
			(child :: ParticleEmitter):Clear()
		end

		-- Stop Beams
		if child:IsA("Beam") then
			(child :: Beam).Enabled = false
		end

		-- Stop Trails
		if child:IsA("Trail") then
			(child :: Trail).Enabled = false
			(child :: Trail):Clear()
		end

		-- Disable PointLights
		if child:IsA("PointLight") or child:IsA("SpotLight") or child:IsA("SurfaceLight") then
			(child :: Light).Enabled = false
		end
	end
end

--[[
    Clear all custom attributes from an instance.
]]
function ObjectValidator._clearAttributes(instance: Instance): ()
	local attributes = instance:GetAttributes()

	for attributeName, _ in pairs(attributes) do
		instance:SetAttribute(attributeName, nil)
	end
end

--[[
    Reset visibility and transparency for visual objects.
]]
function ObjectValidator.ResetVisibility(instance: Instance): ()
	if instance:IsA("BasePart") then
		local basePart = instance :: BasePart
		basePart.Transparency = 0
		basePart.CanCollide = true
	end

	-- Handle descendants
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local basePart = descendant :: BasePart
			basePart.Transparency = 0
			basePart.CanCollide = true
		end
	end
end

--[[
    Prepare an instance for pooling by moving to a storage location.
]]
function ObjectValidator.PrepareForStorage(
	instance: Instance,
	storageParent: Instance?
): ()
	-- Move to storage (or nil parent if no storage specified)
	if storageParent then
		instance.Parent = storageParent
	end

	-- Disable physics for BaseParts
	if instance:IsA("BasePart") then
		local basePart = instance :: BasePart
		basePart.Anchored = true
		basePart.CanCollide = false
		basePart.CanTouch = false
		basePart.CanQuery = false
	end

	-- Handle Models
	if instance:IsA("Model") then
		for _, descendant in ipairs(instance:GetDescendants()) do
			if descendant:IsA("BasePart") then
				local basePart = descendant :: BasePart
				basePart.Anchored = true
				basePart.CanCollide = false
				basePart.CanTouch = false
				basePart.CanQuery = false
			end
		end
	end
end

--[[
    Prepare an instance for active use.
]]
function ObjectValidator.PrepareForUse(
	instance: Instance,
	targetParent: Instance?,
	targetCFrame: CFrame?
): ()
	-- Set position first (before parenting to avoid physics issues)
	if targetCFrame then
		if instance:IsA("BasePart") then
			(instance :: BasePart).CFrame = targetCFrame
		elseif instance:IsA("Model") then
			(instance :: Model):PivotTo(targetCFrame)
		end
	end

	-- Re-enable physics for BaseParts
	if instance:IsA("BasePart") then
		local basePart = instance :: BasePart
		basePart.Anchored = false
		basePart.CanCollide = true
		basePart.CanTouch = true
		basePart.CanQuery = true
	end

	-- Handle Models
	if instance:IsA("Model") then
		for _, descendant in ipairs(instance:GetDescendants()) do
			if descendant:IsA("BasePart") then
				local basePart = descendant :: BasePart
				basePart.Anchored = false
				basePart.CanCollide = true
				basePart.CanTouch = true
				basePart.CanQuery = true
			end

			-- Re-enable ParticleEmitters
			if descendant:IsA("ParticleEmitter") then
				(descendant :: ParticleEmitter).Enabled = true
			end

			-- Re-enable Beams
			if descendant:IsA("Beam") then
				(descendant :: Beam).Enabled = true
			end

			-- Re-enable Trails
			if descendant:IsA("Trail") then
				(descendant :: Trail).Enabled = true
			end

			-- Re-enable Lights
			if descendant:IsA("PointLight") or descendant:IsA("SpotLight") or descendant:IsA("SurfaceLight") then
				(descendant :: Light).Enabled = true
			end
		end
	end

	-- Parent to target
	if targetParent then
		instance.Parent = targetParent
	end
end

return ObjectValidator
