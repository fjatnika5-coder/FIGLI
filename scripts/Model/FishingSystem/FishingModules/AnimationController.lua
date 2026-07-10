-- ════════════════════════════════════════════════════════════════
-- ✅ ANIMATION CONTROLLER - SEAMLESS TRANSITIONS VERSION
-- Location: ReplicatedStorage/FishingModules/AnimationController
-- ════════════════════════════════════════════════════════════════
local AnimationController = {}
local RepStorage = game:GetService("ReplicatedStorage"):WaitForChild("FishingSystem")

local loadedAnimations = {}
local currentAnimation = nil
local currentAnimationName = nil
local currentHumanoid = nil
local currentRodName = nil
local animationsFolder = nil

-- Flag untuk prevent race condition
local isPlayingSequence = false
local sequenceId = 0

-- ═══════════════════════════════════════════════════════════════
-- ✅ TRANSITION CONFIG
-- ═══════════════════════════════════════════════════════════════
local DEFAULT_FADE_IN = 0.05
local DEFAULT_FADE_OUT = 0.05
local SEQUENCE_CROSSFADE = 0

-- ═══════════════════════════════════════════════════════════════
-- ✅ DEBUG SETTINGS
-- ═══════════════════════════════════════════════════════════════
local DEBUG_ENABLED = false

local function debugPrint(...)
	if DEBUG_ENABLED then
		print("[AnimController]", ...)
	end
end

local function debugWarn(...)
	if DEBUG_ENABLED then
		warn("[AnimController]", ...)
	end
end

-- ═══════════════════════════════════════════════════════════════
-- ✅ ROD-SPECIFIC ANIMATION CONFIG
-- ═══════════════════════════════════════════════════════════════
local ROD_ANIMATIONS = {
	["The Vanquisher"] = { useCustomFolder = true },
	["Eternal Flower"] = { useCustomFolder = true },
	["Blackhole Sword"] = { useCustomFolder = true },
	["Aurelian Rod"] = { useCustomFolder = true },
	["x1x1x1 Hammer"] = { useCustomFolder = true },
	["Crescendo Scythe"] = { useCustomFolder = true },
	["Aether Monarch"] = { useCustomFolder = true },
	["Wings of Everlove"] = { useCustomFolder = true },
	["Jiyu"] = { useCustomFolder = true },
	["AdminRod"] = { useCustomFolder = true },
	["AscensionRod"] = { useCustomFolder = true },
	["OblivonRod"] = { useCustomFolder = true },
	["Princess Parasol"] = { useCustomFolder = true },
	["FrozenkRod"] = { useCustomFolder = true },
	["Mei"] = { useCustomFolder = true },
	["Gulabatu"] = { useCustomFolder = true },
	["OwnerRod"] = { useCustomFolder = true },
	["Esteh"] = { useCustomFolder = true },
	["Vin"] = { useCustomFolder = true },
	["Nine"] = { useCustomFolder = true },
	["Cherryna"] = { useCustomFolder = true },
	["Kyouyariin"] = { useCustomFolder = true },
	["Slash Katana"] = { useCustomFolder = true },
	["UmbraluxRod"] = { useCustomFolder = true },
	["AuraluxRod"] = { useCustomFolder = true },
	["Youkatta"] = { useCustomFolder = true },
	["Jiyuu"] = { useCustomFolder = true },
	["Soya"] = { useCustomFolder = true },
	["Solitario"] = { useCustomFolder = true },
	["PASEP"] = { useCustomFolder = true },
	["Ceisya"] = { useCustomFolder = true },
	["Little"] = { useCustomFolder = true },
	["Miyuki"] = { useCustomFolder = true },
	["Dark Matter Scythe"] = { useCustomFolder = true },
	["Cupid Harp"] = { useCustomFolder = true, hasTwoWaiting = true },
}

-- ✅ Base animations semua rod load
local DEFAULT_ANIMATIONS = {
	"EquippedAnimation",
	"CatchAnimation",
	"WaitingAnimation",
	"PullingAnimation",
}

-- ✅ Extra animations khusus rod tertentu
local EXTRA_ANIMATIONS = {
	"WaitingAnimation2",
}

-- ✅ ANIMATION PRIORITY
local ANIMATION_PRIORITY = Enum.AnimationPriority.Action2

-- ═══════════════════════════════════════════════════════════════
-- CLEANUP FUNCTION
-- ═══════════════════════════════════════════════════════════════
local function destroyLoadedAnimations()
	debugPrint("Cleaning up animations...")

	for animName, animTrack in pairs(loadedAnimations) do
		if animTrack then
			pcall(function()
				if animTrack.IsPlaying then
					animTrack:Stop(0)
				end
				animTrack:Destroy()
			end)
		end
	end
	loadedAnimations = {}
	currentAnimation = nil
	currentAnimationName = nil
end

-- ═══════════════════════════════════════════════════════════════
-- ✅ LOAD ANIMATIONS BASED ON ROD
-- ═══════════════════════════════════════════════════════════════
local function loadAnimationsForRod(humanoid, rodName)
	if not humanoid or not humanoid.Parent then return end
	if not animationsFolder then return end

	debugPrint("Loading animations for rod:", rodName or "Default")

	local rodConfig = ROD_ANIMATIONS[rodName]
	local loadedCount = 0

	-- ✅ Build animation list: base + extras kalau rod butuh
	local animsToLoad = {}
	for _, name in ipairs(DEFAULT_ANIMATIONS) do
		table.insert(animsToLoad, name)
	end
	if rodConfig and rodConfig.hasTwoWaiting then
		for _, name in ipairs(EXTRA_ANIMATIONS) do
			table.insert(animsToLoad, name)
		end
	end

	for _, animName in ipairs(animsToLoad) do
		local animObject = nil

		if rodConfig then
			if rodConfig.useCustomFolder then
				local customFolder = animationsFolder:FindFirstChild(rodName)
				if customFolder then
					animObject = customFolder:FindFirstChild(animName)
				end
			end

			if not animObject and rodConfig[animName] then
				animObject = Instance.new("Animation")
				animObject.AnimationId = rodConfig[animName]
			end
		end

		if not animObject then
			animObject = animationsFolder:FindFirstChild(animName)
		end

		if animObject then
			local success, animTrack = pcall(function()
				return humanoid:LoadAnimation(animObject)
			end)

			if success and animTrack then
				animTrack.Priority = ANIMATION_PRIORITY

				-- ✅ WaitingAnimation2 & EquippedAnimation = loop
				-- WaitingAnimation = loop KECUALI rod hasTwoWaiting (jadi one-shot transition)
				if animName == "EquippedAnimation" or animName == "WaitingAnimation2" then
					animTrack.Looped = true
				elseif animName == "WaitingAnimation" then
					if rodConfig and rodConfig.hasTwoWaiting then
						animTrack.Looped = false -- one-shot transition ke Waiting2
					else
						animTrack.Looped = true -- normal hold
					end
				else
					animTrack.Looped = false
				end

				loadedAnimations[animName] = animTrack
				loadedCount = loadedCount + 1
			end

			if rodConfig and rodConfig[animName] and animObject then
				animObject:Destroy()
			end
		end
	end

	debugPrint("Total animations loaded:", loadedCount)
end

-- ═══════════════════════════════════════════════════════════════
-- ✅ INTERNAL: Crossfade - play new BEFORE stopping old
-- ═══════════════════════════════════════════════════════════════
local function crossfadeTo(animName, fadeIn, fadeOut)
	fadeIn = fadeIn or DEFAULT_FADE_IN
	fadeOut = fadeOut or DEFAULT_FADE_OUT

	local newAnim = loadedAnimations[animName]
	if not newAnim then
		debugWarn("Animation not loaded:", animName)
		return nil
	end

	local oldAnim = currentAnimation

	local playOk = pcall(function()
		newAnim:Play(fadeIn)
	end)

	if not playOk then
		debugWarn("Failed to play:", animName)
		return nil
	end

	if oldAnim and oldAnim ~= newAnim then
		pcall(function()
			if oldAnim.IsPlaying then
				oldAnim:Stop(fadeOut)
			end
		end)
	end

	currentAnimation = newAnim
	currentAnimationName = animName

	return newAnim
end

-- ═══════════════════════════════════════════════════════════════
-- ✅ INTERNAL: Hard stop
-- ═══════════════════════════════════════════════════════════════
local function stopCurrentAnimation(fadeTime)
	fadeTime = fadeTime or 0
	if currentAnimation then
		pcall(function()
			if currentAnimation.IsPlaying then
				currentAnimation:Stop(fadeTime)
			end
		end)
		currentAnimation = nil
		currentAnimationName = nil
	end
end

-- ═══════════════════════════════════════════════════════════════
-- PUBLIC API
-- ═══════════════════════════════════════════════════════════════
function AnimationController:Initialize(humanoid)
	if not humanoid or not humanoid.Parent then return end

	animationsFolder = RepStorage:WaitForChild("Assets"):WaitForChild("Animations"):WaitForChild("Fishing")
	currentHumanoid = humanoid
	isPlayingSequence = false
	sequenceId = 0

	destroyLoadedAnimations()
	loadAnimationsForRod(humanoid, nil)
end

function AnimationController:SetRod(rodName)
	if currentRodName == rodName then return end

	local oldRodHasCustom = ROD_ANIMATIONS[currentRodName] ~= nil
	local newRodHasCustom = ROD_ANIMATIONS[rodName] ~= nil

	currentRodName = rodName

	if oldRodHasCustom or newRodHasCustom then
		isPlayingSequence = false
		sequenceId = sequenceId + 1
		self:Stop()
		destroyLoadedAnimations()

		if currentHumanoid and currentHumanoid.Parent then
			loadAnimationsForRod(currentHumanoid, rodName)
		end
	end
end

function AnimationController:ClearRod()
	isPlayingSequence = false
	sequenceId = sequenceId + 1

	if currentRodName and ROD_ANIMATIONS[currentRodName] then
		self:Stop()
		destroyLoadedAnimations()

		if currentHumanoid and currentHumanoid.Parent then
			loadAnimationsForRod(currentHumanoid, nil)
		end
	end
	currentRodName = nil
end

function AnimationController:Play(animationName, fadeTime)
	fadeTime = fadeTime or DEFAULT_FADE_IN
	return crossfadeTo(animationName, fadeTime, DEFAULT_FADE_OUT)
end

function AnimationController:Stop(fadeTime)
	fadeTime = fadeTime or DEFAULT_FADE_OUT

	isPlayingSequence = false
	sequenceId = sequenceId + 1

	stopCurrentAnimation(fadeTime)

	for name, anim in pairs(loadedAnimations) do
		pcall(function()
			if anim.IsPlaying then
				anim:Stop(fadeTime)
			end
		end)
	end
end

function AnimationController:TransitionTo(animationName, fadeTime)
	return self:Play(animationName, fadeTime or DEFAULT_FADE_IN)
end

function AnimationController:Reload(humanoid)
	isPlayingSequence = false
	sequenceId = sequenceId + 1
	self:Stop()
	destroyLoadedAnimations()
	currentHumanoid = humanoid

	if humanoid and humanoid.Parent then
		animationsFolder = RepStorage:WaitForChild("Assets"):WaitForChild("Animations"):WaitForChild("Fishing")
		loadAnimationsForRod(humanoid, currentRodName)
	end
end

function AnimationController:Cleanup()
	isPlayingSequence = false
	sequenceId = sequenceId + 1
	self:Stop()
	destroyLoadedAnimations()
	currentRodName = nil
	currentHumanoid = nil
end

-- ═══════════════════════════════════════════════════════════════
-- ✅ ANIMATION SEQUENCES
-- ═══════════════════════════════════════════════════════════════

function AnimationController:PlayCastSequence()
	debugPrint("Playing Cast Sequence")

	sequenceId = sequenceId + 1
	local mySequenceId = sequenceId
	isPlayingSequence = true

	local catchAnim = loadedAnimations["CatchAnimation"]
	local waitingAnim = loadedAnimations["WaitingAnimation"]
	local waitingAnim2 = loadedAnimations["WaitingAnimation2"]

	if not waitingAnim then
		isPlayingSequence = false
		return
	end

	local function isSequenceValid()
		return isPlayingSequence and sequenceId == mySequenceId
	end

	local rodConfig = ROD_ANIMATIONS[currentRodName]
	local hasTwoWaiting = rodConfig and rodConfig.hasTwoWaiting and waitingAnim2

	-- ═══════════════════════════════════════════════════════
	-- ✅ CUPID HARP: Catch → Waiting1 (one-shot) → Waiting2 (loop hold)
	-- ✅ NORMAL:     Catch → Waiting (loop hold)
	-- ═══════════════════════════════════════════════════════

	local function playFinalWaiting()
		if not isSequenceValid() then return end

		if hasTwoWaiting then
			-- ✅ Stage 1: WaitingAnimation (one-shot transition)
			pcall(function() waitingAnim:Play(SEQUENCE_CROSSFADE) end)
			currentAnimation = waitingAnim
			currentAnimationName = "WaitingAnimation"

			-- When Waiting1 ends → instant crossfade to Waiting2
			local w1Connection
			w1Connection = waitingAnim.Ended:Once(function()
				if not isSequenceValid() then return end

				-- ✅ Stage 2: WaitingAnimation2 (loop hold until pull)
				pcall(function() waitingAnim2:Play(SEQUENCE_CROSSFADE) end)
				currentAnimation = waitingAnim2
				currentAnimationName = "WaitingAnimation2"
				isPlayingSequence = false
			end)

			-- Safety timeout Waiting1
			task.delay(5, function()
				if isSequenceValid() and currentAnimationName == "WaitingAnimation" then
					if w1Connection then pcall(function() w1Connection:Disconnect() end) end
					if not waitingAnim2.IsPlaying then
						pcall(function() waitingAnim2:Play(SEQUENCE_CROSSFADE) end)
						currentAnimation = waitingAnim2
						currentAnimationName = "WaitingAnimation2"
					end
					isPlayingSequence = false
				end
			end)
		else
			-- ✅ Normal rod: WaitingAnimation loop hold
			pcall(function() waitingAnim:Play(SEQUENCE_CROSSFADE) end)
			currentAnimation = waitingAnim
			currentAnimationName = "WaitingAnimation"
			isPlayingSequence = false
		end
	end

	-- ✅ No CatchAnimation → skip to waiting
	if not catchAnim then
		playFinalWaiting()
		return
	end

	-- ✅ Play CatchAnimation first
	crossfadeTo("CatchAnimation", SEQUENCE_CROSSFADE, SEQUENCE_CROSSFADE)

	local endedConnection
	endedConnection = catchAnim.Ended:Once(function()
		if not isSequenceValid() then return end
		playFinalWaiting()
	end)

	-- Safety timeout CatchAnimation
	task.delay(5, function()
		if isSequenceValid() and currentAnimationName == "CatchAnimation" then
			if endedConnection then pcall(function() endedConnection:Disconnect() end) end
			playFinalWaiting()
		end
	end)
end

function AnimationController:PlayPullingSequence()
	isPlayingSequence = false
	sequenceId = sequenceId + 1
	crossfadeTo("PullingAnimation", SEQUENCE_CROSSFADE, SEQUENCE_CROSSFADE)
end

function AnimationController:PlayIdleSequence()
	isPlayingSequence = false
	sequenceId = sequenceId + 1
	crossfadeTo("EquippedAnimation", DEFAULT_FADE_IN, DEFAULT_FADE_OUT)
end

-- ═══════════════════════════════════════════════════════════════
-- ✅ DEBUG HELPERS
-- ═══════════════════════════════════════════════════════════════

function AnimationController:GetLoadedAnimationNames()
	local names = {}
	for name, _ in pairs(loadedAnimations) do
		table.insert(names, name)
	end
	return names
end

function AnimationController:GetCurrentAnimation()
	return currentAnimationName
end

function AnimationController:IsPlaying(animationName)
	if animationName then
		local anim = loadedAnimations[animationName]
		return anim and anim.IsPlaying
	else
		return currentAnimation and currentAnimation.IsPlaying
	end
end

function AnimationController:IsPlayingSequence()
	return isPlayingSequence
end

function AnimationController:PrintDebugInfo()
	print("═══════════════════════════════════════")
	print("ANIMATION CONTROLLER DEBUG")
	print("═══════════════════════════════════════")
	print("Current Rod:", currentRodName or "None")
	print("Current Humanoid:", currentHumanoid and "Valid" or "Invalid")
	print("Is Playing Sequence:", isPlayingSequence)
	print("Fade Config: IN =", DEFAULT_FADE_IN, "OUT =", DEFAULT_FADE_OUT, "SEQ =", SEQUENCE_CROSSFADE)
	print("")
	print("Loaded Animations:")
	for name, anim in pairs(loadedAnimations) do
		local status = anim.IsPlaying and "PLAYING" or "Stopped"
		local looped = anim.Looped and "LOOP" or "ONE-SHOT"
		local length = anim.Length and string.format("%.2fs", anim.Length) or "N/A"
		print(string.format("  %s: %s %s (%s)", name, status, looped, length))
	end
	print("")
	print("Current Animation:", currentAnimationName or "None")
	print("═══════════════════════════════════════")
end

function AnimationController:SetDebug(enabled)
	DEBUG_ENABLED = enabled
end

return AnimationController