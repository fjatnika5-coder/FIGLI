--[[
	PITCH CONFIGURATION MODULE - READY TO USE!
	
	Module ini sudah berisi semua Asset ID lagu kamu dengan pitch 0.49
	Tinggal copy-paste langsung ke Roblox ModuleScript!
]]--

local PitchConfig = {}

--[[
	DAFTAR PITCH PER LAGU
	Semua lagu di bawah ini akan play dengan pitch 0.49
]]--

PitchConfig.SongPitches = {
	-- === 6 LAGU AWAL ===
	[79872671810300] = 0.49,
	[127730199333288] = 0.49,
	[140468146864985] = 0.49,
	[84797376562618] = 0.49,
	[96398999152822] = 0.49,
	[140185699108790] = 0.49,

	-- === TAMBAHAN SEBELUMNYA ===
	[111823291431712] = 0.49,
	[118311070207309] = 0.49,
	[121721733739164] = 0.49,
	[86315784989890] = 0.49,
	[82553322379485] = 0.49,
	[80393453462656] = 0.49,
	[123779536235227] = 0.49,
	[125316257212178] = 0.49,
	[90765218612001] = 0.49,
	[133206323511234] = 0.49,
	[131432731624597] = 0.49,
	[81583939001124] = 0.49,
	[84417295761270] = 0.49,
	[81419006913916] = 0.49,
	[93768840505459] = 0.49,
	[109535431824907] = 0.49,
	[139506047047309] = 0.49,
	[134599995841790] = 0.49,
	[127820522153454] = 0.49,
	[125450078819372] = 0.49,
	[138976183520975] = 0.49,
	[133860609985441] = 0.49,
	[83878373884451] = 0.49,

	-- === TAMBAHAN BARU (YANG BARU KAMU KASIH) ===
	[134302281267792] = 0.49,
	[135682612031137] = 0.49,
	[140033636923803] = 0.49,
	[104098616210115] = 0.49,
	[124894062719632] = 0.49,
	[95628269200189]  = 0.49,
	[129357859822577] = 0.49,
	[116052709290109] = 0.49,
	[125947520733992] = 0.49,
	[90385012051221]  = 0.49,
	[88942012471065]  = 0.49,
	[103987950713283] = 0.49,
	[124614872016116] = 0.49,
	[87418117237531]  = 0.49,
	[139725018840983] = 0.49,
	[122750717205084] = 0.49,
	[93597161257352]  = 0.49,
	[73380411981454]  = 0.49,
	[133249630675694] = 0.49,
	[105874838891601] = 0.49,
	[116540477454603] = 0.49,
	[121565157360655] = 0.49,
	[93127402167532]  = 0.49,
	[97712463286355]  = 0.49,
	[102427368766687] = 0.49,
}



--[[
	DEFAULT PITCH
	Lagu yang tidak ada di daftar akan pakai pitch ini
]]--
PitchConfig.DefaultPitch = 1.0

--[[
	HELPER FUNCTIONS
]]--

-- Convert semitones to pitch ratio
function PitchConfig.SemitonesToPitch(semitones: number): number
	return 2 ^ (semitones / 12)
end

-- Convert pitch ratio to semitones
function PitchConfig.PitchToSemitones(pitch: number): number
	return 12 * math.log(pitch, 2)
end

-- Get pitch for specific Sound ID
function PitchConfig.GetPitch(soundId: number): number
	return PitchConfig.SongPitches[soundId] or PitchConfig.DefaultPitch
end

-- Check if Sound ID has custom pitch
function PitchConfig.HasCustomPitch(soundId: number): boolean
	return PitchConfig.SongPitches[soundId] ~= nil
end

-- Add or update pitch for Sound ID
function PitchConfig.SetPitch(soundId: number, pitch: number)
	PitchConfig.SongPitches[soundId] = pitch
end

-- Remove custom pitch (akan pakai default)
function PitchConfig.RemovePitch(soundId: number)
	PitchConfig.SongPitches[soundId] = nil
end

-- Get all configured Sound IDs
function PitchConfig.GetConfiguredSounds(): {number}
	local soundIds = {}
	for soundId in pairs(PitchConfig.SongPitches) do
		table.insert(soundIds, soundId)
	end
	return soundIds
end

-- Print pitch info for debugging
function PitchConfig.PrintPitchInfo(soundId: number)
	local pitch = PitchConfig.GetPitch(soundId)
	local semitones = PitchConfig.PitchToSemitones(pitch)
	local isCustom = PitchConfig.HasCustomPitch(soundId)


end

return PitchConfig