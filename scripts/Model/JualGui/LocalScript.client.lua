-- sellfish (LocalScript)

local player = game.Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remote = ReplicatedStorage:WaitForChild("JualIkanRemote")

local gui = script.Parent
local frame = gui.Frame
local npcText = frame.NpcText

local typing = false

local function typeText(text)
	typing = true
	npcText.Text = ""
	for i = 1, #text do
		npcText.Text = string.sub(text, 1, i)
		task.wait(0.03)
	end
	typing = false
end

Remote.OnClientEvent:Connect(function(mode, value)
	if mode == "Jualan" then
		gui.Enabled = true
		typeText("Halo, bisa saya bantu? Apa kamu ingin menjual Ikan?")
	elseif mode == "TerimaKasih" then
		gui.Enabled = true
		typeText("Terima kasih! Saya membeli Ikan seharga Rp." .. tostring(value))
		task.delay(2.5, function()
			gui.Enabled = false
		end)
	elseif mode == "Info" then
		gui.Enabled = true
		typeText(tostring(value))
	end
end)

frame.All.MouseButton1Click:Connect(function()
	Remote:FireServer("All") -- sekarang artinya: jual semua NON-FAVORIT
end)

frame.Hand.MouseButton1Click:Connect(function()
	Remote:FireServer("Hand")
end)

frame.Cancel.MouseButton1Click:Connect(function()
	if not typing then
		gui.Enabled = false
	end
end)
