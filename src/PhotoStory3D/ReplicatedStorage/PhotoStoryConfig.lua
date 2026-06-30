--!nonstrict
local Config = {}

-- ====== DATA LAMA (TIDAK DIUBAH) ======
Config.MusicSoundId = "rbxassetid://115154421177613"
Config.Volume = 0.5

Config.LowEndMode = false
Config.AutoLowEnd = true

Config.ScenesFolder = "PhotoStoryScenes"
Config.PadsFolder   = "PhotoPads"
Config.GirlPadName  = "GirlPad"
Config.BoyPadName   = "BoyPad"

Config.VignetteImage = ""

Config.TextDefaults = {
	Font               = Enum.Font.GothamBold,
	TextColor3         = Color3.fromRGB(255, 255, 255),
	StrokeColor3       = Color3.fromRGB(0, 0, 0),
	StrokeTransparency = 0.35,
	TypewriterSpeed    = 28,
	Position           = UDim2.fromScale(0.5, 0.8),
	Size               = UDim2.fromScale(0.82, 0.12),
}

-- Warna default lirik (cycled per phrase)
Config.DefaultWordColors = {
	Color3.fromRGB(255, 210, 230),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(190, 220, 255),
	Color3.fromRGB(255, 230, 170),
}

-- ============================================================
-- GAMBAR GLOBAL (muncul sepanjang cutscene). Image kosong = di-skip.
-- Tinggal isi Image = "rbxassetid://...." kalau mau pakai.
-- ============================================================
Config.GlobalImages = {
	-- { Name="Logo", Image="", Position=UDim2.fromScale(0.12,0.9),
	--   Size=UDim2.fromOffset(65,65), Animation="Float", ZIndex=31 },
}

-- ============================================================
-- STICKER / GAMBAR PER SCENE  ->  TINGGAL ISI Image asset id.
-- Key = NAMA SCENE (sama dengan Config.Scenes[].Name).
-- Image = "" -> di-skip diam-diam (tidak ada kotak/hijau, tidak error).
-- Target: "Girl"/"Boy" = nempel dekat karakter (WorldToViewportPoint + Offset).
--         "Screen"      = pakai Position.
-- Animation: "Pop" | "Float" | "Wiggle" | "Pulse" | "PopWiggle".
-- Size: pakai UDim2.fromOffset(px,px) (rapi) atau UDim2.fromScale(...).
-- Cara isi: cukup ganti Image = "" jadi Image = "rbxassetid://123456789".
-- ============================================================
Config.SceneImages = {
	Scene1 = {
		{ Name = "StickerLove1", Image = "", Target = "Girl",   Offset = Vector2.new( 55, -120),
		  Size = UDim2.fromOffset(55, 55), StartTime = 0.5, Lifetime = 2.0, Animation = "PopWiggle", ZIndex = 30 },
		{ Name = "LogoSmall",    Image = "", Target = "Screen", Position = UDim2.fromScale(0.12, 0.88),
		  Size = UDim2.fromOffset(65, 65), StartTime = 0.2, Lifetime = 4.0, Animation = "Float",     ZIndex = 31 },
	},
	Scene2 = {
		{ Name = "StickerBlueberry", Image = "", Target = "Boy", Offset = Vector2.new(-45, -110),
		  Size = UDim2.fromOffset(58, 58), StartTime = 0.4, Lifetime = 2.2, Animation = "Pop", ZIndex = 30 },
		{ Name = "StickerPastry",    Image = "", Target = "Girl", Offset = Vector2.new( 50, -115),
		  Size = UDim2.fromOffset(54, 54), StartTime = 1.0, Lifetime = 2.0, Animation = "Pulse", ZIndex = 30 },
	},
	Scene3 = {
		-- { Name="Heart", Image="", Target="Screen", Position=UDim2.fromScale(0.8,0.25),
		--   Size=UDim2.fromOffset(50,50), StartTime=0.4, Lifetime=1.8, Animation="Float", ZIndex=30 },
	},
	Scene4 = {
		-- belum ada sticker; tinggal tambah di sini kalau mau
	},
}

-- ============================================================
-- SCENES  (DATA LAMA dipertahankan: nama, durasi, animasi, transisi, text).
-- Text.Mode = "LyricPhrase" (lirik per-phrase, BERURUTAN, rapi). Backward compatible.
-- ============================================================
Config.Scenes = {
	{
		Name       = "Scene1",
		Duration   = 4.3,
		CameraPart = "CameraPart",
		GirlPoint  = "GirlPoint",
		BoyPoint   = "BoyPoint",
		Camera     = { FOV = 45, Shake = true, ShakeAmount = 0.08, SlowZoom = true, ZoomAmount = 2 },
		Animations = { Girl = "rbxassetid://94236640546781", Boy = "rbxassetid://97440045770691" },
		Text = {
			Text = "Memilih nama panggilan mesra",
			StartTime = 0.5,
			Mode = "LyricPhrase",
			Target = "Girl",
			WordsPerPhrase = 2,
			PhraseDelay = 0.42,
			PhraseLifetime = 1.25,
			MaxVisiblePhrases = 2,
			Offset = Vector2.new(0, -95),
			Spacing = 28,
			TextSize = 22,
			Wiggle = true,
			-- field lama tetap boleh ada (diabaikan saat LyricPhrase):
			Typewriter = true, Fade = true, Bounce = true,
		},
		Vignette       = true,
		TransitionIn   = "FadeWhite",
		TransitionOut  = "FlashWhite",
	},
	{
		Name       = "Scene2",
		Duration   = 3.6,
		CameraPart = "CameraPart",
		GirlPoint  = "GirlPoint",
		BoyPoint   = "BoyPoint",
		Camera     = { FOV = 50, Shake = true, ShakeAmount = 0.05, SlowZoom = true, ZoomAmount = 3 },
		Animations = { Girl = "rbxassetid://132802617433208", Boy = "rbxassetid://100552473518596" },
		Text = {
			Text = "kamu blueberry dan aku pastry",
			StartTime = 0.6,
			Mode = "LyricPhrase",
			Target = "AlternatePhrase", -- phrase1 dekat Girl, phrase2 dekat Boy, dst (rapi)
			WordsPerPhrase = 2,
			PhraseDelay = 0.42,
			PhraseLifetime = 1.2,
			MaxVisiblePhrases = 2,
			Offset = Vector2.new(0, -95),
			Spacing = 28,
			TextSize = 22,
			Wiggle = true,
			Typewriter = true, Fade = true, Bounce = true,
		},
		Vignette       = true,
		TransitionIn   = "FadeBlack",
		TransitionOut  = "Blur",
	},
	{
		Name       = "Scene3",
		Duration   = 2.7,
		CameraPart = "CameraPart",
		GirlPoint  = "GirlPoint",
		BoyPoint   = "BoyPoint",
		Camera     = { FOV = 40, Shake = false, ShakeAmount = 0, SlowZoom = true, ZoomAmount = 2 },
		Animations = { Girl = "rbxassetid://77338301055587", Boy = "rbxassetid://77338301055587" },
		Text = {
			Text = "nama depanmu nama belakangmu",
			StartTime = 0.4,
			Mode = "LyricPhrase",
			Target = "Center",
			WordsPerPhrase = 2,
			PhraseDelay = 0.4,
			PhraseLifetime = 1.1,
			MaxVisiblePhrases = 2,
			Offset = Vector2.new(0, -95),
			Spacing = 26,
			TextSize = 22,
			Wiggle = true,
			Typewriter = false, Fade = true, Bounce = true,
		},
		Vignette       = false,
		TransitionIn   = "FadeBlack",
		TransitionOut  = "FadeBlack",
	},
	{
		Name       = "Scene4",
		Duration   = 4.3,
		CameraPart = "CameraPart",
		GirlPoint  = "GirlPoint",
		BoyPoint   = "BoyPoint",
		Camera     = { FOV = 40, Shake = false, ShakeAmount = 0, SlowZoom = true, ZoomAmount = 2 },
		Animations = { Girl = "rbxassetid://77338301055587", Boy = "rbxassetid://77338301055587" },
		Text = {
			Text = "jadi nama toko roti",
			StartTime = 0.4,
			Mode = "LyricPhrase",
			Target = "Boy",
			WordsPerPhrase = 2,
			PhraseDelay = 0.44,
			PhraseLifetime = 1.3,
			MaxVisiblePhrases = 2,
			Offset = Vector2.new(0, -95),
			Spacing = 28,
			TextSize = 22,
			Wiggle = true,
			Typewriter = false, Fade = true, Bounce = true,
		},
		Vignette       = false,
		TransitionIn   = "FadeBlack",
		TransitionOut  = "FadeBlack",
	},
}

return Config
