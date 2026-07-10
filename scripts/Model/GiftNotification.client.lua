--!strict
-- Taruh di: StarterPlayer > StarterPlayerScripts

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")

-- Ambil Remote yang sama dengan di Server
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ChatMessageRemote = Remotes:WaitForChild("ChatMessage")

-- Konfigurasi Warna (Format Hex)
local COLORS = {
	TAG     = "#FFA500", -- Oranye (Untuk Tag [DONATION])
	NAME    = "#FFFFFF", -- Putih (Nama Player)
	MONEY   = "#88FF88", -- Hijau Terang (Jumlah Uang)
	TEXT    = "#DDDDDD"  -- Abu-abu terang (Kata sambung)
}

ChatMessageRemote.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end


	local donorName = data.Donor or "Unknown"
	local recipientName = data.Recipient or "Unknown"
	local amount = data.Amount or 0
	local robuxIcon = utf8.char(0xE002)

	local msg = string.format(
		'<font color="%s"><b>[DONATION]</b></font> ' ..
			'<font color="%s">%s</font> ' ..
			'<font color="%s">gifted</font> ' ..
			'<font color="%s">%s</font> ' ..
			'<font color="%s"><b>%s %s</b></font>',
		COLORS.TAG,       -- Warna Tag
		COLORS.NAME,      -- Warna Donor
		donorName,        -- Nama Donor
		COLORS.TEXT,      -- Warna teks "gifted"
		COLORS.NAME,      -- Warna Recipient
		recipientName,    -- Nama Recipient
		COLORS.MONEY,     -- Warna Uang
		robuxIcon,        -- Icon Robux
		amount            -- Jumlah
	)

	local isTextChatService = false
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		local channels = TextChatService:FindFirstChild("TextChannels")
		if channels then
			local rbxGeneral = channels:FindFirstChild("RBXGeneral")
			if rbxGeneral then
				isTextChatService = true
				rbxGeneral:DisplaySystemMessage(msg)
			end
		end
	end

	-- Jika pakai Chat Lama (LegacyChatService)
	if not isTextChatService then
		pcall(function()
			StarterGui:SetCore("ChatMakeSystemMessage", {
				Text = string.gsub(msg, "<[^>]+>", ""), 
				Color = Color3.fromHex(COLORS.MONEY),
				Font = Enum.Font.GothamBold,
				FontSize = Enum.FontSize.Size24
			})
		end)
	end
end)