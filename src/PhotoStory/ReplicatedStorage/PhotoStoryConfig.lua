--!nonstrict
-- ============================================================
-- PhotoStoryConfig
-- Semua konten cutscene diatur di sini. Edit tanpa menyentuh logic.
-- Ganti semua "rbxassetid://..._ID" dengan asset id milikmu.
-- Slot karakter "PlayerA" / "PlayerB" = dua player yang dipasangkan.
-- ============================================================

local Config = {}

-- ---------- Global ----------
Config.MusicSoundId = "rbxassetid://MUSIC_ID"
Config.Volume = 0.5

-- Portrait 9:16. Layar utama otomatis di-fit & di-letterbox.
Config.AspectRatio = 9 / 16

-- Low-end mode: kurangi efek berat (blur diganti fade, scale-pop dikurangi).
-- Bisa kamu set true secara manual, atau biarkan auto-deteksi di client.
Config.LowEndMode = false
Config.AutoLowEnd = true -- kalau true, client menebak low-end dari device

-- Nama Part pad pemicu di Workspace (dua player berdiri bareng untuk mulai).
Config.PadPartName = "PhotoStoryPad"

-- Default teks (bisa di-override per scene di Text = {...}).
Config.TextDefaults = {
	Font = Enum.Font.GothamBold,
	TextColor3 = Color3.fromRGB(255, 255, 255),
	StrokeColor3 = Color3.fromRGB(0, 0, 0),
	StrokeTransparency = 0.4,
	TypewriterSpeed = 28, -- grapheme per detik
}

-- Default transform karakter (dipakai kalau scene tidak menyebut).
Config.CharacterDefaults = {
	Scale = 1.0,
	Rotation = 0,
}

-- ---------- Scenes ----------
Config.Scenes = {
	{
		Duration = 3,
		Background = "rbxassetid://BG1_ID",
		TransitionIn = "DarkIntro",
		TransitionOut = "FadeWhite",

		Text = {
			Text = "memilih nama panggilan misalnya",
			Position = UDim2.fromScale(0.5, 0.62),
			Size = UDim2.fromScale(0.78, 0.1),
			Typewriter = true,
			Fade = true,
		},

		Characters = {
			Left = {
				User = "PlayerA",
				Position = UDim2.fromScale(0.36, 0.55),
				Scale = 1.0,
				Rotation = 10,
				AnimationId = "rbxassetid://ANIM_IDLE_ID",
			},
			Right = {
				User = "PlayerB",
				Position = UDim2.fromScale(0.64, 0.55),
				Scale = 1.0,
				Rotation = -10,
				AnimationId = "rbxassetid://ANIM_IDLE_ID",
			},
		},

		Images = {
			{
				Name = "Logo",
				Image = "rbxassetid://LOGO_ID",
				Position = UDim2.fromScale(0.12, 0.9),
				Size = UDim2.fromScale(0.16, 0.16),
				Transparency = 0,
			},
			{
				Name = "Sticker",
				Image = "rbxassetid://STICKER_ID",
				Position = UDim2.fromScale(0.82, 0.2),
				Size = UDim2.fromScale(0.14, 0.14),
				Transparency = 0,
			},
		},
	},

	{
		Duration = 3.5,
		Background = "rbxassetid://BG2_ID",
		TransitionIn = "FadeWhite",
		TransitionOut = "Zoom",

		Text = {
			Text = "lalu mereka berdua jadian",
			Position = UDim2.fromScale(0.5, 0.2),
			Size = UDim2.fromScale(0.8, 0.1),
			Typewriter = true,
			Fade = true,
		},

		Characters = {
			Left = {
				User = "PlayerA",
				Position = UDim2.fromScale(0.42, 0.58),
				Scale = 1.1,
				Rotation = 14,
				AnimationId = "rbxassetid://ANIM_WAVE_ID",
			},
			Right = {
				User = "PlayerB",
				Position = UDim2.fromScale(0.58, 0.58),
				Scale = 1.1,
				Rotation = -14,
				AnimationId = "rbxassetid://ANIM_WAVE_ID",
			},
		},

		Images = {
			{
				Name = "Heart",
				Image = "rbxassetid://HEART_ID",
				Position = UDim2.fromScale(0.5, 0.36),
				Size = UDim2.fromScale(0.2, 0.2),
				Transparency = 0,
			},
		},
	},

	{
		Duration = 3,
		Background = "rbxassetid://BG3_ID",
		TransitionIn = "Blur",
		TransitionOut = "Fade",

		Text = {
			Text = "tamat <3",
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.6, 0.12),
			Typewriter = false,
			Fade = true,
		},

		Characters = {
			Left = {
				User = "PlayerA",
				Position = UDim2.fromScale(0.5, 0.6),
				Scale = 1.2,
				Rotation = 0,
				AnimationId = "rbxassetid://ANIM_IDLE_ID",
			},
		},

		Images = {},
	},
}

return Config
