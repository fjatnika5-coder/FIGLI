-- || Made by: @a2x4440 || --

local RunConfig = {}

-- \\ SETTINGS \\

RunConfig.WalkSpeed = game.StarterPlayer.CharacterWalkSpeed
RunConfig.RunSpeed = 40 -- Speed while runninh
RunConfig.SprintSpeed = 55 -- Speed while sprinting

RunConfig.WalkFov = workspace.Camera.FieldOfView
RunConfig.RunFov = 80 -- Camera FieldOfView while running
RunConfig.SprintFov = 85 -- Camera FieldOfView while sprinting

RunConfig.CanRun = true -- If the player is able to run
RunConfig.CanSprint = false -- If the player is able to sprint

RunConfig.RunKey = Enum.KeyCode.LeftShift -- The key to press to run
RunConfig.TransitionSpeed = 0.5 -- Time it takes to go from walking to running
RunConfig.SprintTransitionSpeed = 3 -- Time it takes before you start sprinting

RunConfig.RunAnimationId = "rbxassetid://" -- EXAMPLE: "rbxassetid://1234567890"
RunConfig.SprintAnimationId = "rbxassetid://" -- EXAMPLE: "rbxassetid://1234567890"
RunConfig.ChangeAnimationProirity = true -- Turn this off if your animations are bugging

































-- !!WARNING: DO NOT CHANGE!! --
RunConfig.Walking = false
RunConfig.Running = false
RunConfig.Sprinting = false


return RunConfig
