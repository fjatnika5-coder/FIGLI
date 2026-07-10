local l__ReplicatedStorage__1 = game:GetService("ReplicatedStorage")
local l__LocalPlayer__2 = game.Players.LocalPlayer
local l__Debris__3 = game:GetService("Debris")
local l__TweenService__1 = game:GetService("TweenService")
local l__PhysicsService__2 = game:GetService("PhysicsService")
local u3 = require(script.CameraShaker)
local u4 = Vector3.new(12, 27.502, -144.622) --Nuke Target Position
local function u5(p1, p2)
	p1.Speed = NumberRange.new(p1.Speed.Min * p2, p1.Speed.Max * p2)
	p1.Acceleration = p1.Acceleration * p2
	local l__Keypoints__4 = p1.Size.Keypoints
	local v5 = {}
	for v6 = 1, #l__Keypoints__4 do
		table.insert(v5, NumberSequenceKeypoint.new(l__Keypoints__4[v6].Time, l__Keypoints__4[v6].Value * p2, l__Keypoints__4[v6].Envelope * p2))
	end
	p1.Size = NumberSequence.new(v5)
end
local l__RunService__6 = game:GetService("RunService")
local function u7(p3, p4, p5, p6)
	local v7 = p3:Clone()
	local l__NukeCFrame__8 = v7.NukeValues.NukeCFrame
	local l__Frame__9 = v7.BillboardGuiAnimation.Frame
	l__Frame__9.TextLabels.TopText.Visible = true
	l__Frame__9.TextLabels.BottomText.Visible = true
	local l__CenterEmitPoint__10 = v7.CenterEmitPoint
	local l__ThrustEmitPoint__11 = v7.ThrustEmitPoint
	local v12 = Instance.new("BloomEffect")
	v12.Enabled = true
	v12.Name = "NukeBloom"
	v12.Size = 15
	v12.Threshold = 0.25
	v12.Intensity = -1
	v12.Parent = game.Lighting
	local l__Objects__13 = v7.Objects
	local v14 = l__Objects__13.ConfettiBox:Clone()
	l__Objects__13.ConfettiBox:Destroy()
	l__Objects__13:Destroy()
	local v15 = u3.new(Enum.RenderPriority.Camera.Value, function(p7)
		workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame * p7
	end)
	v15:Start()
	v7.Position = u4
	u5(l__ThrustEmitPoint__11.Flame, 5)
	u5(l__ThrustEmitPoint__11.Shockwave, 15)
	u5(l__ThrustEmitPoint__11.BigShockwave, 50)
	u5(l__ThrustEmitPoint__11.Flame2, 5)
	u5(l__ThrustEmitPoint__11.Flame3, 5)
	u5(l__ThrustEmitPoint__11.Flame4, 5)
	u5(l__ThrustEmitPoint__11.Flame5, 10)
	u5(l__ThrustEmitPoint__11.Smoke, 1.5)
	u5(l__ThrustEmitPoint__11.SmokePreLaunch, 3)
	u5(l__ThrustEmitPoint__11.SmokeLaunch, 4)
	u5(l__ThrustEmitPoint__11.SmokeRing, 4)
	u5(v7.Sparkles, 2.5)
	u5(v7.Sparks, 3)
	u5(l__CenterEmitPoint__10.Rays1, 25)
	u5(l__CenterEmitPoint__10.Rays2, 25)
	u5(l__CenterEmitPoint__10.Rays3, 25)
	u5(l__CenterEmitPoint__10.SmoothRaysBig, 7.5)
	u5(l__CenterEmitPoint__10.RaysBig, 8)
	u5(l__CenterEmitPoint__10.SparkleExplosion, 4)
	u5(l__CenterEmitPoint__10.Spark3, 25)
	v7.CFrame = game.Workspace.NukeModel.CFrame.Value
	v7.AlignPosition.Position = v7.Position
	v7.AlignOrientation.CFrame = v7.CFrame
	l__NukeCFrame__8.Value = v7.CFrame
	v7.Anchored = false
	v7.Parent = workspace
	local v16 = l__RunService__6.Heartbeat:Connect(function(p8)
		v7.AlignPosition.Position = l__NukeCFrame__8.Value.Position
		v7.AlignOrientation.CFrame = l__NukeCFrame__8.Value
	end)
	wait(1)
	script.Alarm:Play()
	v7.Sparkles.Enabled = false
	v7.ThrustEmitPoint.SmokePreLaunch.Enabled = true
	v7.ThrustEmitPoint.SmokePreLaunch.Rate = 0
	v7.PreThruster:Play()
	v7.PreThruster.Volume = 0
	v7.PreThruster.PlaybackSpeed = 0.1
	l__TweenService__1:Create(v7.PreThruster, TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
		Volume = 1, 
		PlaybackSpeed = 0.5
	}):Play()
	l__TweenService__1:Create(v7.ThrustEmitPoint.SmokePreLaunch, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
		Rate = 100
	}):Play()
	wait(5)
	v15:ShakeSustain(u3.Presets.Earthquake)
	v7.Sparkles.Enabled = true
	v7.ThrustEmitPoint.SmokePreLaunch.Enabled = false
	l__ThrustEmitPoint__11.SmokeLaunch:Emit(50)
	v7.AlignPosition.Responsiveness = 25
	v7.AlignOrientation.Responsiveness = 25
	v7.PreLaunch:Play()
	v7.Thruster2:Play()
	l__TweenService__1:Create(v7.Thruster2, TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0), {
		PlaybackSpeed = 1.5, 
		Volume = 3
	}):Play()
	l__TweenService__1:Create(v7.PreThruster, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
		Volume = 1, 
		PlaybackSpeed = 1
	}):Play()
	for v17, v18 in pairs(l__ThrustEmitPoint__11:GetChildren()) do
		if string.find(v18.Name, "Flame") == nil then
			v18.Enabled = true
		end
	end
	l__ThrustEmitPoint__11.SmokeRing.Enabled = false
	l__ThrustEmitPoint__11.SmokeLaunch.Enabled = false
	l__ThrustEmitPoint__11.Shockwave.Enabled = false
	l__ThrustEmitPoint__11.BigShockwave.Enabled = false
	l__ThrustEmitPoint__11.Flare.Enabled = false
	l__CenterEmitPoint__10.Rays1.Enabled = true
	l__CenterEmitPoint__10.Rays2.Enabled = true
	l__CenterEmitPoint__10.Rays3.Enabled = true
	for v19 = 1, 10 do
		l__NukeCFrame__8.Value = l__NukeCFrame__8.Value:ToWorldSpace(CFrame.Angles(0, 0, 0.17453292519943295))
		l__NukeCFrame__8.Value = l__NukeCFrame__8.Value:ToWorldSpace(CFrame.new(0, 25, 0))
		wait(v19 * 0.0125)
	end
	v7.AlignPosition.Responsiveness = 10
	v7.AlignOrientation.Responsiveness = 10
	l__NukeCFrame__8.Value = CFrame.new(l__NukeCFrame__8.Value.Position, u4):ToWorldSpace(CFrame.Angles(-1.5707963267948966, 0, 0))
	wait(0.5)
	v12.Intensity = 1
	v12.Size = 20
	l__TweenService__1:Create(v12, TweenInfo.new(1, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0, false, 0), {
		Intensity = -1, 
		Size = 10
	}):Play()
	v7.AlignPosition.Responsiveness = 50
	v7.AlignOrientation.Responsiveness = 50
	l__ThrustEmitPoint__11.SmokeRing:Emit(50)
	l__ThrustEmitPoint__11.Flame:Emit(25)
	l__ThrustEmitPoint__11.Flame2:Emit(25)
	l__ThrustEmitPoint__11.Flame3:Emit(25)
	l__ThrustEmitPoint__11.Flame4:Emit(25)
	l__ThrustEmitPoint__11.Flame5:Emit(25)
	l__ThrustEmitPoint__11.Shockwave.Enabled = true
	l__ThrustEmitPoint__11.BigShockwave:Emit(1)
	v7.Launch:Play()
	v7.Thruster:Play()
	for v20, v21 in pairs(l__ThrustEmitPoint__11:GetChildren()) do
		v21.Enabled = true
	end
	l__ThrustEmitPoint__11.SmokeRing.Enabled = false
	l__ThrustEmitPoint__11.SmokeLaunch.Enabled = false
	l__ThrustEmitPoint__11.BigShockwave.Enabled = false
	l__ThrustEmitPoint__11.Flare:Emit(10)
	l__TweenService__1:Create(l__NukeCFrame__8, TweenInfo.new(2.5, Enum.EasingStyle.Back, Enum.EasingDirection.In, 0, false, 0), {
		Value = CFrame.new(u4 + Vector3.new(0, -1, 0), u4):ToWorldSpace(CFrame.Angles(1.5707963267948966, 0, 0))
	}):Play()
	wait(2.6)
	v15:StopSustained(0)
	v15:ShakeOnce(4, 6, 0.25, 4)
	script.Alarm:Stop()
	v12.Intensity = 1
	v12.Size = 30
	l__TweenService__1:Create(v12, TweenInfo.new(5, Enum.EasingStyle.Circular, Enum.EasingDirection.Out, 0, false, 0), {
		Intensity = -1, 
		Size = 10
	}):Play()
	v7.Anchored = true
	v7.Transparency = 1
	v7.Size = Vector3.new(0, 0, 0)
	v7.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	v7.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	v7.CFrame = l__NukeCFrame__8.Value
	v7.PreThruster:Stop()
	v7.Thruster:Stop()
	v7.Thruster2:Stop()
	v7.Explosion.TimePosition = 0.75
	v7.Explosion:Play()
	v7.ChimeLoop:Play()
	v7.ApplauseLoop:Play()
	v7.CoinsLoop:Play()
	
	-- Function to preserve the exact case of the username
	local function preserveExactCase(username)
		return username
	end

	-- Example where 'p4' and 'p5' are player names
	l__Frame__9.TextLabels.TopText.Text = "@" .. preserveExactCase(p4) .. " DONATED"
	-- Reverse the string, add commas every 3 digits, and then reverse it back
	l__Frame__9.TextLabels.MiddleText.Text = "\u{E002}" .. tostring(p6):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
	l__Frame__9.TextLabels.BottomText.Text = "TO @" .. preserveExactCase(p5)
	l__Frame__9.RobuxLogo.Size = UDim2.fromScale(0, 0)
	l__Frame__9.RobuxLogo.Rotation = -180
	l__Frame__9.Star.Size = UDim2.fromScale(0, 0)
	l__Frame__9.TextLabels.BottomText.Size = UDim2.fromScale(0, 0)
	l__Frame__9.TextLabels.BottomText.Position = UDim2.fromScale(0.5, 0.5)
	l__Frame__9.TextLabels.MiddleText.Size = UDim2.fromScale(0, 0)
	l__Frame__9.TextLabels.TopText.Position = UDim2.fromScale(0.5, 0.5)
	l__Frame__9.TextLabels.TopText.Size = UDim2.fromScale(0, 0)
	l__Frame__9.Parent.Enabled = true
	l__TweenService__1:Create(v7, TweenInfo.new(20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
		Position = u4 + Vector3.new(0, 250, 0)
	}):Play()
	l__TweenService__1:Create(l__Frame__9.RobuxLogo, TweenInfo.new(10, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0), {
		Size = UDim2.fromScale(1, 1)
	}):Play()
	l__TweenService__1:Create(l__Frame__9.RobuxLogo, TweenInfo.new(15, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0), {
		Rotation = 0
	}):Play()
	l__TweenService__1:Create(l__Frame__9.Star, TweenInfo.new(5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0), {
		Size = UDim2.fromScale(1.5, 1.5)
	}):Play()
	l__TweenService__1:Create(l__Frame__9.Star, TweenInfo.new(15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
		Rotation = 360
	}):Play()
	l__TweenService__1:Create(l__Frame__9.Star, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 5), {
		ImageTransparency = 1, 
		ImageColor3 = Color3.fromRGB(255, 255, 0)
	}):Play()
	for v22, v23 in pairs(l__ThrustEmitPoint__11:GetChildren()) do
		v23.Enabled = false
	end
	v7.Sparkles.Enabled = false
	for v24, v25 in pairs(l__CenterEmitPoint__10:GetChildren()) do
		v25.Enabled = false
	end
	l__CenterEmitPoint__10.SparkleExplosion:Emit(100)
	l__CenterEmitPoint__10.Shockwave:Emit(15)
	l__CenterEmitPoint__10.FractalBurst:Emit(3)
	l__CenterEmitPoint__10.RaysBig:Emit(20)
	l__CenterEmitPoint__10.Spark1:Emit(100)
	l__CenterEmitPoint__10.Spark2:Emit(100)
	l__CenterEmitPoint__10.Spark3:Emit(50)
	local v26 = v14:Clone()
	v26.Position = u4 + Vector3.new(0, 250, 0)
	v26.Parent = workspace
	l__TweenService__1:Create(v26, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
		Size = Vector3.new(1000, 100, 1000)
	}):Play()
	spawn(function()
		local v27 = v26:GetChildren()
		for v28, v29 in pairs(v27) do
			if v29:IsA("ParticleEmitter") then
				v29.Enabled = true
			end
		end
		wait(60)
		for v30, v31 in pairs(v27) do
			if v31:IsA("ParticleEmitter") then
				l__TweenService__1:Create(v31, TweenInfo.new(60, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
					Rate = 0
				}):Play()
			end
		end
		wait(60)
		v26.Size = Vector3.new(0, 0, 0)
		wait(30)
		v26:Destroy()
	end)
	local l__SpawnFireworks__32 = script.Scripts.SpawnFireworks
	l__SpawnFireworks__32.SpawnPosition.Value = u4
	l__SpawnFireworks__32.Disabled = false
	v7.Sparks.Enabled = true
	l__CenterEmitPoint__10.SparkleExplosion.Enabled = true
	l__TweenService__1:Create(v7.Sparks, TweenInfo.new(45, Enum.EasingStyle.Quint, Enum.EasingDirection.In, 0, false, 0), {
		Rate = 0
	}):Play()
	l__TweenService__1:Create(l__CenterEmitPoint__10.SparkleExplosion, TweenInfo.new(45, Enum.EasingStyle.Quint, Enum.EasingDirection.In, 0, false, 0), {
		Rate = 0
	}):Play()
	l__TweenService__1:Create(v7.ChimeLoop, TweenInfo.new(55, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0), {
		Volume = 0, 
		PlaybackSpeed = 0.75
	}):Play()
	l__TweenService__1:Create(v7.ApplauseLoop, TweenInfo.new(60, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0), {
		Volume = 0
	}):Play()
	l__TweenService__1:Create(v7.CoinsLoop, TweenInfo.new(50, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0), {
		Volume = 0, 
		PlaybackSpeed = 1
	}):Play()
	wait(30)
	l__TweenService__1:Create(l__Frame__9.UIScale, TweenInfo.new(15, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0), {
		Scale = 0
	}):Play()
	wait(15)
	l__Frame__9.Parent.Enabled = false
	wait(30)
	v15:Stop()
	v12:Destroy()
	v16:Disconnect()
	v7:Destroy()
	v26:Destroy()
	v14:Destroy()
end
require(l__ReplicatedStorage__1.Remotes).OnClientEvent("FireNuke"):Connect(function(p9, p10, p11)
	print('yes')
	if l__LocalPlayer__2:GetAttribute('GlobalEffects') ~= false then
		warn('enabled')
		u7(l__ReplicatedStorage__1.VFX.MoonVFXAssets.Nuke, p9, p10, p11)
	else
		warn('disabled')
	end
end)