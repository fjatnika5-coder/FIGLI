-- Handles the playing, pausing, skipping, and looping of songs

--[[MODULES]]--

local Songs = require(script.Parent.Songs)
local SongInfo = require(script.Parent.Classes.SongInfo)
local SongCollection = require(script.Parent.Classes.SongCollection)
local PitchConfig = require(script.Parent.PitchConfig)  -- ← PITCH SYSTEM ADDED!

type SongInfo = SongInfo.SongInfo
type SongCollection = SongCollection.SongCollection

--[[GLOBALS]]--

local events = {
	SongChanged = Instance.new("BindableEvent")
}

local Player = {}
Player.SongChanged = events.SongChanged.Event
Player.IsPlaying = false
Player.Songs = SongCollection.new("", {})
Player.PlaylistName = ""
Player.ShuffleEnabled = false

local audioPlayer = script.Parent.MusicPlayer
local currentSongId = 1
local unshuffledSongCollection = nil
local shuffledSongCollection = nil

--[[LOCAL FUNCTIONS]]--

-- ========================================
-- PITCH SYSTEM FUNCTION - NEW!
-- ========================================
local function ApplyPitchToSound(sound: Sound)
	-- Extract Sound ID dari SoundId string
	local soundIdString = sound.SoundId
	local soundId = tonumber(string.match(soundIdString, "%d+"))

	if not soundId then
		warn("Could not extract Sound ID from:", soundIdString)
		return
	end

	-- Get pitch dari PitchConfig
	local pitch = PitchConfig.GetPitch(soundId)

	-- Apply pitch
	sound.PlaybackSpeed = pitch

	-- Debug info (bisa di-comment kalau ga perlu)
	if PitchConfig.HasCustomPitch(soundId) then
		print(string.format("🎵 Pitch %.2f applied to Sound ID %d", pitch, soundId))
	end
end
-- ========================================

local function setupAudioPlayer(SongId: number, TimePosition: number, OverrideShuffle: boolean)
	local song = (OverrideShuffle and unshuffledSongCollection.Songs or Player.Songs.Songs)[SongId]

	if audioPlayer.Playing then
		audioPlayer:Stop()
	end

	audioPlayer.SoundId = "rbxassetid://" .. song.AssetId
	ApplyPitchToSound(audioPlayer)  -- ← PITCH SYSTEM APPLIED!
	audioPlayer.TimePosition = TimePosition
end

local function skip(SongOffset: number)
	local newSongId = currentSongId + SongOffset

	if newSongId > #Player.Songs.Songs then
		newSongId -= #Player.Songs.Songs
		if Player.ShuffleEnabled then
			Player.Songs:Shuffle()
		end
	elseif newSongId < 1 then
		newSongId = #Player.Songs.Songs + newSongId
	end

	Player.Play(newSongId)
end

local function getSong(Order: number, OverrideShuffle: boolean?)
	local songList = OverrideShuffle and unshuffledSongCollection.Songs or Player.Songs.Songs

	for _, songInfo in pairs(songList) do
		if songInfo.Order == Order then
			return songInfo
		end
	end
end

local function cloneSongCollection(Collection: SongCollection)
	local newSongCollection = SongCollection.new(Collection.Name, {})

	for index, song in pairs(Collection.Songs) do
		local newSongInfo = SongInfo.new(song.Title, song.AssetId, song.Order)
		newSongCollection.Songs[index] = newSongInfo
	end

	return newSongCollection
end

--[[MODULAR FUNCTIONS]]--

function Player.ChangeSongs(NewSongs: SongCollection, PlaylistName: string)
	Player.PlaylistName = PlaylistName
	Player.Songs = NewSongs
	unshuffledSongCollection = cloneSongCollection(Player.Songs)
	shuffledSongCollection = cloneSongCollection(NewSongs)
	shuffledSongCollection:Shuffle()
	currentSongId = 1
end

function Player.GetCurrentSong(OverrideShuffle: boolean): SongInfo
	return getSong(currentSongId, OverrideShuffle)
end

function Player.SetLooped(NewLooped: boolean)
	audioPlayer.Looped = NewLooped
end

function Player.SetShuffle(NewShuffle: boolean)
	Player.ShuffleEnabled = NewShuffle

	if not Player.ShuffleEnabled then
		Player.Songs = unshuffledSongCollection
		return
	end

	shuffledSongCollection = cloneSongCollection(Player.Songs)
	shuffledSongCollection:Shuffle()
	Player.Songs = shuffledSongCollection
end

function Player.Play(SongId: number, TimePosition: number?, OverrideShuffle: boolean?)
	TimePosition = TimePosition or 0
	local song = getSong(SongId, OverrideShuffle)

	if not song then
		error(string.format("Song with Id %d not found.", SongId))
	end

	Player.IsPlaying = true
	setupAudioPlayer(SongId, TimePosition, OverrideShuffle)
	audioPlayer:Play()

	if currentSongId ~= SongId then
		events.SongChanged:Fire(currentSongId, OverrideShuffle)
	end

	currentSongId = SongId
end

function Player.Pause()
	Player.IsPlaying = false
	audioPlayer:Pause()
end

function Player.Next()
	skip(1)
end

function Player.Previous()
	skip(-1)
end

return Player