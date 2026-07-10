--[[SERVICES]]--

--[[MODULES]]--

local SongInfo = require(script.Parent.SongInfo)

--[[CONSTANTS]]--

--[[GLOBALS]]--

local SongCollection = {}
SongCollection.__index = SongCollection

type SongInfo = SongInfo.SongInfo

export type SongCollection = {
	Name: string,
	Songs: {SongInfo},
}

--[[LOCAL FUNCTIONS]]--

--[[MODULAR FUNCTIONS]]--

function SongCollection.new(Name: string, Songs: {SongInfo})

	local newSongCollection = {}
	newSongCollection.Name = Name
	newSongCollection.Songs = Songs
	setmetatable(newSongCollection, SongCollection)

	return newSongCollection

end

function SongCollection:Shuffle()

	local newSongs = {}
	local availablePositions = {}

	for index in pairs(self.Songs) do

		table.insert(availablePositions, index)

	end

	for index, songInfo in pairs(self.Songs) do

		local newPositionIndex = math.random(1, #availablePositions)
		local newPosition = availablePositions[newPositionIndex]
		table.remove(availablePositions, newPositionIndex)
		newSongs[newPosition] = songInfo
		songInfo.Order = newPosition

	end

	for index, songInfo in pairs(newSongs) do

		self.Songs[index] = songInfo

	end

end

return SongCollection
