--!nonstrict
-- CameraDirector: ambil alih kamera ke Scriptable, arahkan ke CameraPart scene,
-- dengan shake lembut (math.noise, smooth) + slow dolly zoom.
-- Satu BindToRenderStep untuk seluruh cutscene, di-unbind via janitor.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CameraDirector = {}
CameraDirector.__index = CameraDirector

-- Nama bind HARUS unik per instance. Kalau fix ("PhotoStoryCamera"), dua runner yang
-- sempat overlap saling cabut bind -> kamera beku/hang + warning
-- "UnbindFromRenderStep removed different functions with same reference name 2 times".
local bindCounter = 0

function CameraDirector.new(janitor, lowEnd)
	local self = setmetatable({}, CameraDirector)
	bindCounter += 1
	self._renderName = "PhotoStoryCamera_" .. tostring(bindCounter)
	self._janitor = janitor
	self._lowEnd = lowEnd == true
	self._camera = Workspace.CurrentCamera
	self._base = CFrame.new()
	self._fov = 70
	self._shake = 0
	self._zoom = 0
	self._duration = 1
	self._startClock = os.clock()
	self._saved = nil
	self._bound = false
	return self
end

function CameraDirector:Begin()
	local cam = self._camera
	self._saved = {
		CameraType = cam.CameraType,
		CFrame = cam.CFrame,
		FieldOfView = cam.FieldOfView,
		CameraSubject = cam.CameraSubject,
	}
	cam.CameraType = Enum.CameraType.Scriptable

	self._janitor:Add(function()
		self:_restore()
	end)

	if not self._bound then
		self._bound = true
		RunService:BindToRenderStep(self._renderName, Enum.RenderPriority.Camera.Value + 1, function()
			self:_update()
		end)
		self._janitor:Add(function()
			if self._bound then
				self._bound = false
				pcall(function()
					RunService:UnbindFromRenderStep(self._renderName)
				end)
			end
		end)
	end
end

-- Set parameter scene baru (dipanggil tiap ganti scene).
function CameraDirector:SetScene(cameraPart, fov, shakeAmount, zoomAmount, duration)
	if cameraPart and cameraPart:IsA("BasePart") then
		self._base = cameraPart.CFrame
	end
	self._fov = fov or 70
	self._shake = shakeAmount or 0
	self._zoom = zoomAmount or 0
	self._duration = math.max(duration or 1, 0.1)
	self._startClock = os.clock()

	if self._lowEnd then
		self._shake *= 0.4
		self._zoom *= 0.6
	end
end

function CameraDirector:_update()
	local cam = self._camera
	local elapsed = os.clock() - self._startClock
	local p = math.clamp(elapsed / self._duration, 0, 1)

	-- Slow dolly maju (ease-out) sepanjang scene.
	local ease = 1 - (1 - p) * (1 - p)
	local pushed = self._base * CFrame.new(0, 0, -self._zoom * ease)

	-- Shake lembut via noise (mulus, frekuensi rendah, amplitudo kecil -> tidak pusing).
	if self._shake > 0 then
		local t = os.clock() * 1.1
		local amt = self._shake * 0.5
		local nx = math.noise(t, 0.0) * amt
		local ny = math.noise(0.0, t) * amt
		local nz = math.noise(t, t) * amt * 0.4
		pushed = pushed * CFrame.Angles(nx, ny, nz)
	end

	cam.CFrame = pushed
	cam.FieldOfView = self._fov
end

function CameraDirector:_restore()
	local cam = self._camera
	local saved = self._saved
	if not saved then
		return
	end
	self._saved = nil
	cam.CameraType = saved.CameraType or Enum.CameraType.Custom
	cam.CFrame = saved.CFrame
	cam.FieldOfView = saved.FieldOfView or 70
	cam.CameraSubject = saved.CameraSubject
end

return CameraDirector
