--!nonstrict
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local FreecamMobileUI = {}

function FreecamMobileUI.setButtonVisual(runtime, active)
	local button = runtime._refs.ToggleBtn
	if not (button and button:IsA("GuiObject")) then
		return
	end

	local state = runtime._buttonVisuals
	if state.ImageColor3 == nil and button:IsA("ImageButton") then
		state.ImageColor3 = button.ImageColor3
	end
	if state.BackgroundColor3 == nil then
		state.BackgroundColor3 = button.BackgroundColor3
	end

	if active then
		if button:IsA("ImageButton") then
			button.ImageColor3 = Color3.fromRGB(170, 255, 200)
		end
		button.BackgroundColor3 = Color3.fromRGB(36, 62, 47)
	else
		if button:IsA("ImageButton") and state.ImageColor3 then
			button.ImageColor3 = state.ImageColor3
		end
		if state.BackgroundColor3 then
			button.BackgroundColor3 = state.BackgroundColor3
		end
	end

	button:SetAttribute("FreecamActive", active == true)
end

-- Paksa sebuah control frame + button-nya selalu kelihatan, termasuk seluruh
-- ancestor chain sampai Root. Ini fix bug close/exit kadang tidak muncul:
-- sebelumnya cuma frame paling luar di-set Visible, kalau ada wrapper/parent
-- invisible atau button di dalam invisible, tombol ke-cull.
function FreecamMobileUI._forceControlVisible(runtime, frame, button)
	local root = runtime._refs.Root
	if frame and frame:IsA("GuiObject") then
		frame.Visible = true
		local node = frame.Parent
		while node and node:IsA("GuiObject") and node ~= root do
			node.Visible = true
			node = node.Parent
		end
	end
	if button and button:IsA("GuiObject") then
		button.Visible = true
		button.Active = true
	end
end

-- Safe-area / notch: pakai mekanisme resmi Roblox (CoreUISafeInsets) supaya UI
-- freecam tidak ketutup notch / rounded corner. Disimpan & di-restore via janitor.
function FreecamMobileUI.applySafeArea(runtime)
	local gameUI = runtime._refs.GameUI
	if not (gameUI and gameUI:IsA("ScreenGui")) then
		return
	end
	if runtime._safeAreaApplied then
		return
	end
	runtime._safeAreaApplied = true
	runtime._origScreenInsets = gameUI.ScreenInsets

	pcall(function()
		gameUI.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	end)

	runtime._janitor:Add(function()
		if gameUI and gameUI.Parent then
			pcall(function()
				gameUI.ScreenInsets = runtime._origScreenInsets or Enum.ScreenInsets.CoreUISafeInsets
			end)
		end
	end, true, "FreecamSafeAreaRestore")
end

function FreecamMobileUI.apply(runtime)
	local root = runtime._refs.Root
	if not (root and root:IsA("GuiObject")) then
		return
	end

	-- Root muncul hanya saat custom freecam aktif (mobile atau console).
	local showRoot = runtime._active and (runtime:_isMobile() or runtime:_isConsole())
	root.Visible = showRoot
	if not showRoot then
		return
	end

	-- Tombol touch movement/zoom hanya untuk mobile dan hanya saat tidak hidden.
	-- Console tidak menampilkan tombol touchscreen (pakai gamepad).
	local touchControlsAllowed = runtime:_isMobile() and not runtime._hidden

	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("GuiObject")
			and child ~= runtime._refs.HideFrame
			and child ~= runtime._refs.CloseFrame
		then
			child.Visible = touchControlsAllowed
		end
	end

	-- Close/exit SELALU visible selama aktif (termasuk saat hidden & di console).
	FreecamMobileUI._forceControlVisible(runtime, runtime._refs.CloseFrame, runtime._refs.CloseBtn)

	if runtime:_isMobile() then
		-- Hide toggle relevan hanya di mobile.
		FreecamMobileUI._forceControlVisible(runtime, runtime._refs.HideFrame, runtime._refs.HideBtn)
	elseif runtime._refs.HideFrame and runtime._refs.HideFrame:IsA("GuiObject") then
		-- Console: hide-toggle tidak ada gunanya, sembunyikan.
		runtime._refs.HideFrame.Visible = false
	end
end

function FreecamMobileUI.setGuiVisible(gui, visible)
	if gui:IsA("ScreenGui") then
		gui.Enabled = visible
	else
		gui.Visible = visible
	end
end

function FreecamMobileUI.saveGuiState(bucket, gui)
	if not gui or bucket[gui] ~= nil then
		return
	end

	if gui:IsA("ScreenGui") then
		bucket[gui] = gui.Enabled
	elseif gui:IsA("GuiObject") then
		bucket[gui] = gui.Visible
	end
end

function FreecamMobileUI.hide(runtime)
	local saved = runtime._savedState
	-- Hanya mobile yang menyembunyikan GUI game lain saat masuk freecam.
	if not (saved and runtime:_isMobile()) then
		return
	end

	local root = runtime._refs.Root
	local component = runtime._refs.Component
	local gameUI = runtime._refs.GameUI
	local guiStates = saved.MobileGuiStates
	local screenGuiStates = saved.MobileScreenGuiStates

	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if playerGui then
		for _, child in ipairs(playerGui:GetChildren()) do
			if child:IsA("ScreenGui") and child ~= gameUI then
				FreecamMobileUI.saveGuiState(screenGuiStates, child)
				child.Enabled = false
			end
		end
	end

	if gameUI and gameUI:IsA("ScreenGui") then
		for _, child in ipairs(gameUI:GetChildren()) do
			if child:IsA("GuiObject") and child ~= component then
				FreecamMobileUI.saveGuiState(guiStates, child)
				child.Visible = false
			end
		end
	end

	if component and component:IsA("GuiObject") then
		for _, child in ipairs(component:GetChildren()) do
			if child:IsA("GuiObject") and child ~= root then
				FreecamMobileUI.saveGuiState(guiStates, child)
				child.Visible = false
			end
		end
	end

	if gameUI and gameUI:IsA("ScreenGui") then
		gameUI.Enabled = true
	end
	if component and component:IsA("GuiObject") then
		component.Visible = true
	end
	if root and root:IsA("GuiObject") then
		root.Visible = true
	end
end

function FreecamMobileUI.restore(runtime, saved)
	if not saved then
		return
	end

	for gui, state in pairs(saved.MobileGuiStates or {}) do
		if gui and gui.Parent then
			FreecamMobileUI.setGuiVisible(gui, state)
		end
	end

	for gui, state in pairs(saved.MobileScreenGuiStates or {}) do
		if gui and gui.Parent then
			gui.Enabled = state
		end
	end
end

return FreecamMobileUI
