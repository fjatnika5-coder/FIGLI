wait = task.wait;
local l__ReplicatedStorage__1 = game:GetService("ReplicatedStorage");
local l__Players__2 = game:GetService("Players");
local l__Debris__3 = game:GetService("Debris");
local l__RunService__4 = game:GetService("RunService");
local l__TweenService__1 = game:GetService("TweenService");

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

local u3 = require(script.CameraShaker);
local u4 = Vector3.new(-310, 16.5, 279);

local function u5(p3, p4)
	local v8 = game.Players:GetHumanoidDescriptionFromUserId(p3);
	v8.DepthScale = v8.DepthScale * 53;
	v8.HeadScale = v8.HeadScale * 53; 
	v8.HeightScale = v8.HeightScale * 53;
	v8.WidthScale = v8.WidthScale * 53;
	p4.Humanoid:ApplyDescription(v8);
	for v9, v10 in pairs(p4:GetDescendants()) do
		if (v10:IsA("BasePart") or v10:IsA("Decal")) and v10.Name ~= "HumanoidRootPart" then
			v10.Transparency = 1;
		end;
	end;
end;

local u6 = math.random(-180, 180);

local function u7(p5, p6, p7, p8)
	local UltraHammerGiant = l__ReplicatedStorage__1:FindFirstChild("UltraHammerGiant", true)

	if not UltraHammerGiant then
		warn("❌ [UltraAnimation] UltraHammerGiant tidak ditemukan di ReplicatedStorage!")
		return
	end

	local success, v11 = pcall(function()
		return UltraHammerGiant:Clone()
	end)

	if not success or not v11 then
		warn("❌ [UltraAnimation] Gagal clone UltraHammerGiant:", v11)
		return
	end

	local l__DiamondHammer__12 = v11.DiamondHammer;

	for v13, v14 in pairs(v11:GetDescendants()) do
		if (v14:IsA("BasePart") or v14:IsA("Decal")) and v14.Name ~= "HumanoidRootPart" and (v14:IsDescendantOf(l__DiamondHammer__12) == false or v14:IsDescendantOf(v11.Objects) == false) then
			v14.Transparency = 1;
		end;
	end;
	u2(l__DiamondHammer__12.Handle.MainDiamondCenter.Shockwave, 60);
	u2(l__DiamondHammer__12.Handle.MainDiamondCenter.ChargeGlow, 50);
	u2(l__DiamondHammer__12.Handle.MainDiamondCenter.ChargeRays, 50);
	l__DiamondHammer__12.Handle.Transparency = 1;
	l__DiamondHammer__12.Handle.Diamonds.Transparency = 1;
	l__DiamondHammer__12.Handle.CanCollide = false;
	v11.Parent = workspace;
	u2(l__DiamondHammer__12.Handle.BaseFrontOffset.Shockwave, 10);
	local v15 = v11.Objects.Meteor:Clone();
	local v16 = v11.Objects.FloorAmbiance:Clone();
	local v17 = v11.Objects.Ambiance:Clone();
	local v18 = v11.Objects.ImpactVisuals:Clone();
	local v19 = v11.Objects.Portal:Clone();
	v11.Objects:Destroy();
	local l__Sounds__20 = v11.Sounds;
	l__Sounds__20.Parent = workspace;
	l__Sounds__20.Name = "1MDonationEffect_Sounds";
	local v21 = v11.Humanoid:LoadAnimation(v11.Animations.Giant_MainAnimation);
	local v22 = Instance.new("ColorCorrectionEffect");
	v22.Enabled = true;
	v22.Name = "SmiteColorCorrection";
	v22.Parent = game.Lighting;
	local v23 = Instance.new("BloomEffect");
	v23.Enabled = true;
	v23.Name = "SmiteBloom";
	v23.Size = 20;
	v23.Threshold = 0.1;
	v23.Intensity = -1;
	v23.Parent = game.Lighting;
	local v24 = u3.new(Enum.RenderPriority.Camera.Value, function(p9)
		workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame * p9;
	end);
	v24:Start();
	v11.PrimaryPart = v11.FloorLevel;
	v11:SetPrimaryPartCFrame(CFrame.new(u4.X, u4.Y, u4.Z));
	-- ✅ ROTASI 180° BIAR NGADEP DEPAN (tambah 180 derajat ke random rotation)
	v11:SetPrimaryPartCFrame(v11.FloorLevel.CFrame:ToWorldSpace(CFrame.Angles(0, math.rad(180), 0)));
	v11.PrimaryPart = v11.HumanoidRootPart;
	local v25 = v19:Clone();
	v19.PortalAmbiance.Volume = 0;
	v19.PortalAmbiance.PlaybackSpeed = 0;
	v25.CFrame = v11.FloorLevel.CFrame;
	v25.Parent = workspace;
	v11.FloorLevel:Destroy();
	local l__LeftEyeAttachment__26 = v11.Head.LeftEyeAttachment;
	local l__RightEyeAttachment__27 = v11.Head.RightEyeAttachment;
	l__LeftEyeAttachment__26.Parent = nil;
	l__RightEyeAttachment__27.Parent = nil;
	l__DiamondHammer__12.Parent = nil;
	local v28, v29 = pcall(function()
		u5(p8, v11);
		v11.Humanoid.BodyDepthScale.Value = 50;
		v11.Humanoid.HeadScale.Value = 50;
		v11.Humanoid.BodyHeightScale.Value = 50;
		v11.Humanoid.BodyWidthScale.Value = 50;
	end);
	if v28 == false then
		warn("Unable to set giant's apperance to donator (" .. p5 .. ")  (" .. v29 .. ")");
	end;
	l__DiamondHammer__12.Parent = v11;
	l__DiamondHammer__12.Weld.Attachment0 = v11.RightHand.RightGripAttachment;
	l__LeftEyeAttachment__26.Parent = v11.Head;
	l__RightEyeAttachment__27.Parent = v11.Head;
	l__LeftEyeAttachment__26.Position = Vector3.new(-6, 11, -32);
	l__RightEyeAttachment__27.Position = Vector3.new(6, 11, -32);
	l__Sounds__20.Summon:Play();
	v25.Transparency = 0;
	v25.Sparks.Enabled = true;
	v25.Appearance.Enabled = true;
	l__TweenService__1:Create(v25.Sparks, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0), {
		Rate = 40
	}):Play();
	l__TweenService__1:Create(v25.Appearance, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0), {
		Rate = 40
	}):Play();
	l__TweenService__1:Create(v25, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0), {
		Size = Vector3.new(400, 1, 400)
	}):Play();
	l__TweenService__1:Create(v25.OuterLightBeam, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0), {
		Width0 = 400, 
		Width1 = 600
	}):Play();
	l__TweenService__1:Create(v25.InnerLightBeam, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0), {
		Width0 = 200, 
		Width1 = 300
	}):Play();
	v25.PortalAmbiance.Playing = true;
	v25.PortalOpen1:Play();
	v25.PortalOpen2:Play();
	l__TweenService__1:Create(v25.PortalAmbiance, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false, 0), {
		Volume = 0.5, 
		PlaybackSpeed = 1.25
	}):Play();
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
					Volume = 0.1
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
	local v38 = v16:Clone();
	v38.Position = u4 + Vector3.new(0, -0.5, 0);
	v38.Parent = workspace;
	l__TweenService__1:Create(v38, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
		Size = Vector3.new(2048, 1, 2048)
	}):Play();
	local v39 = v17:Clone();
	v39.Position = u4 + Vector3.new(0, 0, 0);
	v39.Size = Vector3.new(1000, 1000, 1000);
	v39.CFrame = v39.CFrame:ToWorldSpace(CFrame.Angles(0, math.rad(u6), 0.5235987755982988));
	v39.Position = v39.Position + v39.CFrame.UpVector * 600;
	v39.Parent = workspace;
	spawn(function()
		for v40, v41 in pairs(v38:GetChildren()) do
			if v41:IsA("ParticleEmitter") then
				u2(v41, 1.25);
				v41.Enabled = true;
			end;
		end;
		for v42, v43 in pairs(v39:GetChildren()) do
			if v43:IsA("ParticleEmitter") then
				u2(v43, 1.75);
				v43.Enabled = true;
			end;
		end;
		wait(90);
		l__TweenService__1:Create(l__Sounds__20.FireLoop, TweenInfo.new(30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Volume = 0, 
			PlaybackSpeed = 0.5
		}):Play();
		u8 = false;
		for v44, v45 in pairs(v38:GetChildren()) do
			if v45:IsA("ParticleEmitter") then
				l__TweenService__1:Create(v45, TweenInfo.new(60, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
					Rate = 0
				}):Play();
			end;
		end;
		for v46, v47 in pairs(v39:GetChildren()) do
			if v47:IsA("ParticleEmitter") then
				l__TweenService__1:Create(v47, TweenInfo.new(30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
					Rate = 0
				}):Play();
			end;
		end;
		wait(60);
		v38.Size = Vector3.new(0, 0, 0);
		v39.Size = Vector3.new(0, 0, 0);
		wait(30);
		v38:Destroy();
		v39:Destroy();
	end);
	l__TweenService__1:Create(v22, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
		TintColor = Color3.fromRGB(255, 130, 108), 
		Brightness = 0.1, 
		Saturation = 0.1, 
		Contrast = 0.15
	}):Play();
	l__TweenService__1:Create(v23, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
		Intensity = -0.95
	}):Play();
	local function v48(p10)
		local v49 = NumberSequence.new({ NumberSequenceKeypoint.new(0, p10), NumberSequenceKeypoint.new(1, 1) });
		for v50, v51 in pairs(l__DiamondHammer__12.Effects.Beams:GetChildren()) do
			if v51:IsA("Beam") and string.find(v51.Name, "FlameEffect") ~= nil then
				v51.Enabled = true;
				v51.Transparency = v49;
			end;
		end;
	end;
	local v52 = v11.Values.Hammer_FlameEffectTransparency.Changed:Connect(v48);
	v48(1);
	v21:GetMarkerReachedSignal("Eye lense flare"):Connect(function(p11)
		print("Animation event: Eye lense flare");
		l__Sounds__20.LenseFlareEyes:Play();
		v11.Head.LeftEyeAttachment.Flare.Enabled = true;
		v11.Head.LeftEyeAttachment.FlareFlash:Emit(1);
		v11.Head.RightEyeAttachment.Flare.Enabled = true;
		v11.Head.RightEyeAttachment.FlareFlash:Emit(1);
	end);
	v21:GetMarkerReachedSignal("HammerAppear"):Connect(function(p12)
		print("Animation event: HammerAppear " .. p12);
		l__DiamondHammer__12.Handle.AppearSound.Playing = true;
		l__DiamondHammer__12.Handle.AppearSound.Volume = 0;
		l__DiamondHammer__12.Handle.AppearSound.PlaybackSpeed = 0.75;
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.AppearSound, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true, 0), {
			Volume = 0.1
		}):Play();
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.AppearSound, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0), {
			PlaybackSpeed = 1.5
		}):Play();
		l__DiamondHammer__12.Handle.HammerBaseOutline.Sparkles.Enabled = true;
		l__DiamondHammer__12.Handle.HammerBaseOutline.Appearance.Enabled = true;
		l__DiamondHammer__12.Handle.HammerHandleBase.Appearance.Enabled = true;
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.HammerBaseOutline.Sparkles, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0), {
			Rate = 15
		}):Play();
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.HammerBaseOutline.Appearance, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true, 0), {
			Rate = 30
		}):Play();
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.HammerHandleBase.Appearance, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true, 0), {
			Rate = 25
		}):Play();
		l__TweenService__1:Create(l__DiamondHammer__12.Handle, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0), {
			Transparency = 0
		}):Play();
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.Diamonds, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0), {
			Transparency = 0.1
		}):Play();
	end);
	v21:GetMarkerReachedSignal("ChargeSwing"):Connect(function(p13)
		print("Animation event: ChargeSwing");
		l__DiamondHammer__12.Handle.ChargeSound1:Play();
		l__DiamondHammer__12.Handle.ChargeSound2:Play();
		l__DiamondHammer__12.Handle.ChargeSound3:Play();
		l__DiamondHammer__12.Handle.MainChargeSound:Play();
		for v53, v54 in pairs(l__DiamondHammer__12.Handle:GetChildren()) do
			if v54:IsA("Attachment") and string.find(v54.Name, "DiamondCenter") ~= nil then
				v54.Flare.Enabled = true;
			end;
		end;
		l__DiamondHammer__12.Handle.MainDiamondCenter.Shockwave:Emit(1);
		l__DiamondHammer__12.Handle.MainDiamondCenter.ChargeGlow.Enabled = true;
		l__DiamondHammer__12.Handle.MainDiamondCenter.ChargeRays.Enabled = true;
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.MainDiamondCenter.ChargeRays, TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0), {
			TimeScale = 1
		}):Play();
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.MainDiamondCenter.ChargeGlow, TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0), {
			TimeScale = 1
		}):Play();
	end);
	v21:GetMarkerReachedSignal("SwingStart"):Connect(function(p14)
		print("Animation event: SwingStart");
		l__DiamondHammer__12.Handle.ChargeEndSound:Play();
		l__DiamondHammer__12.Handle.MainDiamondCenter.Shockwave:Emit(3);
		l__DiamondHammer__12.Handle.MainDiamondCenter.ChargeGlow.Enabled = false;
		l__DiamondHammer__12.Handle.MainDiamondCenter.ChargeRays.Enabled = false;
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.MainChargeSound, TweenInfo.new(4, Enum.EasingStyle.Quart, Enum.EasingDirection.In, 0, false, 0), {
			Volume = 0.25
		}):Play();
		l__DiamondHammer__12.Handle.BaseCenter.Wind.Volume = 0;
		l__DiamondHammer__12.Handle.BaseCenter.Wind.PlaybackSpeed = 0.5;
		l__DiamondHammer__12.Handle.BaseCenter.Wind.Playing = true;
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.BaseCenter.Wind, TweenInfo.new(3.5, Enum.EasingStyle.Quart, Enum.EasingDirection.In, 0, false, 0), {
			Volume = 0.25, 
			PlaybackSpeed = 2.5
		}):Play();
		l__TweenService__1:Create(v11.Values.Hammer_FlameEffectTransparency, TweenInfo.new(4, Enum.EasingStyle.Quart, Enum.EasingDirection.In, 0, false, 0), {
			Value = 0
		}):Play();
		l__DiamondHammer__12.Handle.HammerBase.Flames.Enabled = true;
		l__DiamondHammer__12.Handle.BaseFrontOffset.Shockwave.Enabled = true;
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.HammerBase.Flames, TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false, 0), {
			Rate = 20
		}):Play();
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.BaseFrontOffset.Shockwave, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false, 0), {
			Rate = 10
		}):Play();
		for v55, v56 in pairs(l__DiamondHammer__12.Effects.Trails:GetChildren()) do
			v56.Enabled = true;
		end;
	end);
	v21:GetMarkerReachedSignal("SwingEnd"):Connect(function(p15)
		print("Animation event: SwingEnd");
		u9 = 0.25;
		l__DiamondHammer__12.Handle.MainChargeSound:Stop();
		l__Sounds__20.Rumble:Play();
		v23.Intensity = 0.75;
		v23.Threshold = 0.05;
		v22.Contrast = 0;
		l__TweenService__1:Create(v23, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Intensity = -0.9, 
			Threshold = 0.1
		}):Play();
		l__TweenService__1:Create(v22, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Contrast = 0.25
		}):Play();
		l__TweenService__1:Create(v11.Values.Hammer_FlameEffectTransparency, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Value = 1
		}):Play();
		l__DiamondHammer__12.Handle.BaseFrontOffset.Shockwave.Enabled = false;
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.HammerBase.Flames, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Rate = 0
		}):Play();
		for v57, v58 in pairs(l__DiamondHammer__12.Effects.Trails:GetChildren()) do
			v58.Enabled = false;
		end;
		l__DiamondHammer__12.Handle.BaseCenter.Wind.Playing = false;
		for v59, v60 in pairs(l__DiamondHammer__12.Handle.BaseCenter:GetChildren()) do
			if v60:IsA("Sound") and string.find(v60.Name, "Impact_") ~= nil then
				v60:Play();
			end;
		end;
		for v61, v62 in pairs(l__DiamondHammer__12.Handle:GetChildren()) do
			if v62:IsA("Attachment") and string.find(v62.Name, "DiamondCenter") ~= nil then
				v62.Flare.Enabled = false;
			end;
		end;
		v24:ShakeOnce(6, 6, 0.25, 5);
		local v63 = v18:Clone();
		v63.Position = u4;
		v63.Parent = workspace;
		u2(v63.EmitPoint.Impact_FractalBurst, 10);
		u2(v63.EmitPoint.Impact_RaysBurst, 25);
		u2(v63.EmitPoint.Impact_Shockwave, 30);
		u2(v63.EmitPoint.Impact_Spark1, 10);
		u2(v63.EmitPoint.Impact_Spark2, 10);
		u2(v63.EmitPoint.Impact_Spark3, 10);
		u2(v63.EmitPoint.Impact_SparkleExplosion, 10);
		u2(v63.EmitPoint.SparkleExplosion, 7.5);
		u2(v63.EmitPoint.Sparks, 5);
		for v64, v65 in pairs(v63.EmitPoint:GetChildren()) do
			if v65:IsA("ParticleEmitter") and string.find(v65.Name, "Impact_") ~= nil then
				v65:Emit(v65:GetAttribute("EmitCount"));
			end;
		end;

		local function preserveExactCase(username)
			return username
		end

		v63.ApplauseLoop.Playing = true;
		v63.ChimeLoop.Playing = true;
		v63.CoinsLoop.Playing = true;
		local l__Frame__66 = v63.BillboardGuiAnimation.Frame;
		l__Frame__66.TopText.Visible = true;
		l__Frame__66.BottomText.Visible = true;
		l__Frame__66.TopText.Text = "@" .. preserveExactCase(p5) .. " DONATED";
		l__Frame__66.MiddleText.Text = "\u{E002}" .. tostring(p7):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "");
		l__Frame__66.BottomText.Text = "TO @" .. preserveExactCase(p6);
		l__Frame__66.RobuxLogo.Size = UDim2.fromScale(0, 0);
		l__Frame__66.RobuxLogo.Rotation = -180;
		l__Frame__66.Star.Size = UDim2.fromScale(0, 0);
		l__Frame__66.BottomText.Size = UDim2.fromScale(0, 0);
		l__Frame__66.BottomText.Position = UDim2.fromScale(0.5, 0.5);
		l__Frame__66.MiddleText.Size = UDim2.fromScale(0, 0);
		l__Frame__66.TopText.Position = UDim2.fromScale(0.5, 0.5);
		l__Frame__66.TopText.Size = UDim2.fromScale(0, 0);
		l__Frame__66.Parent.Enabled = true;
		l__TweenService__1:Create(v63, TweenInfo.new(20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Position = u4 + Vector3.new(0, 400, 0)
		}):Play();
		l__TweenService__1:Create(l__Frame__66.RobuxLogo, TweenInfo.new(10, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0), {
			Size = UDim2.fromScale(1, 1)
		}):Play();
		l__TweenService__1:Create(l__Frame__66.RobuxLogo, TweenInfo.new(15, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0), {
			Rotation = 0
		}):Play();
		l__TweenService__1:Create(l__Frame__66.Star, TweenInfo.new(5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0), {
			Size = UDim2.fromScale(1.5, 1.5)
		}):Play();
		l__TweenService__1:Create(l__Frame__66.Star, TweenInfo.new(15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Rotation = 360
		}):Play();
		l__TweenService__1:Create(l__Frame__66.BottomText, TweenInfo.new(5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0.6), {
			Size = UDim2.fromScale(1.5, 0.1), 
			Position = UDim2.fromScale(0.5, 0.59)
		}):Play();
		l__TweenService__1:Create(l__Frame__66.MiddleText, TweenInfo.new(5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0.4), {
			Size = UDim2.fromScale(1, 1)
		}):Play();
		l__TweenService__1:Create(l__Frame__66.TopText, TweenInfo.new(5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out, 0, false, 0.2), {
			Size = UDim2.fromScale(1.5, 0.1), 
			Position = UDim2.fromScale(0.5, 0.41)
		}):Play();
		l__TweenService__1:Create(l__Frame__66.Star, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 5), {
			ImageTransparency = 1, 
			ImageColor3 = Color3.fromRGB(0, 255, 255)
		}):Play();
		v63.EmitPoint.Sparks.Enabled = true;
		v63.EmitPoint.SparkleExplosion.Enabled = true;
		l__TweenService__1:Create(v63.EmitPoint.Sparks, TweenInfo.new(45, Enum.EasingStyle.Quint, Enum.EasingDirection.In, 0, false, 0), {
			Rate = 0
		}):Play();
		l__TweenService__1:Create(v63.EmitPoint.SparkleExplosion, TweenInfo.new(45, Enum.EasingStyle.Quint, Enum.EasingDirection.In, 0, false, 0), {
			Rate = 0
		}):Play();
		l__TweenService__1:Create(v63.ChimeLoop, TweenInfo.new(55, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0), {
			Volume = 0, 
			PlaybackSpeed = 0.75
		}):Play();
		l__TweenService__1:Create(v63.ApplauseLoop, TweenInfo.new(60, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0), {
			Volume = 0
		}):Play();
		l__TweenService__1:Create(v63.CoinsLoop, TweenInfo.new(50, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0), {
			Volume = 0, 
			PlaybackSpeed = 1
		}):Play();
		wait(30);
		l__TweenService__1:Create(l__Frame__66.UIScale, TweenInfo.new(15, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0), {
			Scale = 0
		}):Play();
		wait(30);
		v63:Destroy();
	end);
	v21:GetMarkerReachedSignal("Release"):Connect(function(p16)
		print("Animation event: Release");
		v11.Head.LeftEyeAttachment.Flare.Enabled = false;
		v11.Head.RightEyeAttachment.Flare.Enabled = false;
	end);
	local l__Appearance__10 = v11.Particles.Appearance;
	v21:GetMarkerReachedSignal("Fade"):Connect(function(p17)
		print("Animation event: Fade " .. p17);
		local v67 = l__Sounds__20.GiantFade:Clone();
		v67.Volume = 0;
		v67.PlaybackSpeed = 1.5;
		v67.Parent = v11.UpperTorso;
		v67.Playing = true;
		l__TweenService__1:Create(v67, TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true, 0), {
			Volume = 0.7
		}):Play();
		l__TweenService__1:Create(v67, TweenInfo.new(8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0), {
			PlaybackSpeed = 0.5
		}):Play();
		for v68, v69 in pairs(v11:GetDescendants()) do
			if (v69:IsA("BasePart") or v69:IsA("Decal")) and v69.Name ~= "HumanoidRootPart" then
				if v69:IsA("Decal") == false then
					local v70 = l__Appearance__10:Clone();
					v70.Parent = v69;
					v70.Enabled = true;
					l__TweenService__1:Create(v70, TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true, 0), {
						Rate = 30
					}):Play();
				end;
				l__TweenService__1:Create(v69, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0), {
					Transparency = 1
				}):Play();
			end;
		end;
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.HammerBaseOutline.Sparkles, TweenInfo.new(8, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0), {
			Rate = 0
		}):Play();
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.HammerBaseOutline.Appearance, TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true, 0), {
			Rate = 70
		}):Play();
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.HammerHandleBase.Appearance, TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true, 0), {
			Rate = 40
		}):Play();
		l__TweenService__1:Create(l__DiamondHammer__12.Handle, TweenInfo.new(8, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0), {
			Transparency = 1
		}):Play();
		l__TweenService__1:Create(l__DiamondHammer__12.Handle.Diamonds, TweenInfo.new(8, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0), {
			Transparency = 1
		}):Play();
	end);
	v21:GetMarkerReachedSignal("FadeEnd"):Connect(function(p18)
		print("Animation event: FadeEnd");
		v52:Disconnect();
		wait(5);
		v11:Destroy();
	end);
	wait(1);
	v21:Play();
	spawn(function()
		l__Sounds__20.Earthquake:Play();
		l__Sounds__20.CrumbleLoop.Volume = 0;
		l__Sounds__20.CrumbleLoop.Playing = true;
		l__TweenService__1:Create(l__Sounds__20.CrumbleLoop, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Volume = 0.1
		}):Play();
		l__Sounds__20.FireLoop.Volume = 0;
		l__Sounds__20.FireLoop.PlaybackSpeed = 0.5;
		l__Sounds__20.FireLoop.Playing = true;
		l__TweenService__1:Create(l__Sounds__20.FireLoop, TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Volume = 0.1, 
			PlaybackSpeed = 1
		}):Play();
		v24:ShakeSustain(u3.Presets.Earthquake);
		for v71, v72 in pairs(v11:GetDescendants()) do
			if (v72:IsA("BasePart") or v72:IsA("Decal")) and v72.Name ~= "HumanoidRootPart" and v72:IsDescendantOf(l__DiamondHammer__12) == false then
				l__TweenService__1:Create(v72, TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
					Transparency = 0
				}):Play();
			end;
		end;
		wait(7);
		l__TweenService__1:Create(l__Sounds__20.CrumbleLoop, TweenInfo.new(10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
			Volume = 0
		}):Play();
		v24:StopSustained(6);
		l__TweenService__1:Create(v25.Sparks, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false, 0), {
			Rate = 0
		}):Play();
		l__TweenService__1:Create(v25.Appearance, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false, 0), {
			Rate = 0
		}):Play();
		l__TweenService__1:Create(v25, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false, 0), {
			Size = Vector3.new(0, 1, 0)
		}):Play();
		l__TweenService__1:Create(v25.OuterLightBeam, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false, 0), {
			Width0 = 0, 
			Width1 = 0
		}):Play();
		l__TweenService__1:Create(v25.InnerLightBeam, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false, 0), {
			Width0 = 0, 
			Width1 = 0
		}):Play();
		l__TweenService__1:Create(v25.PortalAmbiance, TweenInfo.new(5, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false, 0), {
			Volume = 0, 
			PlaybackSpeed = 0
		}):Play();
		v25.PortalClose1.PlayOnRemove = true;
		wait(5);
		v25:Destroy();
	end);
	wait(90);
	u3:Stop();
	l__TweenService__1:Create(v22, TweenInfo.new(30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
		TintColor = Color3.fromRGB(255, 255, 255), 
		Brightness = 0.1, 
		Saturation = 0, 
		Contrast = 0
	}):Play();
	l__TweenService__1:Create(v23, TweenInfo.new(30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0), {
		Intensity = -1
	}):Play();
	wait(30);
	v22:Destroy();
	v23:Destroy();
	l__Sounds__20:Destroy();
	v52:Disconnect();
end;

require(game.ReplicatedStorage.Remotes).OnClientEvent("FireSmite"):Connect(function(p19, p20, p21, p22)
	u7(p19, p20, p21, p22);
end);