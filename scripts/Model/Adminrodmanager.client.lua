-- StarterPlayerScripts.AdminRodManager_Client (Optimized)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FishingSystem = ReplicatedStorage:WaitForChild("FishingSystem")
local AdminRemotes = FishingSystem:WaitForChild("AdminRemotes", 10)
if not AdminRemotes then return end

local ToggleUI      = AdminRemotes:WaitForChild("ToggleAdminRodUI")
local GetPlayerList = AdminRemotes:WaitForChild("GetPlayerList")
local GetPlayerRods = AdminRemotes:WaitForChild("GetPlayerRods")
local AddRod        = AdminRemotes:WaitForChild("AddRod")
local RemoveRod     = AdminRemotes:WaitForChild("RemoveRod")
local GetAllRods    = AdminRemotes:WaitForChild("GetAllRods")

-- ═════════════════════════════════════
-- WARNA
-- ═════════════════════════════════════

local C = {
	bg        = Color3.fromRGB(18, 18, 18),
	card      = Color3.fromRGB(28, 28, 28),
	card2     = Color3.fromRGB(38, 38, 38),
	border    = Color3.fromRGB(55, 55, 55),
	text      = Color3.fromRGB(240, 240, 240),
	textDim   = Color3.fromRGB(150, 150, 150),
	green     = Color3.fromRGB(40, 200, 80),
	red       = Color3.fromRGB(220, 50, 50),
	white     = Color3.fromRGB(255, 255, 255),
}

-- ═════════════════════════════════════
-- STATE
-- ═════════════════════════════════════

local selectedPlayer = nil
local allRodNames = {}
local isOpen = false
local isMobile = UserInputService.TouchEnabled

-- Cache supaya tidak invoke server tiap ketikan
local cachedPlayerList = nil  -- di-fetch sekali saat panel buka
local cachedOwnedRods = nil   -- di-fetch sekali saat player dipilih, refresh saat add/remove

-- ═════════════════════════════════════
-- DEBOUNCE HELPER
-- ═════════════════════════════════════

local DEBOUNCE_TIME = 0.25 -- detik

local function createDebounce(callback)
	local lastId = 0
	return function(...)
		lastId += 1
		local myId = lastId
		local args = table.pack(...)
		task.delay(DEBOUNCE_TIME, function()
			if myId == lastId then
				callback(table.unpack(args, 1, args.n))
			end
		end)
	end
end

-- ═════════════════════════════════════
-- UI HELPERS
-- ═════════════════════════════════════

local function create(className, props)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		if k ~= "Children" and k ~= "Parent" then
			inst[k] = v
		end
	end
	if props.Children then
		for _, child in ipairs(props.Children) do
			child.Parent = inst
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function addCorner(parent, radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 6), Parent = parent })
end

local function addStroke(parent, color, thickness)
	return create("UIStroke", {
		Color = color or C.border,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function addPadding(parent, t, b, l, r)
	return create("UIPadding", {
		PaddingTop = UDim.new(0, t or 8),
		PaddingBottom = UDim.new(0, b or 8),
		PaddingLeft = UDim.new(0, l or 8),
		PaddingRight = UDim.new(0, r or 8),
		Parent = parent,
	})
end

-- ═════════════════════════════════════
-- BUILD GUI
-- ═════════════════════════════════════

local screenGui = create("ScreenGui", {
	Name = "AdminRodManagerUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 100,
	Parent = playerGui,
})

local panelSize = isMobile and UDim2.new(0.95, 0, 0.85, 0) or UDim2.new(0, 520, 0, 600)

local mainFrame = create("Frame", {
	Name = "Main",
	Size = panelSize,
	Position = UDim2.new(0.5, 0, 0.5, 0),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = C.bg,
	Visible = false,
	Parent = screenGui,
})
addCorner(mainFrame, 10)
addStroke(mainFrame, C.border, 2)

-- Header
local header = create("Frame", {
	Size = UDim2.new(1, 0, 0, 44),
	BackgroundColor3 = C.card,
	BorderSizePixel = 0,
	Parent = mainFrame,
})
addCorner(header, 10)

create("Frame", {
	Size = UDim2.new(1, 0, 0, 12),
	Position = UDim2.new(0, 0, 1, -12),
	BackgroundColor3 = C.card,
	BorderSizePixel = 0,
	Parent = header,
})

create("TextLabel", {
	Size = UDim2.new(1, -50, 1, 0),
	Position = UDim2.new(0, 14, 0, 0),
	BackgroundTransparency = 1,
	Text = "ROD MANAGER",
	TextColor3 = C.white,
	TextSize = 16,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = header,
})

local closeBtn = create("TextButton", {
	Size = UDim2.new(0, 36, 0, 36),
	Position = UDim2.new(1, -40, 0, 4),
	BackgroundColor3 = C.red,
	Text = "X",
	TextColor3 = C.white,
	TextSize = 16,
	Font = Enum.Font.GothamBold,
	Parent = header,
})
addCorner(closeBtn, 6)

local content = create("Frame", {
	Size = UDim2.new(1, -16, 1, -52),
	Position = UDim2.new(0, 8, 0, 48),
	BackgroundTransparency = 1,
	Parent = mainFrame,
})

-- ═══════════════════════════════════
-- PLAYER PANEL
-- ═══════════════════════════════════

local playerPanel = create("Frame", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	Visible = true,
	Parent = content,
})

create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 30),
	BackgroundTransparency = 1,
	Text = "SELECT PLAYER",
	TextColor3 = C.textDim,
	TextSize = 13,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = playerPanel,
})

local playerSearch = create("TextBox", {
	Size = UDim2.new(1, 0, 0, 36),
	Position = UDim2.new(0, 0, 0, 30),
	BackgroundColor3 = C.card,
	Text = "",
	PlaceholderText = "Search player...",
	PlaceholderColor3 = C.textDim,
	TextColor3 = C.white,
	TextSize = 14,
	Font = Enum.Font.Gotham,
	ClearTextOnFocus = false,
	Parent = playerPanel,
})
addCorner(playerSearch, 6)
addStroke(playerSearch, C.border)
addPadding(playerSearch, 0, 0, 10, 10)

local playerScroll = create("ScrollingFrame", {
	Size = UDim2.new(1, 0, 1, -76),
	Position = UDim2.new(0, 0, 0, 72),
	BackgroundTransparency = 1,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = C.border,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Parent = playerPanel,
})

create("UIListLayout", {
	SortOrder = Enum.SortOrder.Name,
	Padding = UDim.new(0, 4),
	Parent = playerScroll,
})

-- ═══════════════════════════════════
-- ROD PANEL
-- ═══════════════════════════════════

local rodPanel = create("Frame", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = content,
})

local rodHeader = create("Frame", {
	Size = UDim2.new(1, 0, 0, 36),
	BackgroundTransparency = 1,
	Parent = rodPanel,
})

local backBtn = create("TextButton", {
	Size = UDim2.new(0, 70, 0, 32),
	BackgroundColor3 = C.card2,
	Text = "< BACK",
	TextColor3 = C.white,
	TextSize = 12,
	Font = Enum.Font.GothamBold,
	Parent = rodHeader,
})
addCorner(backBtn, 6)
addStroke(backBtn, C.border)

local rodPlayerLabel = create("TextLabel", {
	Size = UDim2.new(1, -80, 0, 32),
	Position = UDim2.new(0, 78, 0, 0),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = C.green,
	TextSize = 14,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	Parent = rodHeader,
})

local tabFrame = create("Frame", {
	Size = UDim2.new(1, 0, 0, 32),
	Position = UDim2.new(0, 0, 0, 40),
	BackgroundTransparency = 1,
	Parent = rodPanel,
})

local tabOwned = create("TextButton", {
	Size = UDim2.new(0.5, -2, 1, 0),
	BackgroundColor3 = C.green,
	Text = "OWNED",
	TextColor3 = C.white,
	TextSize = 12,
	Font = Enum.Font.GothamBold,
	Parent = tabFrame,
})
addCorner(tabOwned, 6)

local tabAdd = create("TextButton", {
	Size = UDim2.new(0.5, -2, 1, 0),
	Position = UDim2.new(0.5, 2, 0, 0),
	BackgroundColor3 = C.card2,
	Text = "ADD ROD",
	TextColor3 = C.textDim,
	TextSize = 12,
	Font = Enum.Font.GothamBold,
	Parent = tabFrame,
})
addCorner(tabAdd, 6)
addStroke(tabAdd, C.border)

local rodSearch = create("TextBox", {
	Size = UDim2.new(1, 0, 0, 32),
	Position = UDim2.new(0, 0, 0, 78),
	BackgroundColor3 = C.card,
	Text = "",
	PlaceholderText = "Search rod...",
	PlaceholderColor3 = C.textDim,
	TextColor3 = C.white,
	TextSize = 13,
	Font = Enum.Font.Gotham,
	ClearTextOnFocus = false,
	Parent = rodPanel,
})
addCorner(rodSearch, 6)
addStroke(rodSearch, C.border)
addPadding(rodSearch, 0, 0, 10, 10)

local statusLabel = create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 20),
	Position = UDim2.new(0, 0, 0, 114),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = C.textDim,
	TextSize = 11,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = rodPanel,
})

local rodScroll = create("ScrollingFrame", {
	Size = UDim2.new(1, 0, 1, -140),
	Position = UDim2.new(0, 0, 0, 138),
	BackgroundTransparency = 1,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = C.border,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Parent = rodPanel,
})

create("UIListLayout", {
	SortOrder = Enum.SortOrder.Name,
	Padding = UDim.new(0, 3),
	Parent = rodScroll,
})

-- ═══════════════════════════════════
-- LOGIC
-- ═══════════════════════════════════

local currentTab = "owned"

local function showStatus(text, color)
	statusLabel.Text = text
	statusLabel.TextColor3 = color or C.textDim
	task.delay(3, function()
		if statusLabel.Text == text then
			statusLabel.Text = ""
		end
	end)
end

local function clearList(scrollFrame)
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

-- ═══════════════════════════════════
-- FETCH DATA (server calls terpusat)
-- ═══════════════════════════════════

local function fetchPlayerList()
	local ok, list = pcall(function()
		return GetPlayerList:InvokeServer()
	end)
	if ok and list then
		cachedPlayerList = list
	end
	return cachedPlayerList or {}
end

local function fetchOwnedRods(force)
	if not selectedPlayer then return {} end
	if cachedOwnedRods and not force then return cachedOwnedRods end

	local ok, rods = pcall(function()
		return GetPlayerRods:InvokeServer(selectedPlayer)
	end)
	if ok and rods then
		cachedOwnedRods = rods
	end
	return cachedOwnedRods or {}
end

local function fetchAllRods()
	if #allRodNames > 0 then return allRodNames end

	local ok, rods = pcall(function()
		return GetAllRods:InvokeServer()
	end)
	if ok and rods then
		allRodNames = rods
	end
	return allRodNames
end

-- ═══════════════════════════════════
-- PLAYER LIST (render dari cache, filter lokal)
-- ═══════════════════════════════════

local function createPlayerButton(info)
	local btn = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = C.card,
		Text = "",
		AutoButtonColor = false,
		Parent = playerScroll,
	})
	addCorner(btn, 6)
	addStroke(btn, C.border)

	create("TextLabel", {
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.new(0, 12, 0, 0),
		BackgroundTransparency = 1,
		Text = info.displayName .. " (@" .. info.name .. ")",
		TextColor3 = C.white,
		TextSize = 13,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = btn,
	})

	btn.MouseEnter:Connect(function() btn.BackgroundColor3 = C.card2 end)
	btn.MouseLeave:Connect(function() btn.BackgroundColor3 = C.card end)

	btn.MouseButton1Click:Connect(function()
		selectedPlayer = info.name
		cachedOwnedRods = nil -- Reset cache saat ganti player
		rodPlayerLabel.Text = info.displayName .. " (@" .. info.name .. ")"
		playerPanel.Visible = false
		rodPanel.Visible = true
		currentTab = "owned"
		rodSearch.Text = ""
		refreshRodList()
	end)
end

-- renderPlayerList: filter lokal dari cache, TIDAK invoke server
local function renderPlayerList(filter)
	clearList(playerScroll)
	local list = cachedPlayerList or {}
	filter = filter and filter:lower() or ""

	for _, info in ipairs(list) do
		local match = filter == ""
			or info.name:lower():find(filter, 1, true)
			or info.displayName:lower():find(filter, 1, true)
		if match then
			createPlayerButton(info)
		end
	end
end

-- fetchAndRenderPlayerList: invoke server sekali, lalu render
local function fetchAndRenderPlayerList()
	fetchPlayerList()
	renderPlayerList(playerSearch.Text)
end

-- ═══════════════════════════════════
-- ROD LIST
-- ═══════════════════════════════════

local function createRodRow(rodName, isOwned)
	local row = create("Frame", {
		Name = rodName,
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = C.card,
		Parent = rodScroll,
	})
	addCorner(row, 6)

	create("TextLabel", {
		Size = UDim2.new(1, -90, 1, 0),
		Position = UDim2.new(0, 12, 0, 0),
		BackgroundTransparency = 1,
		Text = rodName,
		TextColor3 = C.white,
		TextSize = 13,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})

	if isOwned then
		local removeBtn = create("TextButton", {
			Size = UDim2.new(0, 68, 0, 26),
			Position = UDim2.new(1, -76, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = C.red,
			Text = "REMOVE",
			TextColor3 = C.white,
			TextSize = 11,
			Font = Enum.Font.GothamBold,
			Parent = row,
		})
		addCorner(removeBtn, 4)

		removeBtn.MouseButton1Click:Connect(function()
			removeBtn.Text = "..."
			local ok, result = pcall(function()
				return RemoveRod:InvokeServer(selectedPlayer, rodName)
			end)
			if ok and result then
				showStatus("Removed: " .. rodName, C.red)
				cachedOwnedRods = nil -- Invalidate cache
				refreshRodList()
			else
				showStatus("Failed to remove", C.red)
				task.wait(1)
				removeBtn.Text = "REMOVE"
			end
		end)
	else
		local addBtn = create("TextButton", {
			Size = UDim2.new(0, 54, 0, 26),
			Position = UDim2.new(1, -62, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = C.green,
			Text = "ADD",
			TextColor3 = C.white,
			TextSize = 11,
			Font = Enum.Font.GothamBold,
			Parent = row,
		})
		addCorner(addBtn, 4)

		addBtn.MouseButton1Click:Connect(function()
			addBtn.Text = "..."
			local ok, result = pcall(function()
				return AddRod:InvokeServer(selectedPlayer, rodName)
			end)
			if ok and result then
				showStatus("Added: " .. rodName, C.green)
				cachedOwnedRods = nil -- Invalidate cache
				refreshRodList()
			else
				showStatus("Failed to add", C.red)
				task.wait(1)
				addBtn.Text = "ADD"
			end
		end)
	end
end

function refreshRodList()
	clearList(rodScroll)
	local filter = rodSearch.Text:lower()

	if currentTab == "owned" then
		tabOwned.BackgroundColor3 = C.green
		tabOwned.TextColor3 = C.white
		tabAdd.BackgroundColor3 = C.card2
		tabAdd.TextColor3 = C.textDim

		local rods = fetchOwnedRods(cachedOwnedRods == nil) -- Fetch hanya kalau cache kosong
		local count = 0
		for _, rodName in ipairs(rods) do
			if filter == "" or rodName:lower():find(filter, 1, true) then
				createRodRow(rodName, true)
				count += 1
			end
		end
		showStatus(count .. " rod(s) owned", C.textDim)
	else
		tabOwned.BackgroundColor3 = C.card2
		tabOwned.TextColor3 = C.textDim
		tabAdd.BackgroundColor3 = C.green
		tabAdd.TextColor3 = C.white

		local owned = fetchOwnedRods(cachedOwnedRods == nil)
		local ownedSet = {}
		for _, r in ipairs(owned) do
			ownedSet[r] = true
		end

		fetchAllRods()

		local count = 0
		for _, rodName in ipairs(allRodNames) do
			if not ownedSet[rodName] then
				if filter == "" or rodName:lower():find(filter, 1, true) then
					createRodRow(rodName, false)
					count += 1
				end
			end
		end
		showStatus(count .. " rod(s) available", C.textDim)
	end
end

-- ═══════════════════════════════════
-- EVENTS
-- ═══════════════════════════════════

closeBtn.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
	isOpen = false
end)

backBtn.MouseButton1Click:Connect(function()
	rodPanel.Visible = false
	playerPanel.Visible = true
	selectedPlayer = nil
	cachedOwnedRods = nil
	playerSearch.Text = ""
	fetchAndRenderPlayerList()
end)

tabOwned.MouseButton1Click:Connect(function()
	currentTab = "owned"
	rodSearch.Text = ""
	refreshRodList()
end)

tabAdd.MouseButton1Click:Connect(function()
	currentTab = "add"
	rodSearch.Text = ""
	refreshRodList()
end)

-- Debounced search: filter lokal dari cache, BUKAN invoke server tiap huruf
local debouncedPlayerFilter = createDebounce(function(text)
	renderPlayerList(text)
end)

local debouncedRodFilter = createDebounce(function()
	refreshRodList()
end)

playerSearch:GetPropertyChangedSignal("Text"):Connect(function()
	debouncedPlayerFilter(playerSearch.Text)
end)

rodSearch:GetPropertyChangedSignal("Text"):Connect(function()
	debouncedRodFilter()
end)

ToggleUI.OnClientEvent:Connect(function()
	isOpen = not isOpen
	mainFrame.Visible = isOpen
	if isOpen then
		playerPanel.Visible = true
		rodPanel.Visible = false
		selectedPlayer = nil
		cachedPlayerList = nil
		cachedOwnedRods = nil
		playerSearch.Text = ""
		fetchAndRenderPlayerList()
	end
end)