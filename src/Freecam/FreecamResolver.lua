--!nonstrict
local Players = game:GetService("Players")

local Resolver = {}

local function find(parent, name, timeout)
	if not parent then
		return nil
	end

	local ok, obj = pcall(function()
		return parent:WaitForChild(name, timeout or 60)
	end)

	return ok and obj or nil
end

local function findButton(frame)
	if not frame then
		return nil
	end

	return frame:FindFirstChild("TextButton") or frame:FindFirstChildWhichIsA("GuiButton")
end

function Resolver.resolve()
	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return false, "PlayerGui tidak ada"
	end

	local gameUI = find(playerGui, "GameUI", 60)
	local component = gameUI and find(gameUI, "Component", 60)
	if not component then
		return false, "GameUI.Component tidak ditemukan"
	end

	local buttons = component:FindFirstChild("Buttons")
	local leftHolder = buttons and buttons:FindFirstChild("LeftHolder")
	local toggleBtn = leftHolder and leftHolder:FindFirstChild("Freecam")
	local hotkeyFrame = toggleBtn and (toggleBtn:FindFirstChild("Hotkeys") or toggleBtn:FindFirstChild("Hotkey"))

	local root = component:FindFirstChild("Freecam")
	local movement = root and root:FindFirstChild("Movement")
	local hideFrame = root and root:FindFirstChild("hide")
	local closeFrame = root and root:FindFirstChild("close")

	return true, {
		GameUI = gameUI,
		Component = component,
		ToggleBtn = toggleBtn,
		ToggleHotkey = hotkeyFrame,
		Root = root,
		MovementRoot = movement,
		ForwardBtn = findButton(movement and movement:FindFirstChild("forward")),
		BackBtn = findButton(movement and movement:FindFirstChild("back")),
		LeftBtn = findButton(movement and movement:FindFirstChild("left")),
		RightBtn = findButton(movement and movement:FindFirstChild("right")),
		ZoomInBtn = findButton(root and root:FindFirstChild("zoomIn")),
		ZoomOutBtn = findButton(root and root:FindFirstChild("zoomOut")),
		HideFrame = hideFrame,
		HideBtn = findButton(hideFrame),
		CloseFrame = closeFrame,
		CloseBtn = findButton(closeFrame),
	}
end

return Resolver
