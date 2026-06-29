--!nonstrict
-- ============================================================
-- PhotoStoryConfig (versi 3D camera scene)
-- Avatar diambil OTOMATIS dari player yang injek pad (tidak ada UserId di sini).
-- Background = dunia Roblox (CameraPart/GirlPoint/BoyPoint di Workspace).
-- Ganti "rbxassetid://..._ID" dengan asset id milikmu. Placeholder di-skip.
-- ============================================================

local Config = {}

-- ---------- Global ----------
Config.MusicSoundId = "rbxassetid://MUSIC_ID"
Config.Volume = 0.5

Config.LowEndMode = false
Config.AutoLowEnd = true -- mobile -> hemat efek otomatis

-- Lokasi di Workspace.
Config.ScenesFolder = "PhotoStoryScenes" -- Workspace.PhotoStoryScenes
Config.PadsFolder = "PhotoPads" -- Workspace.PhotoPads
Config.GirlPadName = "GirlPad"
Config.BoyPadName = "BoyPad"

-- Vignette opsional: isi asset id (gambar bingkai gelap). Kosongkan = tanpa vignette.
Config.VignetteImage = "" -- mis. "rbxassetid://VIGNETTE_ID"

-- Default teks (override per scene).
Config.TextDefaults = {
	Font = Enum.Font.GothamBold,
	TextColor3 = Color3.fromRGB(255, 255, 255),
	StrokeColor3 = Color3.fromRGB(0, 0, 0),
	StrokeTransparency = 0.35,
	TypewriterSpeed = 28, -- grapheme / detik
	Position = UDim2.fromScale(0.5, 0.8),
	Size = UDim2.fromScale(0.82, 0.12),
}

-- ---------- Scenes ----------
-- CameraPart/GirlPoint/BoyPoint = NAMA child di Workspace.PhotoStoryScenes.<Name>.
Config.Scenes = {
	{
		Name = "Scene1",
		Duration = 4,
		CameraPart = "CameraPart",
		GirlPoint = "GirlPoint",
		BoyPoint = "BoyPoint",

		Camera = {
			FOV = 45,
			Shake = true,
			ShakeAmount = 0.08,
			SlowZoom = true,
			ZoomAmount = 2, -- dolly maju (stud) sepanjang scene
		},

		Animations = {
			Girl = "rbxassetid://ANIM_GIRL_ID",
			Boy = "rbxassetid://ANIM_BOY_ID",
		},

		Text = {
			Text = "isi text di sini",
			StartTime = 0.5,
			Typewriter = true,
			Fade = true,
			Bounce = true,
		},

		Vignette = true,
		TransitionIn = "FadeWhite",
		TransitionOut = "FlashWhite",
	},

	{
		Name = "Scene2",
		Duration = 4.5,
		CameraPart = "CameraPart",
		GirlPoint = "GirlPoint",
		BoyPoint = "BoyPoint",

		Camera = {
			FOV = 50,
			Shake = true,
			ShakeAmount = 0.05,
			SlowZoom = true,
			ZoomAmount = 3,
		},

		Animations = {
			Girl = "rbxassetid://ANIM_GIRL_ID",
			Boy = "rbxassetid://ANIM_BOY_ID",
		},

		Text = {
			Text = "lalu mereka jadian",
			StartTime = 0.6,
			Typewriter = true,
			Fade = true,
			Bounce = true,
		},

		Vignette = true,
		TransitionIn = "FadeBlack",
		TransitionOut = "Blur",
	},

	{
		Name = "Scene3",
		Duration = 4,
		CameraPart = "CameraPart",
		GirlPoint = "GirlPoint",
		BoyPoint = "BoyPoint",

		Camera = {
			FOV = 40,
			Shake = false,
			ShakeAmount = 0,
			SlowZoom = true,
			ZoomAmount = 2,
		},

		Animations = {
			Girl = "rbxassetid://ANIM_GIRL_ID",
			Boy = "rbxassetid://ANIM_BOY_ID",
		},

		Text = {
			Text = "tamat <3",
			StartTime = 0.4,
			Typewriter = false,
			Fade = true,
			Bounce = true,
		},

		Vignette = false,
		TransitionIn = "FadeBlack",
		TransitionOut = "FadeBlack",
	},
}

return Config
