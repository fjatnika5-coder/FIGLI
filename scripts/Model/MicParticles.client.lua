local RP = game:GetService("ReplicatedStorage")
local RS = game:GetService("RunService")
local Players = game:GetService("Players")
local LPlr = Players.LocalPlayer

local NoteEffect = script.NoteEffect

local Connecteds = {}

local MicSystem = workspace:WaitForChild("MicSystem", 15)

local Wires = {}

local HearSelf = false
local EmitNotes = true

local function ConnectNew(NewPlr)

	Connecteds[NewPlr] = {}
	local MyTable = Connecteds[NewPlr]

	MyTable.AudioDeviceInput = NewPlr.AudioDeviceInput
	MyTable.Analyzer = Instance.new("AudioAnalyzer", MyTable.AudioDeviceInput)

	MyTable.Wire = Instance.new("Wire", MyTable.AudioDeviceInput)
	MyTable.Wire.SourceInstance = MyTable.AudioDeviceInput
	MyTable.Wire.TargetInstance = MyTable.Analyzer

end
local function DisconnectOld(OldPlr)

	local MyTable = Connecteds[OldPlr]
	if MyTable then
		if MyTable.Wire then MyTable.Wire:Destroy() end
		if MyTable.Analyzer then MyTable.Analyzer:Destroy() end
	end
	Connecteds[OldPlr] = nil

end

-- Jaga-jaga: bersihkan entri kalau player keluar tanpa event dari server
Players.PlayerRemoving:Connect(DisconnectOld)

local function UpdateSelfHear()

	if HearSelf == true then
		for i, v in Wires do
			v.SourceInstance = LPlr.AudioReverb
		end
	else
		for i, v in Wires do
			v.SourceInstance = nil
		end
	end
end

local function UpdateHearSelfButton()
	local button = LPlr.PlayerGui.MicScreen.But
	if HearSelf then

		button.BackgroundColor3 = Color3.new(0, 0.333333, 0)
		button.Text = "Hear Self: ON"
	else

		button.BackgroundColor3 = Color3.new(0.8, 0.2, 0.2)
		button.Text = "Hear Self: OFF"
	end
end

local function UpdateEmitNote()

	RP.MicParticleEvent:FireServer("EmitNotes", EmitNotes)

end


RP.MicParticleEvent.OnClientEvent:Connect(function(Condition, Plr, WiresReceived)
	if Condition == 1 then
		ConnectNew(Plr)
	elseif Condition == 2 then
		DisconnectOld(Plr)
	elseif Condition == 3 then

		Wires = WiresReceived

		LPlr.PlayerGui.MicScreen.But.Visible = true
		LPlr.PlayerGui.MicScreen.EffectBut.Visible = false
		UpdateSelfHear()
		UpdateHearSelfButton() -- Update button appearance
	elseif Condition == 4 then
		LPlr.PlayerGui.MicScreen.But.Visible = false
		LPlr.PlayerGui.MicScreen.EffectBut.Visible = false

	elseif Condition == "Fetch" then
		for i, v in Plr do
			ConnectNew(v)
		end
	end
end)


task.spawn(function()
	while true do

		local HighestLevel = 0
		local TotalSingers = 0

		local StageNotes = game:GetService("CollectionService"):GetTagged("StageNote")

		for i, v in Connecteds do
			if v.Analyzer then
				TotalSingers += 1
				local Level = v.Analyzer.RmsLevel
				local StageSet = workspace:FindFirstChild("StageSet")
				if StageSet then
					local Mic = StageSet:FindFirstChild("Mic")
					if Mic then
						-- your code here

						if i:GetAttribute("EmitNotes") == true and Level > 0.01 then

							HighestLevel = math.max(HighestLevel, Level)

							local RColor = math.clamp(-0.25 + Level, 0, 0.25)
							local GColor = math.clamp(0.25 - (math.abs(0.25 - Level)), 0, 0.25)
							local BColor = math.clamp(0.25 - Level, 0, 0.25)

							local ChosenColor = Color3.new(RColor * 4, GColor * 4, BColor * 4)

							--print(Level, ChosenColor)


							for i, v in StageNotes do
								local ClonedNote = NoteEffect:Clone()

								ClonedNote.Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, ChosenColor),
									ColorSequenceKeypoint.new(1, ChosenColor),
								})

								ClonedNote.Speed = NumberRange.new(3 + (Level * 250), 3 + (Level * 250))
								ClonedNote.LightEmission = 0.5 + Level

								ClonedNote.Parent = v
								ClonedNote:Emit(1)

								game.Debris:AddItem(ClonedNote, 1)
							end

						end

					end
				end
			end
		end

		for i, v in StageNotes do
			local LightAtt = v:FindFirstChild("LightAtt")
			if LightAtt then
				local SpotLight = LightAtt:FindFirstChild("SpotLight")
				if SpotLight then
					if HighestLevel > 0 then
						SpotLight.Enabled = true
					else
						SpotLight.Enabled = false
					end
					game:GetService("TweenService"):Create(SpotLight, TweenInfo.new(0.1, Enum.EasingStyle.Linear), {Angle = math.clamp((HighestLevel * 2) * 180, 0, 90)}):Play()
				end
			end
		end

		local StageSet = workspace:FindFirstChild("StageSet")
		if StageSet then
			local Mic = StageSet:FindFirstChild("Mic")
			if Mic then
				local Att = Mic:FindFirstChild("Att")
				if Att then
					local SpotLight = Att:FindFirstChild("SpotLight")
					if SpotLight then
						if TotalSingers > 0 then
							game:GetService("TweenService"):Create(SpotLight, TweenInfo.new(0.1, Enum.EasingStyle.Linear), {Angle = 80}):Play()
						else
							game:GetService("TweenService"):Create(SpotLight, TweenInfo.new(0.1, Enum.EasingStyle.Linear), {Angle = 10}):Play()
						end
					end
				end
			end
		end

		task.wait(0.1)
	end
end)

repeat task.wait() until LPlr.PlayerGui:FindFirstChild("MicScreen")

RP.MicParticleEvent:FireServer("Fetch")

LPlr.PlayerGui.MicScreen.But.Activated:Connect(function()
	HearSelf = not HearSelf
	UpdateSelfHear()
	UpdateHearSelfButton()
end)
LPlr.PlayerGui.MicScreen.EffectBut.Activated:Connect(function()
	EmitNotes = not EmitNotes
	UpdateEmitNote()
end)