--!nonstrict
-- AssetPreloader: preload asset gambar scene sekarang + berikutnya saja.
-- Skip placeholder id ("..._ID") supaya tidak spam error.

local ContentProvider = game:GetService("ContentProvider")

local AssetPreloader = {}

-- Cache id yang sudah pernah dipreload (bounded oleh jumlah asset, tidak bocor).
local preloaded = {}

local function isRealAsset(id)
	return typeof(id) == "string" and string.match(id, "^rbxassetid://%d+$") ~= nil
end

-- Kumpulkan id gambar dari satu scene (background + images).
function AssetPreloader.gatherScene(scene)
	local ids = {}
	if scene == nil then
		return ids
	end
	if isRealAsset(scene.Background) then
		ids[#ids + 1] = scene.Background
	end
	for _, img in ipairs(scene.Images or {}) do
		if isRealAsset(img.Image) then
			ids[#ids + 1] = img.Image
		end
	end
	return ids
end

-- Preload daftar id (yang belum dicache). Aman dipanggil berkali-kali.
function AssetPreloader.preload(ids)
	local pending = {}
	for _, id in ipairs(ids) do
		if not preloaded[id] then
			preloaded[id] = true
			pending[#pending + 1] = id
		end
	end
	if #pending == 0 then
		return
	end
	pcall(function()
		ContentProvider:PreloadAsync(pending)
	end)
end

-- Preload scene index i dan i+1 sekaligus.
function AssetPreloader.preloadWindow(scenes, index)
	local ids = AssetPreloader.gatherScene(scenes[index])
	for _, id in ipairs(AssetPreloader.gatherScene(scenes[index + 1])) do
		ids[#ids + 1] = id
	end
	AssetPreloader.preload(ids)
end

return AssetPreloader
