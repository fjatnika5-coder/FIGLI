script.Parent.ApplyColors.OnServerEvent:Connect(function(Player, ColorList)
	for i, Info in ColorList do
		local Part = Info[1]
		local Color = Info[2]
		if Part:IsA("BasePart") or Part:IsA("PointLight") or Part:IsA("SpotLight") or Part:IsA("SurfaceLight") then
			Part.Color = Color
		elseif Part:IsA("Trail") or Part:IsA("Beam") or Part:IsA("ParticleEmitter") then
			Part.Color = ColorSequence.new(Color)
		end
	end
end)