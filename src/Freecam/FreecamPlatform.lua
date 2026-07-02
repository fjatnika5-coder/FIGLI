--!nonstrict
-- FreecamPlatform
-- Helper deteksi platform yang jelas, jangan andalkan TouchEnabled mentah.
--   Desktop : keyboard + mouse tersedia, bukan ten-foot console (laptop touchscreen masuk sini).
--   Mobile  : touch-primary device, bukan console.
--   Console : ten-foot / gamepad-primary.

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local FreecamPlatform = {}

FreecamPlatform.Mode = {
	Desktop = "Desktop",
	Mobile = "Mobile",
	Console = "Console",
}

function FreecamPlatform.isConsole()
	-- Ten-foot UI = TV/console interface.
	if GuiService:IsTenFootInterface() then
		return true
	end

	-- Gamepad-primary: ada gamepad, tapi tidak ada keyboard/mouse/touch.
	if UserInputService.GamepadEnabled
		and not UserInputService.KeyboardEnabled
		and not UserInputService.MouseEnabled
		and not UserInputService.TouchEnabled
	then
		return true
	end

	return false
end

function FreecamPlatform.getMode()
	if FreecamPlatform.isConsole() then
		return FreecamPlatform.Mode.Console
	end

	-- Desktop diprioritaskan: kalau ada keyboard + mouse, anggap PC/laptop
	-- walaupun device juga punya touchscreen (laptop touch). Ini mencegah
	-- false-positive mobile pada laptop touchscreen.
	if UserInputService.KeyboardEnabled and UserInputService.MouseEnabled then
		return FreecamPlatform.Mode.Desktop
	end

	-- Touch-primary tanpa keyboard+mouse = mobile/tablet.
	if UserInputService.TouchEnabled then
		return FreecamPlatform.Mode.Mobile
	end

	-- Fallback aman.
	return FreecamPlatform.Mode.Desktop
end

-- Custom freecam runtime dipakai SEMUA platform (Desktop, Mobile, Console).
-- Native Roblox freecam hanya developer access, jadi bukan route untuk player.
function FreecamPlatform.shouldUseCustomRuntime()
	return true
end

-- Native Roblox freecam (Shift+P CoreScript) hanya fitur developer bawaan Roblox,
-- bukan route game untuk player biasa. Selalu false.
function FreecamPlatform.shouldUseNativeRobloxFreecam()
	return false
end

return FreecamPlatform
