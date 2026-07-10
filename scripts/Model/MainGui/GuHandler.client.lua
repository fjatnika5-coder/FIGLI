local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ShopOpen = false
local SettingsOpen = false

local screenGui   = script.Parent  -- FastBar / Main UI
local Sidebar     = screenGui:WaitForChild("Sidebar")
local OpenBtn     = screenGui:WaitForChild("OpenBtn")
local ClickSFX    = screenGui:FindFirstChild("ClickSFX")

local EmoteBtn    = Sidebar:WaitForChild("EmoteBtn")
local SettingBtn  = Sidebar:WaitForChild("SettingBtn")
local MusicBtn    = Sidebar:WaitForChild("MusicBtn")
local ShopBtn     = Sidebar:WaitForChild("ShopBtn")

local AnimUI      = playerGui:WaitForChild("AnimationsUI_Final")

local ShopUI      = playerGui:WaitForChild("ShopUI")
local ShopMain    = ShopUI:WaitForChild("MainFrame")

local SettingsUI   = playerGui:WaitForChild("SettingsUI")
local SettingsMain = SettingsUI:WaitForChild("MainFrame")
local Skyback      = SettingsUI:FindFirstChild("Skyback")

local MusicUI      = playerGui:WaitForChild("MusicUI")

--------------------------------------------------------------------
-- POPUP SIZE CONFIG
--------------------------------------------------------------------
local POP_OPEN_TIME   = 0.25
local POP_CLOSE_TIME  = 0.20
local EASE_STYLE      = Enum.EasingStyle.Quad
local EASE_DIR        = Enum.EasingDirection.Out

local ZERO_SIZE = UDim2.new(0,0,0,0)

local OPEN_SIZES = {
	EmoteFrame = UDim2.new(0.244, 0, 0.638, 0),
	Settings   = UDim2.new(0.55, 0, 0.480, 0),
	Skyback    = UDim2.new(0.239, 0, 0.369, 0),
	Shop       = UDim2.new(0.793, 0, 0.813, 0),
}

--------------------------------------------------------------------
-- CLICK COOLDOWN + SFX
--------------------------------------------------------------------
local BUTTON_COOLDOWN = 0.25
local lastClickAt = {}

local function canClick(key)
	local now = os.clock()
	if (lastClickAt[key] or 0) + BUTTON_COOLDOWN > now then return false end
	lastClickAt[key] = now
	return true
end

local function playClick()
	if ClickSFX then
		if ClickSFX.IsPlaying then ClickSFX:Stop() end
		ClickSFX:Play()
	end
end

local function ensureAnchor(gui)
	if gui and gui:IsA("GuiObject") then
		gui.AnchorPoint = Vector2.new(0.5, 0.5)
	end
end

local function prep(frame)
	if frame then
		frame.Visible = false
		frame.Size = ZERO_SIZE
		ensureAnchor(frame)
	end
end

-- siapkan semua popup
prep(EmoteFrame)
prep(SettingsMain)
if Skyback then prep(Skyback) end
prep(ShopMain)

SettingsUI.Enabled = false
MusicUI.Enabled = false
ShopUI.Enabled   = false

--------------------------------------------------------------------
-- TWEEN HELPERS
--------------------------------------------------------------------
local function tweenOpen(frame, size)
	frame.Visible = true
	frame.Size = ZERO_SIZE
	TweenService:Create(
		frame,
		TweenInfo.new(POP_OPEN_TIME, EASE_STYLE, EASE_DIR),
		{ Size = size }
	):Play()
end

local function tweenClose(frame)
	local tw = TweenService:Create(
		frame,
		TweenInfo.new(POP_CLOSE_TIME, EASE_STYLE, EASE_DIR),
		{ Size = ZERO_SIZE }
	)
	tw:Play()
	tw.Completed:Connect(function()
		frame.Visible = false
	end)
end

local function isOpen(frame)
	return frame.Visible and frame.Size ~= ZERO_SIZE
end

local panels = {EmoteFrame, SettingsMain, Skyback, ShopMain}

local function closeAll()
	for _, f in ipairs(panels) do
		if f and isOpen(f) then
			tweenClose(f)
		end
	end
	SettingsUI.Enabled = false
	ShopUI.Enabled     = false
	MusicUI.Enabled    = false
end

local function openExclusive(frame, size, mode)
	closeAll()
	if mode == "Settings" then
		SettingsUI.Enabled = true
	elseif mode == "Shop" then
		ShopUI.Enabled = true
	end
	if frame then
		tweenOpen(frame, size)
	end
end

--------------------------------------------------------------------
-- 📱 DEVICE DETECT + AUTO UISCALE
--------------------------------------------------------------------
local isMobile = UIS.TouchEnabled

-- cari / buat UIScale di Sidebar
local uiScale = Sidebar:FindFirstChildOfClass("UIScale")
if not uiScale then
	uiScale = Instance.new("UIScale")
	uiScale.Name = "AutoScale"
	uiScale.Parent = Sidebar
end

Sidebar.AnchorPoint = Vector2.new(0, 0.5)

-- ukuran base (PC)
local BASE_SIDEBAR_SIZE = UDim2.new(0, 55, 0, 220)
local BASE_BUTTON_SIZE  = UDim2.new(0, 40, 0, 40)

Sidebar.Size = BASE_SIDEBAR_SIZE

-- hapus AspectRatio kalau ada
local aspect = Sidebar:FindFirstChildOfClass("UIAspectRatioConstraint")
if aspect then
	aspect:Destroy()
end

local camera = Workspace.CurrentCamera

local function updateUIScale()
	if not camera then
		camera = Workspace.CurrentCamera
		if not camera then return end
	end

	local vps = camera.ViewportSize
	local minSide = math.min(vps.X, vps.Y)

	-- 1080 = referensi monitor PC
	local scale = minSide / 1080

	if isMobile then
		scale = scale * 0.9
	end

	scale = math.clamp(scale, 0.7, 1.1)
	uiScale.Scale = scale
end

updateUIScale()

if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateUIScale)
end

player.CharacterAdded:Connect(function()
	task.wait(0.5)
	updateUIScale()
end)

-- set tombol (di-scale sama UIScale di atas)
local buttons = {"ShopBtn","SettingBtn","EmoteBtn","MusicBtn"}
for order, name in ipairs(buttons) do
	local btn = Sidebar:FindFirstChild(name)
	if btn then
		btn.AnchorPoint = Vector2.new(0.5, 0)
		btn.BackgroundTransparency = 1
		btn.LayoutOrder = order
		btn.Size = BASE_BUTTON_SIZE
	end
end

--------------------------------------------------------------------
-- 🔽 SIDEBAR + OPEN BUTTON POS
--------------------------------------------------------------------
OpenBtn.AnchorPoint = Vector2.new(0.5, 0.5)

local SIDEBAR_OPEN_POS
local SIDEBAR_CLOSE_POS
local OPENBTN_OPEN_POS
local OPENBTN_CLOSE_POS

local OPENBTN_SIZE_PC     = UDim2.new(0, 40, 0, 40)
local OPENBTN_SIZE_MOBILE = UDim2.new(0, 26, 0, 26)

if isMobile then
	-- mobile: sedikit di atas tengah + openBtn agak menjauh
	SIDEBAR_OPEN_POS  = UDim2.new(0, 8, 0.42, 0)
	SIDEBAR_CLOSE_POS = UDim2.new(-0.08, 8, 0.42, 0)

	OPENBTN_OPEN_POS  = UDim2.new(0.09, 0, 0.42, 0)
	OPENBTN_CLOSE_POS = UDim2.new(0.035, 0, 0.42, 0)

	OpenBtn.Size = OPENBTN_SIZE_MOBILE
else
	SIDEBAR_OPEN_POS  = UDim2.new(0, 5, 0.5, 0)
	SIDEBAR_CLOSE_POS = UDim2.new(-0.10, 5, 0.5, 0)

	OPENBTN_OPEN_POS  = UDim2.new(0.06, 0, 0.5, 0)
	OPENBTN_CLOSE_POS = UDim2.new(0.015, 0, 0.5, 0)

	OpenBtn.Size = OPENBTN_SIZE_PC
end

local sidebarVisible = true
local animating = false

Sidebar.Position = SIDEBAR_OPEN_POS
Sidebar.Visible  = true
OpenBtn.Position = OPENBTN_OPEN_POS

local function toggleSidebar()
	if animating then return end
	animating = true

	if sidebarVisible then
		local tw1 = TweenService:Create(Sidebar, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
			Position = SIDEBAR_CLOSE_POS
		})
		local tw2 = TweenService:Create(OpenBtn, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
			Position = OPENBTN_CLOSE_POS
		})
		tw1:Play()
		tw2:Play()
		tw1.Completed:Wait()
		Sidebar.Visible = false
		sidebarVisible = false
	else
		Sidebar.Visible = true
		local tw1 = TweenService:Create(Sidebar, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
			Position = SIDEBAR_OPEN_POS
		})
		local tw2 = TweenService:Create(OpenBtn, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
			Position = OPENBTN_OPEN_POS
		})
		tw1:Play()
		tw2:Play()
		tw1.Completed:Wait()
		sidebarVisible = true
	end

	animating = false
end

OpenBtn.Activated:Connect(function()
	if not canClick("OpenBtn") then return end
	playClick()
	toggleSidebar()
end)

--------------------------------------------------------------------
-- 🔘 BUTTON LOGIC
--------------------------------------------------------------------
EmoteBtn.Activated:Connect(function()
	if not canClick("EmoteBtn") then return end
	playClick()

	-- tutup panel fastbar lain
	closeAll()

	-- toggle Animations UI
	if _G.AnimationsUI then
		if _G.AnimationsUI_IsOpen then
			_G.AnimationsUI.Close()
			_G.AnimationsUI_IsOpen = false
		else
			_G.AnimationsUI.Open()
			_G.AnimationsUI_IsOpen = true
		end
	end
end)


ShopBtn.Activated:Connect(function()
	if not canClick("ShopBtn") then return end
	playClick()

	if ShopOpen then
		-- TUTUP
		closeAll()
		ShopOpen = false
	else
		-- BUKA
		closeAll()
		openExclusive(ShopMain, OPEN_SIZES.Shop, "Shop")
		ShopOpen = true
		SettingsOpen = false
	end
end)


SettingBtn.Activated:Connect(function()
	if not canClick("SettingBtn") then return end
	playClick()

	if SettingsOpen then
		-- TUTUP
		closeAll()
		SettingsOpen = false
	else
		-- BUKA
		closeAll()
		openExclusive(SettingsMain, OPEN_SIZES.Settings, "Settings")
		if Skyback then
			tweenOpen(Skyback, OPEN_SIZES.Skyback)
		end
		SettingsOpen = true
		ShopOpen = false
	end
end)

MusicBtn.Activated:Connect(function()
	if not canClick("MusicBtn") then return end
	playClick()
	if MusicUI.Enabled then
		MusicUI.Enabled = false
	else
		closeAll()
		MusicUI.Enabled = true
	end
end)

local function closeAll()
	for _, f in ipairs(panels) do
		if f and isOpen(f) then
			tweenClose(f)
		end
	end

	SettingsUI.Enabled = false
	ShopUI.Enabled     = false
	MusicUI.Enabled    = false

	-- RESET STATE
	ShopOpen = false
	SettingsOpen = false
end
