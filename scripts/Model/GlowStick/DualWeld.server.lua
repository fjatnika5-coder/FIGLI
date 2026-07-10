script.Parent.Changed:Connect(function(c)
	if c == "Parent" and script.Parent.Parent:FindFirstChild("RightHand") ~= nil then
		local rightHand = script.Parent.Parent["RightHand"]
		local leftHand = script.Parent.Parent["LeftHand"]
		local handle = script.Parent.Handle
		local handle2 = script.Parent.Handle2

		-- Create the weld for the RightHand
		local weldRight = Instance.new("Weld")
		weldRight.Parent = rightHand
		weldRight.Part0 = rightHand
		weldRight.Part1 = handle
		weldRight.C0 = rightHand.CFrame:Inverse() * handle.CFrame

		-- Create the weld for the LeftHand
		local weldLeft = Instance.new("Weld")
		weldLeft.Parent = leftHand
		weldLeft.Part0 = leftHand
		weldLeft.Part1 = handle2
		weldLeft.C0 = weldRight.C0 -- Copy the C0 from the right hand weld

		-- Alternatively, if you want to set the left hand to the exact position of the right hand:
		-- weldLeft.C0 = rightHand.CFrame:Inverse() * leftHand.CFrame
	end
end)
