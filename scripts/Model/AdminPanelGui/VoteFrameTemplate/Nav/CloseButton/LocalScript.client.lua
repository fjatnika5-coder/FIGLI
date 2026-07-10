script.Parent.MouseButton1Click:Connect(function()
	script.Parent.Parent.Parent:TweenPosition(UDim2.fromScale(0.5, -1.5), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 1.5, true)
	task.wait(1.5)
	script.Parent.Parent.Parent.Visible = false
end)