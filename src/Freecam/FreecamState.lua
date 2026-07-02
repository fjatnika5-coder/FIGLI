--!nonstrict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local FreecamState = {}

function FreecamState.getControls()
	local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
	if not playerScripts then
		return nil
	end

	local playerModuleScript = playerScripts:FindFirstChild("PlayerModule")
	if not playerModuleScript then
		return nil
	end

	local ok, playerModule = pcall(require, playerModuleScript)
	if not ok or not playerModule or type(playerModule.GetControls) ~= "function" then
		return nil
	end

	local okControls, controls = pcall(function()
		return playerModule:GetControls()
	end)

	return okControls and controls or nil
end

function FreecamState.save(runtime, camera)
	if not camera then
		return nil
	end

	return {
		CameraType = camera.CameraType,
		CameraSubject = camera.CameraSubject,
		CFrame = camera.CFrame,
		Focus = camera.Focus,
		FieldOfView = camera.FieldOfView,
		MouseBehavior = UserInputService.MouseBehavior,
		MouseIconEnabled = UserInputService.MouseIconEnabled,
		MobileGuiStates = {},
		MobileScreenGuiStates = {},
	}
end

function FreecamState.restore(runtime, camera, saved, restoreMobileGui)
	if not (camera and saved) then
		return
	end

	camera.CameraType = saved.CameraType or Enum.CameraType.Custom
	camera.CFrame = saved.CFrame or camera.CFrame
	camera.Focus = saved.Focus or camera.Focus
	camera.FieldOfView = saved.FieldOfView or camera.FieldOfView

	local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	camera.CameraSubject = humanoid or saved.CameraSubject

	UserInputService.MouseBehavior = saved.MouseBehavior or Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = saved.MouseIconEnabled ~= false

	restoreMobileGui(runtime, saved)
end

return FreecamState
