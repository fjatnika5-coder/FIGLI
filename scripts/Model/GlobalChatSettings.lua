local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Cek apakah RemoteEvent sudah ada (hindari double spawn)
local existingEvent = ReplicatedStorage:FindFirstChild("GlobalChatEvent")
local ev

if existingEvent then
	ev = existingEvent
else
	ev = Instance.new("RemoteEvent")
	ev.Name = "GlobalChatEvent"
	ev.Parent = ReplicatedStorage
end

local Settings = {

	Chat_Event = ev,

	Prefix = "[SERVER]:",

	PrefixColor = Color3.fromRGB(255, 0, 0),
	MessageColor = Color3.fromRGB(111, 255, 0),

	MessageDelay = 300,

	Messages = {
		" Take a moment to relax… enjoy the music and cozy vibes of this place.",
		" If you love spending time here, a Like & Favorite would mean a lot to us.",
		" Try adjusting the sky—each color brings a different calming atmosphere.",
		" ConfessionBoard: Feel free to write your thoughts, feelings, or anything you want to express.",
		" New songs have been added~ feel free to explore the playlist anytime.",
		" The Music Player now shuffles automatically. Switch to manual if you prefer your own flow.",
		" Move the Music Player wherever feels most comfortable for you.",
		" Don’t like the screen shake? You can turn it off in Settings easily.",
		" For the best visuals, try Max Graphics—or lower it if your device needs it.",
		" Thank you for being here. We hope this place brings you comfort and peace.",
	}
}

return Settings



