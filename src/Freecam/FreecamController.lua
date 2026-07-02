--!nonstrict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Packages = Shared.Packages
local Knit = require(Packages.Knit)
local Janitor = require(Packages.Janitor)

local FreecamResolver = require(script.Parent.Parent.Modules.Freecam.FreecamResolver)
local FreecamRuntime = require(script.Parent.Parent.Modules.Freecam.FreecamRuntime)
local Logger = require(script.Parent.Parent.Modules.Logger)

local Controller = Knit.CreateController({ Name = "FreecamController" })

local LocalPlayer = Players.LocalPlayer
local log = Logger.new("FreecamController", false)

function Controller:KnitStart()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui", 60)
	if not playerGui then
		log:error("PlayerGui not found")
		return
	end

	local ok, refsOrErr
	for _ = 1, 5 do
		ok, refsOrErr = FreecamResolver.resolve()
		if ok then
			break
		end
		task.wait(2)
	end

	if not ok then
		log:warn("FreecamResolver failed: " .. tostring(refsOrErr))
		return
	end

	-- Guard double-init: kalau KnitStart kepanggil ulang, bersihin runtime lama.
	if self._janitor then
		self._janitor:Destroy()
	end

	self._janitor = Janitor.new()
	self._runtime = FreecamRuntime.new(refsOrErr)
	self._runtime:Bind()
	self._janitor:Add(self._runtime, "Destroy")
end

function Controller:KnitStop()
	if self._janitor then
		self._janitor:Destroy()
		self._janitor = nil
	end
	self._runtime = nil
end

return Controller
