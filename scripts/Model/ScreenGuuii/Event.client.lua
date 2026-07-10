local l__ReplicatedStorage__1 = game:GetService("ReplicatedStorage");
local l__Players__2 = game:GetService("Players");
local l__Debris__3 = game:GetService("Debris");
local l__RunService__4 = game:GetService("RunService");
local l__TweenService__1 = game:GetService("TweenService");
local l__Lighting__4 = game:GetService("Lighting");
local u4 = Vector3.new(-472.745, 11.244, -488.718);
local doit = false
local ticking = false

local function comma(p1)
	local v2 = p1;
	local k;
	while true do
		local v3, v4 = string.gsub(v2, "^(-?%d+)(%d%d%d)", "%1,%2");
		k = v4;
		v2 = v3;
		if k ~= 0 then

		else
			break;
		end;	
	end;
	return v2;
end;

local function event(donator, reciever, amount)	

	local function tweening(p3, p4, p5)
		l__TweenService__1:Create(p3, TweenInfo.new(p4, Enum.EasingStyle.Quint), p5):Play();
	end;

	local function u2(p1, p2)
		p1.Speed = NumberRange.new(p1.Speed.Min * p2, p1.Speed.Max * p2);
		p1.Acceleration = p1.Acceleration * p2;
		local l__Keypoints__5 = p1.Size.Keypoints;
		local v6 = {};
		for v7 = 1, #l__Keypoints__5 do
			table.insert(v6, NumberSequenceKeypoint.new(l__Keypoints__5[v7].Time, l__Keypoints__5[v7].Value * p2, l__Keypoints__5[v7].Envelope * p2));
		end;
		p1.Size = NumberSequence.new(v6);
	end;
	local v22 = Instance.new("ColorCorrectionEffect");
	v22.Enabled = true;
	v22.Name = "EventColorCorrection";
	v22.Parent = game.Lighting;
	local v23 = Instance.new("BloomEffect");
	v23.Enabled = true;
	v23.Name = "SmiteBloom";
	v23.Size = 20;
	v23.Threshold = 0.1;
	v23.Intensity = -1;
	v23.Parent = game.Lighting;
	local u6 = math.random(-180, 180);
	local v11 = game.ReplicatedStorage.VFX.Templates.Live:Clone()
	local v5 = v11.Objects.NPC:Clone()
	local v16 = v11.Objects.FloorAmbiance:Clone();
	local v17 = v11.Objects.Ambiance:Clone();
	local impact = v11.Objects.ImpactVisuals
	local u18 = v11.Objects.Heavenball:Clone()
	local v67 = v11.Objects.Whitehole:Clone()
	local v68 = v11.Objects.Whitehole2:Clone()
	local v69 = v11.Objects.Whitehole3:Clone()
	local v70 = v11.Objects.Whitehole4:Clone()
	local v38 = v16:Clone();
	v38.Position = u4 + Vector3.new(0, -0.5, 0);
	v38.Parent = workspace;
	local v39 = v17:Clone();
	v39.Position = u4 + Vector3.new(0, 0, 0);
	v39.Size = Vector3.new(1000, 1000, 1000);
	v39.CFrame = v39.CFrame:ToWorldSpace(CFrame.Angles(0, math.rad(u6), 0.5235987755982988));
	v39.Position = v39.Position + v39.CFrame.UpVector * 600;
	v39.Parent = workspace;
	l__TweenService__1:Create(v38, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
		Size = Vector3.new(2048, 1, 2048)
	}):Play();
	local v19 = v11.Objects.Orb:Clone();
	local v15 = v11.Objects.Meteor:Clone();
	local u3 = require(script.CameraShaker);
	local l__Sounds__20 = v11.Sounds:Clone()
	l__Sounds__20.Parent = game.Workspace
	local v24 = u3.new(Enum.RenderPriority.Camera.Value, function(p9)
		workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame * p9;
	end);

	l__TweenService__1:Create(v22, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
		TintColor = Color3.fromRGB(255, 128, 255), 
		Brightness = 0.25, 
		Saturation = 0.1, 
		Contrast = 0.25
	}):Play();

	local v25 = v19:Clone();
	v25.Parent = workspace;
	v25.Position = Vector3.new(-616.455, 74.457, -471.17) --BLACK HOLE SPAWN POSITION

	v24:Start();
	v24:ShakeSustain(u3.Presets.Earthquake);



	local ambiance = l__Sounds__20.Ambiance:Clone()
	ambiance.Parent = workspace
	ambiance:Play()

	for v1, v2 in pairs(v25.Attachment:GetChildren()) do
		if v2:IsA("ParticleEmitter") then
			u2(v2, 1.75);
			v2.Enabled = true;
		end;
	end;

	for v40, v41 in pairs(v38:GetChildren()) do
		if v41:IsA("ParticleEmitter") then
			u2(v41, 1.75);
			v41.Enabled = true;
		end;
	end;
	for v42, v43 in pairs(v39:GetChildren()) do
		if v43:IsA("ParticleEmitter") then
			u2(v43, 2.5);
			v43.Enabled = true;
		end;
	end;

	local u8 = true;
	local u9 = 0.5;
	spawn(function()
		while u8 == true do
			wait(u9);
			spawn(function()
				local v30 = math.random(100, 400) / 100;
				local v31 = math.random(250, 400) / 100;
				local v32 = math.random(500, 750);
				local v33 = v15:Clone();
				v33.Parent = workspace;
				v33.Transparency = 1;
				v33.Position = u4 + Vector3.new(math.random(-750, 750), 0, math.random(-750, 750));
				v33.Size = v33.Size * v30;
				v33.CFrame = v33.CFrame:ToWorldSpace(CFrame.Angles(math.rad(math.random(-10, 10)), math.rad(u6), 0.5235987755982988));
				v33.Position = v33.Position + v33.CFrame.UpVector * v32;
				for v34, v35 in pairs(v33:GetDescendants()) do
					if v35:IsA("ParticleEmitter") then
						u2(v35, v30);
						if string.find(v35.Name, "Meteor_") ~= nil then
							v35.Enabled = true;
						end;
					end;
				end;
				v33.Glow.Range = v33.Glow.Range * v30;
				v33.Glow.Enabled = true;
				v33.Trail0.Position = v33.Trail0.Position * (v30 / 2);
				v33.Trail1.Position = v33.Trail1.Position * (v30 / 2);
				v33.Trail.Enabled = true;
				v33.Whoosh.Volume = 0;
				v33.Whoosh.TimePosition = math.random(0, v33.Whoosh.TimeLength);
				v33.Whoosh.PlaybackSpeed = 1.5 - v30 * 0.15;
				v33.Impact.PlaybackSpeed = 1.5 - v30 * 0.15;
				v33.Whoosh.Playing = true;
				l__TweenService__1:Create(v33, TweenInfo.new(v31, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false, 0), {
					Position = v33.Position + v33.CFrame.UpVector * -v32, 
					Orientation = Vector3.new(math.random(-180, 180) * 3, math.random(-180, 180) * 3, math.random(-180, 180) * 3)
				}):Play();
				l__TweenService__1:Create(v33, TweenInfo.new(v31 * 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
					Transparency = 0
				}):Play();
				l__TweenService__1:Create(v33.Whoosh, TweenInfo.new(v31 * 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
					Volume = 1
				}):Play();
				wait(v31);
				v33.Transparency = 1;
				v33.Orientation = Vector3.new(0, 0, 0);
				v33.Glow.Range = v33.Glow.Range * 1.5;
				v33.Glow.Brightness = v33.Glow.Brightness * 3;
				l__TweenService__1:Create(v33.Glow, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0), {
					Brightness = 0, 
					Range = v33.Glow.Range / 2
				}):Play();
				for v36, v37 in pairs(v33:GetDescendants()) do
					if v37:IsA("ParticleEmitter") then
						if string.find(v37.Name, "Meteor_") ~= nil then
							v37.Enabled = false;
						end;
						if string.find(v37.Name, "Explosion_") ~= nil then
							v37:Emit(v37:GetAttribute("EmitCount"));
						end;
					end;
				end;
				v33.Trail.Enabled = false;
				v33.Whoosh.Playing = false;
				v33.Impact:Play();
				wait(3);
				v33:Destroy();
			end);		
		end;
	end);

	spawn(function()
		l__Sounds__20.Summon:Play();
		l__Sounds__20.Earthquake:Play();
		v25.PortalAmbiance.Playing = true;
		v25.PortalOpen1:Play();
		v25.PortalOpen2:Play();
		l__TweenService__1:Create(v25.PortalAmbiance, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0), {
			Volume = 1.5, 
			PlaybackSpeed = 1.25
		}):Play();
		l__TweenService__1:Create(v25, TweenInfo.new(7, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0), {
			Size = Vector3.new(50,50,50)
		}):Play();
		l__Sounds__20.CrumbleLoop.Playing = true;
		l__TweenService__1:Create(l__Sounds__20.CrumbleLoop, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Volume = 0.5
		}):Play();
		l__Sounds__20.FireLoop.Playing = true;
		l__TweenService__1:Create(l__Sounds__20.FireLoop, TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Volume = 0.5, 
			PlaybackSpeed = 1
		}):Play();
		v24:ShakeSustain(u3.Presets.Earthquake);
		wait(7);
		l__TweenService__1:Create(l__Sounds__20.CrumbleLoop, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Volume = 0
		}):Play();
		v24:StopSustained(6);
		l__TweenService__1:Create(v25.PortalAmbiance, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false, 0), {
			Volume = 0, 
			PlaybackSpeed = 0
		}):Play();
	end)

	wait(math.random(14, 19))
	v67.Parent = workspace
	v68.Parent = workspace
	v69.Parent = workspace
	v70.Parent = workspace
	local heavenball = u18:Clone()
	local charge = l__Sounds__20.Charge_2:Clone()
	charge.Parent = heavenball
	heavenball.Parent = workspace
	charge:Play()
	wait(1.25)
	doit = true
	if doit then
		tweening(heavenball, 6, {
			Transparency = 0
		});
		local ending = l__Sounds__20.ChargeEndSound:Clone()
		ending.Parent = heavenball
		ending:Play()
		wait(1.5)
		v67:Destroy()
		v68:Destroy()
		v69:Destroy()
		v70:Destroy()
		charge:Destroy()
		ending:Destroy()
		l__Sounds__20.Twinkle:Play()
		l__TweenService__1:Create(heavenball, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0), {
			Position = Vector3.new(-128.243, 227.481, 116.418) --BLACK HOLE POSITON
		}):Play();
		wait(1.25)

		doit = false
	end

	if not doit then
		l__TweenService__1:Create(heavenball, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0), {
			Size = Vector3.new(50,50,50)
		}):Play();
		l__Sounds__20.CrumbleLoop.Playing = true;
		l__TweenService__1:Create(l__Sounds__20.CrumbleLoop, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Volume = 0.5
		}):Play();
		l__Sounds__20.Sparkle:Play()
		v24:ShakeSustain(u3.Presets.Earthquake);
		wait(3)
		ticking = true
	end

	if ticking then
		local ticksound = l__Sounds__20.Tick:Clone()
		ticksound.Parent = workspace
		ticksound.Playing = true
		l__Lighting__4.ClockTime = 10
		l__Lighting__4.FogColor = Color3.fromRGB(144, 228, 248)
		wait(1)
		l__Lighting__4.ClockTime = 0
		l__Lighting__4.FogColor = Color3.fromRGB(0,0,0)
		wait(1)
		l__Lighting__4.ClockTime = 10
		l__Lighting__4.FogColor = Color3.fromRGB(144, 228, 248)
		wait(1)
		l__Lighting__4.ClockTime = 0
		l__Lighting__4.FogColor = Color3.fromRGB(0,0,0)
		wait(1)
		l__Lighting__4.ClockTime = 10
		l__Lighting__4.FogColor = Color3.fromRGB(144, 228, 248)
		wait(1)
		l__Lighting__4.ClockTime = 0
		l__Lighting__4.FogColor = Color3.fromRGB(0,0,0)
		wait(1)
		l__Lighting__4.ClockTime = 10
		l__Lighting__4.FogColor = Color3.fromRGB(144, 228, 248)
		wait(1)
		l__Lighting__4.ClockTime = 0
		l__Lighting__4.FogColor = Color3.fromRGB(0,0,0)
		wait(1)
		l__Lighting__4.ClockTime = 10
		l__Lighting__4.FogColor = Color3.fromRGB(144, 228, 248)
		wait(1)
		l__Lighting__4.ClockTime = 0
		l__Lighting__4.FogColor = Color3.fromRGB(0,0,0)
		wait(1)
		l__Lighting__4.ClockTime = 10
		l__Lighting__4.FogColor = Color3.fromRGB(144, 228, 248)
		wait(1)
		l__Lighting__4.ClockTime = 0
		l__Lighting__4.FogColor = Color3.fromRGB(0,0,0)
		wait(1)
		l__Lighting__4.ClockTime = 10
		l__Lighting__4.FogColor = Color3.fromRGB(144, 228, 248)
		wait(1)
		l__Lighting__4.ClockTime = 0
		l__Lighting__4.FogColor = Color3.fromRGB(0,0,0)
		wait(1)
		l__Lighting__4.ClockTime = 10
		l__Lighting__4.FogColor = Color3.fromRGB(144, 228, 248)
		wait(1)
		l__Lighting__4.ClockTime = 0
		l__Lighting__4.FogColor = Color3.fromRGB(0,0,0)
		wait(1)
		ticksound:Stop()
		ticksound:Destroy()
		wait(5)
		ticking = false
	end

	if not ticking then
		v24:StopSustained(6);

		l__TweenService__1:Create(l__Sounds__20.CrumbleLoop, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Volume = 0
		}):Play();
		wait(1)
		l__TweenService__1:Create(v25, TweenInfo.new(10, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0), {
			Size = Vector3.new(75,75,75)
		}):Play();
		l__TweenService__1:Create(heavenball, TweenInfo.new(10, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0), {
			Size = Vector3.new(74,74,74)
		}):Play();
		for l1, l2 in pairs(v25.Attachment:GetChildren()) do
			if l2:IsA("ParticleEmitter") then
				u2(l2, 2);
			end;
		end;
		wait(10)
		for l1, l2 in pairs(v25.Attachment:GetChildren()) do
			if l2:IsA("ParticleEmitter") then
				l2.Rate = 0
			end;
		end;
		v24:ShakeOnce(8, 20, 1, 6);
		l__TweenService__1:Create(v25.Beams.FlameEffect1, TweenInfo.new(1.7, Enum.EasingStyle.Linear), {
			Brightness = 1.57
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect2, TweenInfo.new(1.7, Enum.EasingStyle.Linear), {
			Brightness = 1.57
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect3, TweenInfo.new(1.7, Enum.EasingStyle.Linear), {
			Brightness = 1.57
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect4, TweenInfo.new(1.7, Enum.EasingStyle.Linear), {
			Brightness = 1.57
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect5, TweenInfo.new(1.7, Enum.EasingStyle.Linear), {
			Brightness = 1.57
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect6, TweenInfo.new(1.7, Enum.EasingStyle.Linear), {
			Brightness = 1.57
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect7, TweenInfo.new(1.7, Enum.EasingStyle.Linear), {
			Brightness = 1.57
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect8, TweenInfo.new(1.7, Enum.EasingStyle.Linear), {
			Brightness = 1.57
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect9, TweenInfo.new(1.7, Enum.EasingStyle.Linear), {
			Brightness = 1.57
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect10, TweenInfo.new(1.7, Enum.EasingStyle.Linear), {
			Brightness = 1.57
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect11, TweenInfo.new(1.7, Enum.EasingStyle.Linear), {
			Brightness = 1.57
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect12, TweenInfo.new(1.7, Enum.EasingStyle.Linear), {
			Brightness = 1.57
		}):Play();
		l__TweenService__1:Create(game.Lighting, TweenInfo.new(1.7), {
			Brightness = 5
		}):Play();
		l__TweenService__1:Create(v25, TweenInfo.new(1.7, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {Position = Vector3.new(-465.682, 11.743, -499.481)}):Play() -- blackhole explosion
		l__TweenService__1:Create(heavenball, TweenInfo.new(1.7, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {Position = Vector3.new(-465.682, 11.743, -499.481)}):Play()
		v25.FlameEffect1_0.BrightFlare.Enabled = true;
		v25.Flames.Enabled = true;
		v25.FlameEffect1_0.FlameRing.Enabled = true;
		v25.FlameEffect1_0.Flames1.Enabled = true;
		v25.FlameEffect1_0.Flames2.Enabled = true;
		v25.FlameEffect1_0.Flames3.Enabled = true;
		l__Sounds__20.Drop1:Play()
		l__Sounds__20.Drop2:Play()
		v25.LaunchSound:Play();
		wait(1.7)
		l__Sounds__20.ExplosionSound:Play()
		l__Sounds__20.Sparkle:Stop()
		ambiance:Destroy()
		v23.Intensity = 0.75
		v23.Threshold = 0.05
		v22.Contrast = 0
		l__TweenService__1:Create(v23, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Intensity = -0.9, 
			Threshold = 0.1
		}):Play()
		l__TweenService__1:Create(v22, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Contrast = 0.25
		}):Play()
		v24:ShakeOnce(12, 4, 1, 6);
		v25.SelectionSphere:Destroy()
		v25.FlameEffect1_0.BrightFlare.Enabled = false;
		v25.Flames.Enabled = false;
		v25.FlameEffect1_0.FlameRing.Enabled = false;
		v25.FlameEffect1_0.Flames1.Enabled = false;
		v25.FlameEffect1_0.Flames2.Enabled = false;
		v25.FlameEffect1_0.Flames3.Enabled = false;
		l__TweenService__1:Create(v25.Beams.FlameEffect1, TweenInfo.new(0.01, Enum.EasingStyle.Linear), {
			Brightness = 0
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect2, TweenInfo.new(0.01, Enum.EasingStyle.Linear), {
			Brightness = 0
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect3, TweenInfo.new(0.01, Enum.EasingStyle.Linear), {
			Brightness = 0
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect4, TweenInfo.new(0.01, Enum.EasingStyle.Linear), {
			Brightness = 0
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect5, TweenInfo.new(0.01, Enum.EasingStyle.Linear), {
			Brightness = 0
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect6, TweenInfo.new(0.01, Enum.EasingStyle.Linear), {
			Brightness = 0
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect7, TweenInfo.new(0.01, Enum.EasingStyle.Linear), {
			Brightness = 0
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect8, TweenInfo.new(0.01, Enum.EasingStyle.Linear), {
			Brightness = 0
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect9, TweenInfo.new(0.01, Enum.EasingStyle.Linear), {
			Brightness = 0
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect10, TweenInfo.new(0.01, Enum.EasingStyle.Linear), {
			Brightness = 0
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect11, TweenInfo.new(0.01, Enum.EasingStyle.Linear), {
			Brightness = 0
		}):Play();
		l__TweenService__1:Create(v25.Beams.FlameEffect12, TweenInfo.new(0.01, Enum.EasingStyle.Linear), {
			Brightness = 0
		}):Play();
		l__TweenService__1:Create(game.Lighting, TweenInfo.new(0.2), {
			Brightness = 150
		}):Play();
		l__TweenService__1:Create(game.Lighting.ColorCorrection, TweenInfo.new(0.05), {
			Brightness = 1.2
		}):Play();
		wait(0.05);
		l__TweenService__1:Create(game.Lighting.ColorCorrection, TweenInfo.new(3), {
			Brightness = 0.05
		}):Play();
		l__TweenService__1:Create(game.Lighting, TweenInfo.new(7), {
			Brightness = 2.66
		}):Play();
		impact.Parent = game.Workspace
		impact.Position = Vector3.new(-131.844, 8.88, 121.994)
		l__TweenService__1:Create(impact, TweenInfo.new(30), {Position = Vector3.new(u4.X, 500, u4.Z)}):Play()
		impact.ApplauseLoop:Play()
		impact.CoinsLoop:Play()
		impact.ChimeLoop:Play()
		impact.EmitPoint.Impact_Spark1:Emit(45)
		impact.EmitPoint.Impact_Spark2:Emit(75)
		impact.EmitPoint.Impact_Spark3:Emit(35)
		impact.EmitPoint.Explosion_Glow:Emit(25)
		impact.EmitPoint.Explosion_Rays:Emit(45)
		impact.EmitPoint.Explosion_Ring:Emit(5)
		impact.EmitPoint.Explosion_Flare:Emit(50)
		impact.EmitPoint.Explosion_ThinRays:Emit(35)
		impact.EmitPoint.Explosion_Shockwave:Emit(15)

		local v18 = impact.BillboardGuiAnimation.Frame

		-- Function to preserve the exact case of the username
		local function preserveExactCase(username)
			return username
		end

		v18.RobuxLogo.Size = UDim2.fromScale(0,0)
		v18.Star.Size = UDim2.fromScale(0,0)
		v18.BottomText.Size = UDim2.fromScale(0,0)
		v18.MiddleText.Size = UDim2.fromScale(0,0)
		v18.TopText.Size = UDim2.fromScale(0,0)
		v18.RobuxLogo.Rotation = -180
		v18.Star.Rotation = 0
		v18.Star.ImageTransparency = 0.9
		v18.TopText.Text = "@" .. preserveExactCase(donator) .. " DONATED"
		v18.MiddleText.Text = "\u{E002}" .. tostring(amount):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
		v18.BottomText.Text = "TO @" .. preserveExactCase(reciever)

		l__TweenService__1:Create(v18.RobuxLogo, TweenInfo.new(15, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0), {Size = UDim2.fromScale(1,1)}):Play()
		l__TweenService__1:Create(v18.RobuxLogo, TweenInfo.new(10, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0), {Rotation = 0}):Play()
		l__TweenService__1:Create(v18.Star, TweenInfo.new(10), {Rotation = 360}):Play()
		l__TweenService__1:Create(v18.Star, TweenInfo.new(10), {ImageTransparency = 1}):Play()

		wait(.25)
		l__TweenService__1:Create(v18.TopText, TweenInfo.new(5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0), {Size = UDim2.fromScale(1.5, 0.1)}):Play()
		wait(.25)
		l__TweenService__1:Create(v18.MiddleText, TweenInfo.new(5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0), {Size = UDim2.fromScale(1, 1)}):Play()
		wait(.25)
		l__TweenService__1:Create(v18.BottomText, TweenInfo.new(5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0), {Size = UDim2.fromScale(1.5, 0.1)}):Play()
		l__TweenService__1:Create(v25, TweenInfo.new(0.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {
			Transparency = 1
		}):Play();
		l__TweenService__1:Create(heavenball, TweenInfo.new(0.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {
			Transparency = 1
		}):Play();
		impact.EmitPoint.Sparks.Enabled = true
		impact.EmitPoint.SparkleExplosion.Enabled = true
		wait(15)
		l__TweenService__1:Create(impact.ChimeLoop, TweenInfo.new(60),{Volume = 0}):Play()
		l__TweenService__1:Create(impact.ApplauseLoop, TweenInfo.new(60),{Volume = 0}):Play()
		l__TweenService__1:Create(impact.CoinsLoop, TweenInfo.new(30),{Volume = 0}):Play()
		heavenball:Remove();
		wait(15)
		v25:Destroy();
		l__TweenService__1:Create(v18, TweenInfo.new(14, Enum.EasingStyle.Quint, Enum.EasingDirection.In, 0, false, 0),{Size = UDim2.fromScale(0,0)}):Play()
		for i,v in pairs(impact.EmitPoint:GetChildren()) do
			if v:IsA("ParticleEmitter") then
				l__TweenService__1:Create(v, TweenInfo.new(14), {Rate = 0}):Play()
			end
		end
		wait(15)
		v18:Destroy()
		wait(45)
		impact.CoinsLoop:Stop()
		impact.ApplauseLoop:Stop()
		impact.ChimeLoop:Stop()
		u8 = false;
		l__TweenService__1:Create(l__Sounds__20.FireLoop, TweenInfo.new(30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Volume = 0, 
			PlaybackSpeed = 0.5
		}):Play();
		for l44, l45 in pairs(v38:GetChildren()) do
			if l45:IsA("ParticleEmitter") then
				l__TweenService__1:Create(l45, TweenInfo.new(60, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
					Rate = 0
				}):Play();
			end;
		end;
		for l46, l47 in pairs(v39:GetChildren()) do
			if l47:IsA("ParticleEmitter") then
				l__TweenService__1:Create(l47, TweenInfo.new(30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
					Rate = 0
				}):Play();
			end;
		end;
		l__TweenService__1:Create(v22, TweenInfo.new(30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			TintColor = Color3.fromRGB(255, 255, 255), 
			Brightness = 0, 
			Saturation = 0, 
			Contrast = 0
		}):Play();
		l__TweenService__1:Create(v23, TweenInfo.new(30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Intensity = -1
		}):Play();
		wait(60);
		v22:Destroy();
		v23:Destroy();
		l__Sounds__20:Destroy()
		v38.Size = Vector3.new(0, 0, 0);
		v39.Size = Vector3.new(0, 0, 0);
		wait(30);
		v38:Destroy();
		v39:Destroy();
	end
end

require(game.ReplicatedStorage.Remotes).OnClientEvent("FireBlackHole"):Connect(function(p8, p9, p10)
	event(p8, p9, p10)
end)