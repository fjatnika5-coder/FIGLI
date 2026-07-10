local module = {

	Permissions = {

		NavSeePermission = {
			NavPermission = {1,2,3,4,5, 6, 7}, -- Owner (Anda) dan admin lain bisa lihat semua navigasi
			GuiPermission = {1,2,3,4,5, 6, 7},
			CommandBarPermission = {1,2,3,4,5, 6, 7},
			LogsPermission = {1,2,3,4,5, 6, 7},
		},

		GroupPermission = {

			[33106532] = {

				[255] = {3,4,5,6,7},
				[2] = {1,2,3,4,5},
				[1] = {1,2,3},

			},

		},

		TeamPermission = {

			["Civilian"] = {1,2,3,4},
			["Police"] = {1,2,3,4,5,6},

		},
		
		GamepassPermission = {

			[23423424234] = {1,2,3,4,5,6},

		},

		IDPermission = {

			-- OWNER (ANDA) - LEVEL TERTINGGI
			[8918465521] = {1,2,3,4,5,6,7,8,9,10}, 
			[8934677203] = {1,2,3,4,5,6,7,8,9,10},
			
			-- ADMINS (LEVEL 5) 
			[8353298976] = {1,2,3,4,5}, 
			[9061204565] = {1,2,3,4,5}, 
			[9189505866] = {1,2,3,4,5}, 
			[8718652694] = {1,2,3,4,5}, 
			[8729747762] = {1,2,3,4,5},
			[7886989582] = {1,2,3,4,5},
			
			
			[-1] = {1,2,3,4,5,6,7}, -- Owner Server (ID default)
			[-2] = {1,2,3,4,5,6,7}, -- Owner Group (ID default)

		},

	},

	Messages = {
		WelcomeText = "Welcome @$playername",
		SelectedText = "Selected @$playername",
		UserID = "User ID: $userid",
		ServerClosed = "The server has been shut down.",
		ServerCloseWarning = "The server is being shut down by the administrator.",
		LockdownKick = "A lockdown has been activated on this server and people without a whitelist cannot enter.",
		LockedKick = "This server is locked. You cannot join.",
	},

	Localization = {
		Self = "me",
		All = "all",
		Other = "other",
	},

	LogPermission = {1,2,3,4,5,6,7},
	PunishLogPermission = {1,2,3,4,5,6,7},
	PostMessagePermission = {1,2,3,4,5,6,7},
	GlobalPostMessagePermission = {1,2,3,4,5,6,7},

	ToolList = {

		["Banana Peel"] = {
			ToolName = "Banana Peel",
			Permission = {1,2,3,4},
		},

		["Baseball Bat"] = {
			ToolName = "Baseball Bat",
			Permission = {1,2,3,4},
		},

		["Bloxy Cola"] = {
			ToolName = "Bloxy Cola",
			Permission = {1,2,3,4},
		},

		["Body Swap Potion"] = {
			ToolName = "Body Swap Potion",
			Permission = {1,2,3,4},
		},

		["Bombo's Survival Knife"] = {
			ToolName = "Bombo's Survival Knife",
			Permission = {1,2,3,4},
		},

		["BoomBox"] = {
			ToolName = "BoomBox",
			Permission = {1,2,3,4},
		},

		["Cake"] = {
			ToolName = "Cake",
			Permission = {1,2,3,4},
		},

		["Cheezburger"] = {
			ToolName = "Cheezburger",
			Permission = {1,2,3,4},
		},

		["Deluxe Rainbow Magic Carpet"] = {
			ToolName = "Deluxe Rainbow Magic Carpet",
			Permission = {1,2,3,4},
		},

		["F3X Btools"] = {
			ToolName = "F3X Btools",
			Permission = {1,2,3,4},
		},

		["FLY Tool"] = {
			ToolName = "FLY Tool",
			Permission = {1,2,3,4},
		},

		["Fuse Bomb"] = {
			ToolName = "Fuse Bomb",
			Permission = {1,2,3,4},
		},

		["Golden Steampunk Gloves"] = {
			ToolName = "Golden Steampunk Gloves",
			Permission = {1,2,3,4},
		},

		["Gravity Coil"] = {
			ToolName = "Gravity Coil",
			Permission = {1,2,3,4},
		},

		["Healing Potion"] = {
			ToolName = "Healing Potion",
			Permission = {1,2,3,4},
		},

		["Katana"] = {
			ToolName = "Katana",
			Permission = {1,2,3,4},
		},

		["Noclip"] = {
			ToolName = "Noclip",
			Permission = {1,2,3,4},
		},

		["Rainbow Magic Carpet"] = {
			ToolName = "Rainbow Magic Carpet",
			Permission = {1,2,3,4},
		},

		["Red Hyperlaser Gun"] = {
			ToolName = "Red Hyperlaser Gun",
			Permission = {1,2,3,4},
		},

		["Ronin Katana"] = {
			ToolName = "Ronin Katana",
			Permission = {1,2,3,4},
		},

		["Silver Ninja Star of the Brilliant Light"] = {
			ToolName = "Silver Ninja Star",
			Permission = {1,2,3,4},
		},

		["Space Sandwich"] = {
			ToolName = "Space Sandwich",
			Permission = {1,2,3,4},
		},

		["Speed Coil"] = {
			ToolName = "Speed Coil",
			Permission = {1,2,3,4},
		},

		["Spray Paint"] = {
			ToolName = "Spray Paint",
			Permission = {1,2,3,4},
		},

		["Sword"] = {
			ToolName = "Sword",
			Permission = {1,2,3,4},
		},

		["Teddy Bloxpin"] = {
			ToolName = "Teddy Bloxpin",
			Permission = {1,2,3,4},
		},

		["Witches Brew"] = {
			ToolName = "Witches Brew",
			Permission = {1,2,3,4},
		},
	},

	SkyboxList = {

		["NormalSky"] = {
			SkyboxName = "Normal Skybox",
			Permission = {1,2,3,4},
		},

		["BlueSky"] = {
			SkyboxName = "Blue Skybox",
			Permission = {1,2,3,4},
		},

		["ForestSky"] = {
			SkyboxName = "Forest Skybox",
			Permission = {1,2,3,4},
		},

		["RealisticSky"] = {
			SkyboxName = "Realistic Skybox",
			Permission = {1,2,3,4},
		},

		["DarkRedSky"] = {
			SkyboxName = "Dark Red Skybox",
			Permission = {1,2,3,4},
		},

		["AnimeSky"] = {
			SkyboxName = "Anime Island Skybox",
			Permission = {1,2,3,4},
		},

		["MountainsSkybox"] = {
			SkyboxName = "Mountains Skybox",
			Permission = {1,2,3,4},
		},

	},

	HatList = {

		["BCHardHat"] = {
			HatName = "Builder Hat",
			Permission = {1,2,3,4},
		},

		["Chef Hat"] = {
			HatName = "Chef Hat",
			Permission = {1,2,3,4},
		},

		["Cowboy Hat"] = {
			HatName = "Cowboy Hat",
			Permission = {1,2,3,4},
		},

		["DogeAccessory"] = {
			HatName = "Doge Head",
			Permission = {1,2,3,4},
		},

		["Green Top Hat"] = {
			HatName = "Green Top Hat",
			Permission = {1,2,3,4},
		},

		["Police hat"] = {
			HatName = "Police Hat",
			Permission = {1,2,3,4},
		},

		["Pumpkin Hat"] = {
			HatName = "Pumpkin Hat",
			Permission = {1,2,3,4},
		},

	},

	CommandList = {

		[1] = {
			CommandName = "fly",
			CommandText = "fly <player> <speed>",
			CommandDescription = "Allows you to fly the selected player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[2] = {
			CommandName = "unfly",
			CommandText = "unfly <player>",
			CommandDescription = "Allows you to unfly the selected player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[3] = {
			CommandName = "jail",
			CommandText = "jail [player] [time]-(10s/10m/10h/10d)",
			CommandDescription = "Creates a local prison. No params = self unlimited, <player> = target unlimited, <player> <time> = target with duration.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[4] = {
			CommandName = "sendjail",
			CommandText = "sendjail [player] [time]-(10s/10m/10h/10d)",
			CommandDescription = "Sends to global prison. No params = self unlimited, <player> = target unlimited, <player> <time> = target with duration. Persists through respawn.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[5] = {
			CommandName = "unjail",
			CommandText = "unjail [player]",
			CommandDescription = "Releases player from both local and global prison. No params = unjail self, <player> = unjail target.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[6] = {
			CommandName = "kill",
			CommandText = "kill <player>",
			CommandDescription = "Kills the player instantly.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[7] = {
			CommandName = "clearinventory",
			CommandText = "clearinventory <player>",
			CommandDescription = "Wipes all items from the player's backpack and hands.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[8] = {
			CommandName = "highlight",
			CommandText = "highlight <player> <outline color>-(hex) <fill color>-(hex) <outline transparency> <fill transparency>",
			CommandDescription = "Adds a highlight to the player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[9] = {
			CommandName = "unhighlight",
			CommandText = "unhighlight <player>",
			CommandDescription = "Removes highlights from the player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[10] = {
			CommandName = "refresh",
			CommandText = "refresh <player>",
			CommandDescription = "Refreshes the player's character.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[11] = {

			CommandName = "walkspeed",
			CommandText = "walkspeed <player> <speed>",
			CommandDescription = "Set the player's speed.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[12] = {
			CommandName = "jumpspeed",
			CommandText = "jumpspeed <player> <speed>",
			CommandDescription = "Set the player's jump power.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[13] = {
			CommandName = "shirt",
			CommandText = "shirt <player> <shirt id>",
			CommandDescription = "Changes the player's shirt.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[14] = {
			CommandName = "pants",
			CommandText = "pants <player> <pants id>",
			CommandDescription = "Changes the player's pants.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[15] = {
			CommandName = "face",
			CommandText = "face <player> <face id>",
			CommandDescription = "Changes the player's face.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[16] = {
			CommandName = "teleport",
			CommandText = "teleport <player>",
			CommandDescription = "Allows you to teleport to the player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[17] = {
			CommandName = "bring",
			CommandText = "bring <player> <player2>",
			CommandDescription = "Allows you to teleport the player to player2 location.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[18] = {
			CommandName = "tpplayer",
			CommandText = "tpplayer <player 1> <player 2>",
			CommandDescription = "Allows teleporting a player to another player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[19] = {
			CommandName = "bighead",
			CommandText = "bighead <player> <size>",
			CommandDescription = "It makes the player's head bigger.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[20] = {
			CommandName = "normalhead",
			CommandText = "normalhead <player>",
			CommandDescription = "Restores the player's head to normal.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[21] = {
			CommandName = "smallhead",
			CommandText = "smallhead <player> <size>",
			CommandDescription = "It makes the player's head smaller.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[22] = {
			CommandName = "smoke",
			CommandText = "smoke <player>",
			CommandDescription = "Adds a smoke effect to the player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[23] = {
			CommandName = "unsmoke",
			CommandText = "unsmoke <player>",
			CommandDescription = "Removes smoke effects from the player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[24] = {
			CommandName = "fire",
			CommandText = "fire <player>",
			CommandDescription = "Adds a fire effect to the player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[25] = {
			CommandName = "unfire",
			CommandText = "unfire <player>",
			CommandDescription = "Removes fire effects from the player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[26] = {
			CommandName = "r15",
			CommandText = "r15 <player>",
			CommandDescription = "Makes the player's character r15.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[27] = {
			CommandName = "r6",
			CommandText = "r6 <player>",
			CommandDescription = "Makes the player's character r6.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[28] = {
			CommandName = "sit",
			CommandText = "sit <player>",
			CommandDescription = "Makes the player sit.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[29] = {
			CommandName = "jump",
			CommandText = "jump <player>",
			CommandDescription = "Makes the player jump.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[30] = {
			CommandName = "clone",
			CommandText = "clone <player>",
			CommandDescription = "Allows you to copy a player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[31] = {
			CommandName = "damage",
			CommandText = "damage <player> <amount>",
			CommandDescription = "Damages the player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[32] = {
			CommandName = "heal",
			CommandText = "heal <player> <amount>",
			CommandDescription = "Heals the player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[33] = {
			CommandName = "sethealth",
			CommandText = "sethealth <player> <amount>",
			CommandDescription = "Edits the player's health.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[34] = {
			CommandName = "size",
			CommandText = "size <player> <amount>",
			CommandDescription = "Edit the size of the player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[35] = {
			CommandName = "changename",
			CommandText = "changename <player> <name>",
			CommandDescription = "Changes the player's name.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[36] = {
			CommandName = "hidename",
			CommandText = "hidename <player>",
			CommandDescription = "Hides the player's name.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[37] = {
			CommandName = "showname",
			CommandText = "showname <player>",
			CommandDescription = "Shows the player's name.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[38] = {
			CommandName = "forcefield",
			CommandText = "forcefield <player>",
			CommandDescription = "Gives the player forcefield.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[39] = {
			CommandName = "unforcefield",
			CommandText = "unforcefield <player>",
			CommandDescription = "Removes the player forcefield.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[40] = {
			CommandName = "spin",
			CommandText = "spin <player> <speed>",
			CommandDescription = "Spins the player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[41] = {
			CommandName = "unspin",
			CommandText = "unspin <player>",
			CommandDescription = "Stops spinning the player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[42] = {
			CommandName = "sword",
			CommandText = "sword <player>",
			CommandDescription = "Gives the player a sword.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[43] = {
			CommandName = "invisible",
			CommandText = "invisible <player>",
			CommandDescription = "Makes the player invisible.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[44] = {
			CommandName = "visible",
			CommandText = "visible <player>",
			CommandDescription = "Makes the player visible.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[45] = {
			CommandName = "skybox",
			CommandText = "skybox",
			CommandDescription = "It lets you change the game's skybox.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[46] = {
			CommandName = "explosion",
			CommandText = "explosion <player> <force>",
			CommandDescription = "Creates an explosion on the player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[47] = {
			CommandName = "setteam",
			CommandText = "setteam <player> <team name>",
			CommandDescription = "It is used to change the player's team.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[48] = {
			CommandName = "setteam",
			CommandText = "setteam <player> <team name>",
			CommandDescription = "It is used to change the player's team.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[49] = {
			CommandName = "material",
			CommandText = "material <player> <material>",
			CommandDescription = "Changes the skin material of the player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[50] = {
			CommandName = "btools",
			CommandText = "btools <player>",
			CommandDescription = "Gives the player the F3X Btools Tool.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[51] = {
			CommandName = "fov",
			CommandText = "fov <player> <fov>",
			CommandDescription = "Changes the player's view fov.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[52] = {
			CommandName = "god",
			CommandText = "god <player>",
			CommandDescription = "Makes the player god.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[53] = {
			CommandName = "ungod",
			CommandText = "ungod <player>",
			CommandDescription = "Makes the player ungod.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[54] = {
			CommandName = "time",
			CommandText = "time <time>",
			CommandDescription = "Changes the game time.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[55] = {
			CommandName = "closeserver",
			CommandText = "closeserver",
			CommandDescription = "Shuts down the server.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[56] = {
			CommandName = "sound",
			CommandText = "sound <sound id>",
			CommandDescription = "Plays sound that all players can hear.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[57] = {
			CommandName = "stopsound",
			CommandText = "stopsound <sound id>",
			CommandDescription = "Deletes a sound that plays for all players.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[58] = {
			CommandName = "stopallsounds",
			CommandText = "stopallsounds",
			CommandDescription = "Deletes all active sounds.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[59] = {
			CommandName = "viewinventory",
			CommandText = "viewinventory <player>",
			CommandDescription = "Checks the player's inventory.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[60] = {
			CommandName = "viewhats",
			CommandText = "viewhats <player>",
			CommandDescription = "Checks the player's hats.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[61] = {
			CommandName = "lockdown",
			CommandText = "lockdown",
			CommandDescription = "Kick those who are not on the whitelist on the server.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[62] = {
			CommandName = "addlockdown",
			CommandText = "addlockdown <player>",
			CommandDescription = "Adds the player to lockdown whitelist.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[63] = {
			CommandName = "removelockdown",
			CommandText = "removelockdown <player>",
			CommandDescription = "Removes the player from the lockdown whitelist.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[64] = {
			CommandName = "createserver",
			CommandText = "createserver",
			CommandDescription = "Creates a new server and sends you to it.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[65] = {
			CommandName = "servermessage",
			CommandText = "servermessage",
			CommandDescription = "Sends messages to players on the server.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[66] = {
			CommandName = "globalservermessage",
			CommandText = "globalservermessage",
			CommandDescription = "Sends messages to players on the all servers.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[67] = {
			CommandName = "privatemessage",
			CommandText = "privatemessage <player>",
			CommandDescription = "Sends a message to a player on the server.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[68] = {
			CommandName = "chatmessage",
			CommandText = "chatmessage",
			CommandDescription = "Sends a message to the game chat.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[69] = {
			CommandName = "nuke",
			CommandText = "nuke",
			CommandDescription = "Creates a nuclear bomb (Destroys the entire server)",
			CommandPermission = {10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[70] = {
			CommandName = "ping",
			CommandText = "ping <player>",
			CommandDescription = "Shows the player's ping.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[71] = {
			CommandName = "radio",
			CommandText = "radio <player>",
			CommandDescription = "Gives the player a radio.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[72] = {
			CommandName = "gold",
			CommandText = "gold <player>",
			CommandDescription = "Turns the player into gold.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[73] = {
			CommandName = "neon",
			CommandText = "neon <player>",
			CommandDescription = "Turns the player into neon.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[74] = {
			CommandName = "ghost",
			CommandText = "ghost <player>",
			CommandDescription = "Turns the player into ghost.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[75] = {
			CommandName = "glass",
			CommandText = "glass <player>",
			CommandDescription = "Turns the player into glass.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[76] = {
			CommandName = "ice",
			CommandText = "ice <player>",
			CommandDescription = "Turns the player into ice.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[77] = {
			CommandName = "sparkles",
			CommandText = "sparkles <player>",
			CommandDescription = "Adds a sparkles effect to the player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[78] = {
			CommandName = "unsparkles",
			CommandText = "unsparkles <player>",
			CommandDescription = "Removes sparkles effects from the player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[79] = {
			CommandName = "hideguis",
			CommandText = "hideguis <player>",
			CommandDescription = "Hides the player's gui.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[80] = {
			CommandName = "showguis",
			CommandText = "showguis <player>",
			CommandDescription = "Shows the player's gui.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[81] = {
			CommandName = "warp",
			CommandText = "warp <player>",
			CommandDescription = "You teleport to a warp.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[82] = {
			CommandName = "setwarp",
			CommandText = "setwarp <player>",
			CommandDescription = "Create a warp.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[83] = {
			CommandName = "delwarp",
			CommandText = "delwarp <player>",
			CommandDescription = "Delete a existing warp.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[84] = {
			CommandName = "freeze",
			CommandText = "freeze <player>",
			CommandDescription = "Freezes the player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[85] = {
			CommandName = "unfreeze",
			CommandText = "unfreeze <player>",
			CommandDescription = "Unfreeze a frozen player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[86] = {
			CommandName = "giant",
			CommandText = "giant <player>",
			CommandDescription = "Makes the player a giant.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[87] = {
			CommandName = "height",
			CommandText = "height <player> <size>",
			CommandDescription = "Increases the height of the player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[89] = {
			CommandName = "width",
			CommandText = "width <player> <size>",
			CommandDescription = "Increases the width of the player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[90] = {
			CommandName = "fart",
			CommandText = "fart <player>",
			CommandDescription = "Makes the player fart.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[91] = {
			CommandName = "fat",
			CommandText = "fat <player>",
			CommandDescription = "Makes the player overweight.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[92] = {
			CommandName = "noclip",
			CommandText = "noclip <player> <speed>",
			CommandDescription = "Player's noclip mode turns activated.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[93] = {
			CommandName = "unnoclip",
			CommandText = "unnoclip <player> <speed>",
			CommandDescription = "Player's noclip mode will turn off.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[94] = {
			CommandName = "dwarf",
			CommandText = "dwarf <player>",
			CommandDescription = "Shrinks the player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[95] = {
			CommandName = "thin",
			CommandText = "thin <player>",
			CommandDescription = "Makes the player as weak as a stick.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[96] = {
			CommandName = "sellgamepass",
			CommandText = "sellgamepass <player> <id>",
			CommandDescription = "Sends gamepass sales screen to the player.",
			CommandPermission = {10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[97] = {
			CommandName = "sellproduct",
			CommandText = "sellproduct <player> <id>",
			CommandDescription = "Sends a product sales screen to the player.",
			CommandPermission = {10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[98] = {
			CommandName = "sellasset",
			CommandText = "sellasset <player> <id>",
			CommandDescription = "Sends asset sale screen to the player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[99] = {
			CommandName = "createteam",
			CommandText = "createteam <team name>-(_ For Space) <team color>-(hex) <auto assignable>-(true/false)",
			CommandDescription = "Allows you to create a team.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[100] = {
			CommandName = "removeteam",
			CommandText = "removeteam <team name>-(_ For Space)",
			CommandDescription = "Allows you to delete a team.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[101] = {
			CommandName = "viewtools",
			CommandText = "viewtools <player>",
			CommandDescription = "You can give tools to the player or grab their tools.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[102] = {
			CommandName = "view",
			CommandText = "view <player>",
			CommandDescription = "You can watch the player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[103] = {
			CommandName = "unview",
			CommandText = "unview <player>",
			CommandDescription = "To stop watching the player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[104] = {
			CommandName = "follow",
			CommandText = "follow <player>",
			CommandDescription = "Allows you to teleport to a player's server in the same game.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[105] = {
			CommandName = "blur",
			CommandText = "blur <player> <number>",
			CommandDescription = "Gives the player a blurred effect.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[106] = {
			CommandName = "savemap",
			CommandText = "savemap",
			CommandDescription = "Backs up the game map.",
			CommandPermission = {10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[107] = {
			CommandName = "loadmap",
			CommandText = "loadmap",
			CommandDescription = "Loads the backed up map.",
			CommandPermission = {10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[108] = {
			CommandName = "tempban",
			CommandText = "tempban <player> <time>-(y/M/d/h/m/s) <reason>-(_ For Space)-(Optional)",
			CommandDescription = "Temporarily bans the specified player for a given time.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[109] = {
			CommandName = "tempmute",
			CommandText = "tempmute <player> <time>-(y/M/d/h/m/s) <reason>-(_ For Space)-(Optional)",
			CommandDescription = "Temporarily mutes the specified player for a given time.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[110] = {
			CommandName = "unmute",
			CommandText = "unmute <player>",
			CommandDescription = "Unmutes the specified player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[111] = {
			CommandName = "unban",
			CommandText = "unban <player>",
			CommandDescription = "Unbans the specified player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[112] = {
			CommandName = "mute",
			CommandText = "mute <player> <reason>-(_ For Space)-(Optional)",
			CommandDescription = "Mutes the specified player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[113] = {
			CommandName = "ban",
			CommandText = "ban <player> <reason>-(_ For Space)-(Optional)",
			CommandDescription = "Bans the specified player from the game.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[114] = {
			CommandName = "kick",
			CommandText = "kick <player> <reason>-(_ For Space)-(Optional)",
			CommandDescription = "Kicks the specified player from the game.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[115] = {
			CommandName = "kickall",
			CommandText = "kickall <reason>-(_ For Space)-(Optional)",
			CommandDescription = "Kicks all players from the game.",
			CommandPermission = {10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[116] = {
			CommandName = "editdata",
			CommandText = "editdata <player>",
			CommandDescription = "It allows you to edit the player's leaderstats data.",
			CommandPermission = {10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[117] = {
			CommandName = "vote",
			CommandText = "vote",
			CommandDescription = "Opens a vote launch menu.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {},
			CommandLog = true,
			WebhookLog = false,
		},

		[118] = {
			CommandName = "flytool",
			CommandText = "flytool <player> <speed>",
			CommandDescription = "Allows you to fly the selected player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[119] = {
			CommandName = "unflytool",
			CommandText = "unflytool <player>",
			CommandDescription = "Allows you to unfly the selected player.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[120] = {
			CommandName = "nocliptool",
			CommandText = "nocliptool <player> <speed>",
			CommandDescription = "Gives the player the noclip tool.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

		[121] = {
			CommandName = "unnocliptool",
			CommandText = "unnocliptool <player> <speed>",
			CommandDescription = "Takes the player's noclip tool.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
			CommandFilter = {"me", "all", "other"},
			CommandLog = true,
			WebhookLog = false,
		},

	},

	ServerCommands = {

		[1] = {
			CommandName = "sunrisetime",
			CommandText = "Sunrise Time",
			CommandDescription = "Make the game time 8:00.",
			CommandPermission = {10},
		},

		[2] = {
			CommandName = "noontime",
			CommandText = "Noon Time",
			CommandDescription = "Make the game time 12:00.",
			CommandPermission = {10},
		},

		[3] = {
			CommandName = "sunsettime",
			CommandText = "Sunset Time",
			CommandDescription = "Make the game time 18:00.",
			CommandPermission = {10},
		},

		[4] = {
			CommandName = "nighttime",
			CommandText = "Night Time",
			CommandDescription = "Make the game time 00:00.",
			CommandPermission = {10},
		},

		[5] = {
			CommandName = "restartserver",
			CommandText = "Restart Server",
			CommandDescription = "Shut down the server and move all players to the new server.",
			CommandPermission = {10},
		},

		[6] = {
			CommandName = "lock",
			CommandText = "Lock Server",
			CommandDescription = "Locks the server and prevents new player access.",
			CommandPermission = {10},
		},

		[7] = {
			CommandName = "unlock",
			CommandText = "Unlock Server",
			CommandDescription = "Removes the lock on the server and allows new player access.",
			CommandPermission = {10},
		},

		[9] = {
			CommandName = "lockdown",
			CommandText = "Lockdown Server",
			CommandDescription = "Kick those who are not on the whitelist on the server.",
			CommandPermission = {10},
		},

		[10] = {
			CommandName = "unlockdown",
			CommandText = "Unlockdown Server",
			CommandDescription = "Removes the player from the lockdown whitelist.",
			CommandPermission = {10},
		},

		[11] = {
			CommandName = "shutdown",
			CommandText = "Shutdown Server",
			CommandDescription = "Shuts down the server.",
			CommandPermission = {10},
		},

		[12] = {
			CommandName = "muteall",
			CommandText = "Mute All Players",
			CommandDescription = "Mutes all players on the server.",
			CommandPermission = {10},
		},

		[13] = {
			CommandName = "unmuteall",
			CommandText = "Unmute All Players",
			CommandDescription = "Removes the muting of all players on the server.",
			CommandPermission = {10},
		},

		[14] = {
			CommandName = "killall",
			CommandText = "kill All Players",
			CommandDescription = "Kill all the players.",
			CommandPermission = {10},
		},

		[15] = {
			CommandName = "pvpoff",
			CommandText = "Disable PVP",
			CommandDescription = "Turns off pvp on the server.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
		},

		[16] = {
			CommandName = "pvpon",
			CommandText = "Enable PVP",
			CommandDescription = "Opens pvp on the server.",
			CommandPermission = {1,2,4,5,6,7,8,9,10},
		},

		[17] = {
			CommandName = "savemap",
			CommandText = "Save Map",
			CommandDescription = "Saves the current map by cloning its components into a save folder.",
			CommandPermission = {10},
		},

		[18] = {
			CommandName = "loadmap",
			CommandText = "Load Map",
			CommandDescription = "Loads the saved map from the MapSave folder into the workspace.",
			CommandPermission = {10},
		},

		[19] = {
			CommandName = "killall",
			CommandText = "Kill All Players",
			CommandDescription = "Kill all the players.",
			CommandPermission = {10},
		},

	},

	ProductIds = {

		[1938743969] = {
			Name = "Test Tool",
			Type = "Product",
			Cost = 100,
			Permission = {1,2,3,4},
		},

		[1938743970] = {
			Name = "Test Gamepass",
			Type = "Gamepass",
			Cost = 100,
			Permission = {1,2,3,4},
		},

	},

	Statistics = {

		[0] = {
			Name = "ProductIds",
			Text = "Product Ids",
		},

		[1] = {
			Name = "ServerUptime",
			Text = "Server Uptime",
			Permission = {1,2,3,4},
		},

		[2] = {
			Name = "OnlinePlayers",
			Text = "Online Players",
			Permission = {1,2,3,4},
		},

		[3] = {
			Name = "TotalJoinedPlayers",
			Text = "Total Joined Players",
			Permission = {1,2,3,4},
		},

		[4] = {
			Name = "ServerLocation",
			Text = "Server Location",
			Permission = {1,2,3,4},
		},

		[5] = {
			Name = "ServerSize",
			Text = "Server Size",
			Permission = {1,2,3,4},
		},

		[6] = {
			Name = "GameCreateDate",
			Text = "Game Create Date",
			Permission = {1,2,3,4},
		},

		[7] = {
			Name = "GameUpdateDate",
			Text = "Game Update Date",
			Permission = {1,2,3,4},
		},

		[8] = {
			Name = "Genre",
			Text = "Genre",
			Permission = {1,2,3,4},
		},

		[9] = {
			Name = "FavoritedCount",
			Text = "Favorited Count",
			Permission = {1,2,3,4},
		},

		[10] = {
			Name = "Visits",
			Text = "Visits",
			Permission = {1,2,3,4},
		},

		[11] = {
			Name = "TotalOnlinePlayers",
			Text = "Total Online Players",
			Permission = {1,2,3,4},
		},

		[12] = {
			Name = "GameVersion",
			Text = "Game Version",
			Permission = {1,2,3,4},
		},

		[13] = {
			Name = "PlaceID",
			Text = "Place ID",
			Permission = {1,2,3,4},
		},

		[14] = {
			Name = "UniverseID",
			Text = "Universe ID",
			Permission = {1,2,3,4},
		},

	},


}

return module
