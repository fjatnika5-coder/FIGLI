--[[
	PITCH CONFIGURATION MODULE
	Boombox Custom Compatible
	All listed songs use pitch 0.49
]]--

local PitchConfig = {}

--------------------------------------------------
-- SONG PITCH TABLE (RESET TOTAL)
--------------------------------------------------

PitchConfig.SongPitches = {
	[97712463286355]  = 0.49,
	[102427368766687] = 0.49,
	[132695387891353] = 0.49,
	[104283465401633] = 0.49,
	[95605271947656]  = 0.49,
	[74853239083280]  = 0.49,
	[93127402167532]  = 0.49,
	[131157996866122] = 0.49,
	[115575021156580] = 0.49,
	[121565157360655] = 0.49,
	[80070949326926]  = 0.49,
	[116540477454603] = 0.49,
	[105874838891601] = 0.49,
	[75557476281359]  = 0.49,
	[100671261310049] = 0.49,
	[133249630675694] = 0.49,
	[109888009574862] = 0.49,
	[116725826340287] = 0.49,
	[97751707383906]  = 0.49,
	[135184887217402] = 0.49,
	[73380411981454]  = 0.49,
	[112290183121808] = 0.49,
	[93597161257352]  = 0.49,
	[125608457886596] = 0.49,
	[134587617091459] = 0.49,
	[138934166560053] = 0.49,
	[100022146809392] = 0.49,
	[97615945660803]  = 0.49,
	[122750717205084] = 0.49,
}

--------------------------------------------------
-- DEFAULT PITCH
--------------------------------------------------

PitchConfig.DefaultPitch = 1.0

--------------------------------------------------
-- FUNCTIONS
--------------------------------------------------

function PitchConfig.GetPitch(soundId: number): number
	return PitchConfig.SongPitches[soundId] or PitchConfig.DefaultPitch
end

function PitchConfig.HasCustomPitch(soundId: number): boolean
	return PitchConfig.SongPitches[soundId] ~= nil
end

function PitchConfig.SetPitch(soundId: number, pitch: number)
	PitchConfig.SongPitches[soundId] = pitch
end

function PitchConfig.RemovePitch(soundId: number)
	PitchConfig.SongPitches[soundId] = nil
end

function PitchConfig.GetConfiguredSounds(): { number }
	local ids = {}
	for id in pairs(PitchConfig.SongPitches) do
		table.insert(ids, id)
	end
	return ids
end

--------------------------------------------------
-- DEBUG
--------------------------------------------------

function PitchConfig.PrintPitchInfo(soundId: number)
	local pitch = PitchConfig.GetPitch(soundId)
	print("=== PITCH INFO ===")
	print("Sound ID:", soundId)
	print("Pitch:", pitch)
	print("Custom:", PitchConfig.HasCustomPitch(soundId))
	print("==================")
end

--------------------------------------------------

return PitchConfig
