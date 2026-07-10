-- || Shift To Run - Clean Version (No Animation) || --
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local camera = workspace.CurrentCamera
local RunConfig = require(game.ReplicatedStorage:WaitForChild("RunConfig"))

local character, humanoid
local mobileGui
local mobileConns = {}
local t

-- ================= RUN =================
local function Run()
	if RunConfig.Walking and RunConfig.CanRun then
		RunConfig.Running = true
		TweenService:Create(humanoid, TweenInfo.new(RunConfig.TransitionSpeed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {WalkSpeed = RunConfig.RunSpeed}):Play()
		TweenService:Create(camera, TweenInfo.new(RunConfig.TransitionSpeed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {FieldOfView = RunConfig.RunFov}):Play()
	end
end

-- ================= WALK =================
local function Walk()
	RunConfig.Running = false
	RunConfig.Sprinting = false
	TweenService:Create(humanoid, TweenInfo.new(RunConfig.TransitionSpeed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {WalkSpeed = RunConfig.WalkSpeed}):Play()
	TweenService:Create(camera, TweenInfo.new(RunConfig.TransitionSpeed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {FieldOfView = RunConfig.WalkFov}):Play()
	if t then task.cancel(t); t = nil end
end

-- ================= SPRINT =================
local function Sprint()
	if RunConfig.Walking and RunConfig.Running and RunConfig.CanSprint then
		RunConfig.Sprinting = true
		TweenService:Create(humanoid, TweenInfo.new(RunConfig.TransitionSpeed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {WalkSpeed = RunConfig.SprintSpeed}):Play()
		TweenService:Create(camera, TweenInfo.new(RunConfig.TransitionSpeed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {FieldOfView = RunConfig.SprintFov}):Play()
	end
end

-- ================= MOBILE SETUP =================
local function setupMobileButton()
	-- Disconnect old
	for _, c in ipairs(mobileConns) do if c.Connected then c:Disconnect() end end
	table.clear(mobileConns)

	-- Ambil ulang MobileGui (bisa baru setelah respawn)
	mobileGui = playerGui:WaitForChild("MobileGui", 5)
	if not mobileGui then return end

	local runBtn = mobileGui:FindFirstChild("RunButton")
	if not runBtn then return end

	table.insert(mobileConns, runBtn.MouseButton1Down:Connect(function()
		Run()
	end))
	table.insert(mobileConns, runBtn.MouseButton1Up:Connect(function()
		Walk()
	end))

	-- Show di mobile
	if UIS.TouchEnabled and not UIS.KeyboardEnabled then
		mobileGui.Enabled = true
	end
end

-- ================= CHARACTER SETUP =================
local function onCharacterAdded(newChar)
	character = newChar
	humanoid = character:WaitForChild("Humanoid")
	RunConfig.Running = false
	RunConfig.Sprinting = false
	RunConfig.Walking = false

	-- Re-setup mobile button (GUI baru setelah respawn)
	task.defer(setupMobileButton)
end

-- ================= INPUT =================
UIS.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == RunConfig.RunKey then
		Run()
		t = task.spawn(function()
			task.wait(RunConfig.SprintTransitionSpeed)
			if RunConfig.Running then Sprint() end
		end)
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.KeyCode == RunConfig.RunKey then Walk() end
end)

-- ================= MOVEMENT CHECK =================
RunService.RenderStepped:Connect(function()
	if not humanoid or humanoid.Health <= 0 then return end
	if humanoid.MoveDirection.Magnitude > 0 then
		RunConfig.Walking = true
	else
		RunConfig.Walking = false
		if RunConfig.Running then Walk() end
	end
end)

-- ================= INIT =================
if player.Character then onCharacterAdded(player.Character) end
player.CharacterAdded:Connect(onCharacterAdded)