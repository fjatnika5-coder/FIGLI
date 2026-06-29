--!nonstrict
local Config = {}

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
	Font              = Enum.Font.GothamBold,
	TextColor3        = Color3.fromRGB(255, 255, 255),
	StrokeColor3      = Color3.fromRGB(0, 0, 0),
	StrokeTransparency = 0.35,
	TypewriterSpeed   = 28,
	Position          = UDim2.fromScale(0.5, 0.8),
	Size              = UDim2.fromScale(0.82, 0.12),
}

-- ============================================================
-- GAMBAR OVERLAY (logo/sticker/dekorasi) — backward compatible.
-- GlobalImages = muncul di SEMUA scene.
-- Scene.Images = muncul per scene (Target, StartTime, Lifetime, Animation).
--
-- Target: "Girl" = dekat avatar cewe (WorldToViewportPoint)
--         "Boy"  = dekat avatar cowo
--         "Screen" / nil = pakai Position langsung
--
-- Animation: "Pop" | "Wiggle" | "Float" | "Pulse" | "PopWiggle"
-- Kalau Image = "" (kosong), stiker di-skip otomatis tanpa error.
--
-- Contoh isi kalau sudah punya asset id:
-- Config.GlobalImages = {
--     { Name="Logo", Image="rbxassetid://XXXXXXXX",
--       Position=UDim2.fromScale(0.12, 0.9), Size=UDim2.fromScale(0.13, 0.13),
--       Animation="Float", ZIndex=30 },
-- }
-- ============================================================
Config.GlobalImages = {}

-- ============================================================
-- WARNA DEFAULT PER KATA (dipakai Text.Colors kalau tidak di-set)
-- Tiap kata dapat warna berbeda (cycled).
-- ============================================================
Config.DefaultWordColors = {
	Color3.fromRGB(255, 190, 220),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(180, 220, 255),
	Color3.fromRGB(255, 230, 160),
}

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
			Text       = "Memilih nama panggilan mesra",
			StartTime  = 0.5,
			-- Mode PerWordNearCharacter (default baru) — per-kata dekat karakter
			Mode       = "PerWordNearCharacter",
			Target     = "Alternate",   -- kata bergantian Girl/Boy
			WordDelay  = 0.24,
			WordLifetime = 1.2,
			-- Isi Colors kalau mau warna custom, atau hapus baris ini pakai default
			-- Colors = { Color3.fromRGB(255, 180, 210), Color3.fromRGB(255,255,255) },
			-- Backward compat fields (diabaikan saat Mode=PerWordNearCharacter)
			Typewriter = true, Fade = true, Bounce = true,
		},
		Images = {
			-- Contoh stiker — isi Image dengan asset id kalau sudah ada:
			-- { Name="Heart1", Image="", Target="Girl", Offset=Vector2.new(60,-110),
			--   Size=UDim2.fromScale(0.08,0.08), StartTime=0.5, Lifetime=2.0, Animation="PopWiggle", ZIndex=31 },
			-- { Name="Star1",  Image="", Target="Boy",  Offset=Vector2.new(-50,-100),
			--   Size=UDim2.fromScale(0.07,0.07), StartTime=1.2, Lifetime=1.8, Animation="Pulse",    ZIndex=31 },
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
			Text       = "kamu blueberry dan aku pastry",
			StartTime  = 0.6,
			Mode       = "PerWordNearCharacter",
			Target     = "Alternate",
			WordDelay  = 0.2,
			WordLifetime = 1.1,
			Typewriter = true, Fade = true, Bounce = true,
		},
		Images = {
			-- { Name="Blueberry", Image="", Target="Girl", Offset=Vector2.new(55,-105),
			--   Size=UDim2.fromScale(0.09,0.09), StartTime=0.3, Lifetime=2.5, Animation="Pop",   ZIndex=31 },
			-- { Name="Pastry",    Image="", Target="Boy",  Offset=Vector2.new(-45,-95),
			--   Size=UDim2.fromScale(0.08,0.08), StartTime=0.9, Lifetime=2.0, Animation="Float", ZIndex=31 },
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
			Text       = "nama depanmu nama belakangmu",
			StartTime  = 0.4,
			Mode       = "PerWordNearCharacter",
			Target     = "Girl",
			WordDelay  = 0.26,
			WordLifetime = 1.0,
			Typewriter = false, Fade = true, Bounce = true,
		},
		Images     = {},
		Vignette   = false,
		TransitionIn  = "FadeBlack",
		TransitionOut = "FadeBlack",
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
			Text       = "jadi nama toko roti",
			StartTime  = 0.4,
			Mode       = "PerWordNearCharacter",
			Target     = "Boy",
			WordDelay  = 0.28,
			WordLifetime = 1.3,
			Typewriter = false, Fade = true, Bounce = true,
		},
		Images     = {},
		Vignette   = false,
		TransitionIn  = "FadeBlack",
		TransitionOut = "FadeBlack",
	},
}

return Config
