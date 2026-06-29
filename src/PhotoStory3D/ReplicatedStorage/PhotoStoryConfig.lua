--!nonstrict
local Config = {}

Config.MusicSoundId = "rbxassetid://115154421177613"
Config.Volume = 0.5

Config.LowEndMode = false
Config.AutoLowEnd = true

Config.ScenesFolder = "PhotoStoryScenes"
Config.PadsFolder = "PhotoPads"
Config.GirlPadName = "GirlPad"
Config.BoyPadName = "BoyPad"

Config.VignetteImage = ""

Config.TextDefaults = {
	Font = Enum.Font.GothamBold,
	TextColor3 = Color3.fromRGB(255, 255, 255),
	StrokeColor3 = Color3.fromRGB(0, 0, 0),
	StrokeTransparency = 0.35,
	TypewriterSpeed = 28,
	Position = UDim2.fromScale(0.5, 0.8),
	Size = UDim2.fromScale(0.82, 0.12),
}

-- ============================================================
-- GAMBAR OVERLAY (logo/sticker/dekorasi) — TAMBAHAN, backward compatible.
-- GlobalImages = muncul di SEMUA scene. Kosongkan {} kalau belum dipakai.
-- Animation: "Fade" | "Pop" | "Float" | "Wiggle" | "Pulse".
-- Asset kosong/placeholder otomatis di-skip (tanpa error/warn).
-- Contoh (hapus komentar & isi ID untuk pakai):
-- Config.GlobalImages = {
--     { Name = "Logo", Image = "rbxassetid://ISI_ID_LOGO",
--       Position = UDim2.fromScale(0.12, 0.9), Size = UDim2.fromScale(0.16, 0.16),
--       Rotation = 0, Transparency = 0, Animation = "Wiggle", ZIndex = 20 },
-- }
-- Per scene juga bisa (lihat field Images di Scene), contoh:
--     Images = {
--         { Name = "Sticker1", Image = "rbxassetid://ISI_ID_STICKER",
--           Position = UDim2.fromScale(0.82, 0.2), Size = UDim2.fromScale(0.12, 0.12),
--           Rotation = 0, Transparency = 0, Animation = "Pop", ZIndex = 21,
--           StartTime = 0.4, EndTime = 3.0 },
--     }
-- ============================================================
Config.GlobalImages = {}

Config.Scenes = {
	{
		Name = "Scene1",
		Duration = 4.3,
		CameraPart = "CameraPart",
		GirlPoint = "GirlPoint",
		BoyPoint = "BoyPoint",
		Camera = { FOV = 45, Shake = true, ShakeAmount = 0.08, SlowZoom = true, ZoomAmount = 2 },
		Animations = { Girl = "rbxassetid://94236640546781", Boy = "rbxassetid://97440045770691" },
		Text = { Text = "Memilih nama panggilan mesra", StartTime = 0.5, Typewriter = true, Fade = true, Bounce = true },
		Images = {},
		Vignette = true,
		TransitionIn = "FadeWhite",
		TransitionOut = "FlashWhite",
	},
	{
		Name = "Scene2",
		Duration = 3.6,
		CameraPart = "CameraPart",
		GirlPoint = "GirlPoint",
		BoyPoint = "BoyPoint",
		Camera = { FOV = 50, Shake = true, ShakeAmount = 0.05, SlowZoom = true, ZoomAmount = 3 },
		Animations = { Girl = "rbxassetid://132802617433208", Boy = "rbxassetid://100552473518596" },
		Text = { Text = "kamu blueberry dan aku pastry", StartTime = 0.6, Typewriter = true, Fade = true, Bounce = true },
		Images = {},
		Vignette = true,
		TransitionIn = "FadeBlack",
		TransitionOut = "Blur",
	},
	{
		Name = "Scene3",
		Duration = 2.7,
		CameraPart = "CameraPart",
		GirlPoint = "GirlPoint",
		BoyPoint = "BoyPoint",
		Camera = { FOV = 40, Shake = false, ShakeAmount = 0, SlowZoom = true, ZoomAmount = 2 },
		Animations = { Girl = "rbxassetid://77338301055587", Boy = "rbxassetid://77338301055587" },
		Text = { Text = "nama depanmu nama belakangmu", StartTime = 0.4, Typewriter = false, Fade = true, Bounce = true },
		Images = {},
		Vignette = false,
		TransitionIn = "FadeBlack",
		TransitionOut = "FadeBlack",
	},
	{
		Name = "Scene4",
		Duration = 4.3,
		CameraPart = "CameraPart",
		GirlPoint = "GirlPoint",
		BoyPoint = "BoyPoint",
		Camera = { FOV = 40, Shake = false, ShakeAmount = 0, SlowZoom = true, ZoomAmount = 2 },
		Animations = { Girl = "rbxassetid://77338301055587", Boy = "rbxassetid://77338301055587" },
		Text = { Text = "jadi nama toko roti", StartTime = 0.4, Typewriter = false, Fade = true, Bounce = true },
		Images = {},
		Vignette = false,
		TransitionIn = "FadeBlack",
		TransitionOut = "FadeBlack",
	},
}

return Config
