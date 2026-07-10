--[[TYPES]]--

export type SongInfo = {
	Title: string,
	AssetId: number,
	Order: number
}

--[[SERVICES]]--

--[[MODULES]]--

--[[CONSTANTS]]--

--[[GLOBALS]]--

local SongInfo = {}
SongInfo.__index = SongInfo

--[[LOCAL FUNCTIONS]]--

--[[MODULAR FUNCTIONS]]--

function SongInfo.new(Title: string, AssetId: number, Order: number): SongInfo
	
	local newSongInfo: SongInfo = {}
	newSongInfo.Title = Title
	newSongInfo.AssetId = AssetId
	newSongInfo.Order = Order
	setmetatable(newSongInfo, SongInfo)
	
	return newSongInfo
	
end

return SongInfo
