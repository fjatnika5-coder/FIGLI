--[[SERVICES]]--

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

--[[MODULES]]--

local Player = require(script.Parent.Player)
local UiSyncer = require(script.Parent.UiSyncer)
local Songs = require(script.Parent.Songs)
local SongInfo = require(script.Parent.Classes.SongInfo)
local SongCollection = require(script.Parent.Classes.SongCollection)

type SongCollection = SongCollection.SongCollection
type SongInfo = SongInfo.SongInfo

--[[GLOBALS]]--

local audioPlayer = script.Parent.MusicPlayer

local playerMaster = script.Parent.MusicPlayerMaster
local playerContent = playerMaster.MusicPlayer.Content
local actions = playerContent.Actions
local playlistMaster = playerMaster.PlaylistMaster

local actionButtons = {
	Loop = actions.Loop,
	Next = actions.Next,
	PlayPause = actions.PlayPause,
	Playlist = actions.Playlist,
	Previous = actions.Previous,
	VolumeToggle = actions.VolumeToggle,
	VolumeUp = actions.VolumeUp,
	VolumeDown = actions.VolumeDown,
}

local currentSongCollection = nil

local volumeControlsVisible = false
local playlistVisible = false
local playerVisible = true

local visualiser = playerMaster.MusicPlayer.Content.Visualiser
local visualiserBars = {}
local visualiserBarsCount = 48
local startFrequency = 50
local endFrequency = 500

local mouse = Players.LocalPlayer:GetMouse()

local countryCode = nil

--[[FUNCTIONS]]--

local function getActionButtonIcons(ActionButton): {ImageLabel}
	local icons = {}
	for _, child in pairs(ActionButton:GetChildren()) do
		if child:IsA("ImageLabel") or child.Name == "Icon" then
			table.insert(icons, child)
		end
	end
	return icons
end

local function getChangeIconScaleFunction(ActionButton, NewScale: number): () -> ()
	local function changeScale()
		local icons = getActionButtonIcons(ActionButton)
		for _, icon in pairs(icons) do
			local uiScale = icon:FindFirstChildWhichIsA("UIScale")
			if not uiScale then
				uiScale = Instance.new("UIScale")
				uiScale.Parent = icon
			end
			local scaleTween = TweenService:Create(
				uiScale,
				TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
				{Scale = NewScale}
			)
			scaleTween:Play()
		end
	end
	return changeScale
end

local function addActionButtonAnimations(ActionButton)
	local button = ActionButton.Button
	local enlargeIcon = getChangeIconScaleFunction(ActionButton, 1.2)
	local shrinkIcon = getChangeIconScaleFunction(ActionButton, 0.8)
	local returnIcon = getChangeIconScaleFunction(ActionButton, 1)

	button.MouseEnter:Connect(enlargeIcon)
	button.MouseLeave:Connect(returnIcon)
	button.MouseButton1Down:Connect(shrinkIcon)
	button.MouseButton1Up:Connect(enlargeIcon)
end

for _, actionButton in pairs(actionButtons) do
	addActionButtonAnimations(actionButton)
end
addActionButtonAnimations(playlistMaster.Playlist.SearchMaster.Shuffle)

local function togglePlay(NewSong: SongInfo?, NewTimePosition: number?, OverrideShuffle: boolean)
	if Player.IsPlaying then
		Player.Pause()
	else
		local song = NewSong or Player.GetCurrentSong(OverrideShuffle)
		local songId = song.Order
		if song.Order > #Player.Songs.Songs then
			songId = 1
		end
		Player.Play(songId, NewTimePosition or audioPlayer.TimePosition, OverrideShuffle)
	end

	local visibleIcon
	local invisibleIcon

	if Player.IsPlaying then
		visibleIcon = actionButtons.PlayPause.IconPause
		invisibleIcon = actionButtons.PlayPause.IconPlay
	else
		visibleIcon = actionButtons.PlayPause.IconPlay
		invisibleIcon = actionButtons.PlayPause.IconPause
	end

	visibleIcon.Visible = true
	invisibleIcon.Visible = false

	UiSyncer.UpdateTitleText(OverrideShuffle)
end
actionButtons.PlayPause.Button.MouseButton1Click:Connect(togglePlay)

local function next()
	Player.Next()
	Player.Pause()
	togglePlay()
end
actionButtons.Next.Button.MouseButton1Click:Connect(next)

audioPlayer.Ended:Connect(function()
	if not audioPlayer.Looped then
		next()
	end
end)

local function previous()
	Player.Previous()
	Player.Pause()
	togglePlay()
end
actionButtons.Previous.Button.MouseButton1Click:Connect(previous)

local function toggleLoop()
	Player.SetLooped(not audioPlayer.Looped)

	local visibleIcon
	local invisibleIcon

	if audioPlayer.Looped then
		visibleIcon = actionButtons.Loop.LoopEnabled
		invisibleIcon = actionButtons.Loop.LoopDisabled
	else
		visibleIcon = actionButtons.Loop.LoopDisabled
		invisibleIcon = actionButtons.Loop.LoopEnabled
	end

	visibleIcon.Visible = true
	invisibleIcon.Visible = false
end
actions.Loop.Button.MouseButton1Click:Connect(toggleLoop)

local function togglePlaylist()
	playlistVisible = not playlistVisible
	local newIconStrokeTransparency
	local newPlaylistPositionY

	if playlistVisible then
		newIconStrokeTransparency = 0
		newPlaylistPositionY = 0
	else
		newIconStrokeTransparency = 1
		newPlaylistPositionY = 1
	end

	local icon = getActionButtonIcons(actionButtons.Playlist)[1]
	local iconStrokeTween = TweenService:Create(
		icon.UIStroke,
		TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
		{Transparency = newIconStrokeTransparency}
	)

	local playlist = playerMaster.PlaylistMaster.Playlist
	local playlistTween = TweenService:Create(
		playlist,
		TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
		{Position = UDim2.fromScale(0, newPlaylistPositionY)}
	)

	iconStrokeTween:Play()
	playlistTween:Play()
end
actionButtons.Playlist.Button.MouseButton1Click:Connect(togglePlaylist)

local function addSongToPlaylist(Song: SongInfo)
	local playlist = playerMaster.PlaylistMaster.Playlist

	local songFrame = script.Song:Clone()
	songFrame.Name = Song.Title
	songFrame.Title.Text = Song.Title
	songFrame.Parent = playlist.Songs

	local function playSong()
		Player.Pause()
		togglePlay(Song, 0, true)
	end

	local function updateSize()
		songFrame.Size = UDim2.new(1, 0, 0, songFrame.AbsoluteSize.X / 6.376)
	end

	-- Event-driven, bukan per-frame: ukuran hanya berubah saat AbsoluteSize berubah
	updateSize()
	local updateSizeConnection = songFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateSize)
	songFrame.Button.MouseButton1Click:Connect(playSong)

	songFrame.Destroying:Connect(function()
		updateSizeConnection:Disconnect()
	end)
end

local function clearPlaylist()
	local playlist = playerMaster.PlaylistMaster.Playlist
	for _, songFrame in pairs(playlist.Songs:GetChildren()) do
		if songFrame:IsA("Frame") then
			songFrame:Destroy()
		end
	end
end

local function fillPlaylist(NewSongs: SongCollection)
	local playlist = playerMaster.PlaylistMaster.Playlist

	table.sort(NewSongs.Songs, function(songInfoA, songInfoB)
		return songInfoA.Order < songInfoB.Order
	end)

	for _, song in pairs(NewSongs.Songs) do
		addSongToPlaylist(song)
	end

	for _, songFrame in pairs(playlist.Songs:GetChildren()) do
		if songFrame:IsA("Frame") then
			songFrame.Size = UDim2.fromOffset(songFrame.AbsoluteSize.X, songFrame.AbsoluteSize.Y)
		end
	end
end

local function updatePlaylistSongsSize()
	local playlist = playlistMaster.Playlist
	local songCount = #playlist.Songs:GetChildren() - 2
	local firstSongFrame = nil

	for _, songFrame in pairs(playlist.Songs:GetChildren()) do
		if songFrame:IsA("Frame") then
			firstSongFrame = songFrame
			break
		end
	end

	if not firstSongFrame then
		return
	end

	local contentSizeY = songCount * (firstSongFrame.AbsoluteSize.Y + playlist.Songs.UIListLayout.Padding.Offset)
		+ playlist.Songs.UIListLayout.Padding.Offset
	playlist.Songs.CanvasSize = UDim2.fromOffset(0, contentSizeY)
end
-- Update saat isi playlist berubah saja, bukan tiap frame
playlistMaster.Playlist.Songs.ChildAdded:Connect(updatePlaylistSongsSize)
playlistMaster.Playlist.Songs.ChildRemoved:Connect(updatePlaylistSongsSize)
playlistMaster.Playlist.Songs.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updatePlaylistSongsSize)

local function filterPlaylist()
	local playlist = playerMaster.PlaylistMaster.Playlist
	local pattern = playlist.SearchMaster.Search.Text

	for _, songFrame in pairs(playlist.Songs:GetChildren()) do
		if not songFrame:IsA("Frame") then
			continue
		end

		if string.match(string.lower(songFrame.Name), string.lower(pattern)) then
			songFrame.Visible = true
		else
			songFrame.Visible = false
		end
	end
end
playerMaster.PlaylistMaster.Playlist.SearchMaster.Search:GetPropertyChangedSignal("Text"):Connect(filterPlaylist)

local function getPlaylistNames(): {string}
	local playlistNames = {}
	for playlistName in pairs(Songs) do
		table.insert(playlistNames, playlistName)
	end
	table.sort(playlistNames)
	return playlistNames
end

local function findSongCollection(Name: string)
	for _, collection in pairs(Songs) do
		if collection.Name == Name then
			return collection
		end
	end
end

local function changePlaylist(NewPlaylistName: string, OverrideShuffle: boolean)
	local newSongs = findSongCollection(NewPlaylistName)

	if not newSongs then
		error(`There is no playlist with the name "{NewPlaylistName}". Make sure the name of the playlist button is the same as the playlist that it corresponds to.`)
	end

	for _, playlistButton in pairs(playlistMaster.Playlist.PlaylistButtons:GetChildren()) do
		playlistButton.UIStroke.Enabled = (playlistButton.Name == NewPlaylistName)
	end

	clearPlaylist()
	fillPlaylist(newSongs)
	filterPlaylist()
	Player.ChangeSongs(newSongs, NewPlaylistName)
	Player.Pause()

	togglePlay(newSongs.Songs[math.random(1, #newSongs.Songs)], nil, OverrideShuffle)
	UiSyncer.UpdateTitleText(OverrideShuffle)

	currentSongCollection = newSongs
end

local function shufflePlaylist()
	currentSongCollection:Shuffle()
	changePlaylist(currentSongCollection.Name)
end

local function toggleShuffle()
	Player.SetShuffle(not Player.ShuffleEnabled)

	local newStrokeTransparency = Player.ShuffleEnabled and 0 or 1
	local shuffleButton = playlistMaster.Playlist.SearchMaster.Shuffle
	local strokeTween = TweenService:Create(
		shuffleButton.Icon.UIStroke,
		TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
		{Transparency = newStrokeTransparency}
	)
	strokeTween:Play()
end
playlistMaster.Playlist.SearchMaster.Shuffle.Button.MouseButton1Click:Connect(toggleShuffle)

local function connectPlaylistButtonFunctions(PlaylistButton: TextButton)
	PlaylistButton.MouseButton1Click:Connect(function()
		changePlaylist(PlaylistButton.Name)
	end)
end

for _, playlistButton in pairs(playlistMaster.Playlist.PlaylistButtons:GetChildren()) do
	connectPlaylistButtonFunctions(playlistButton)
end

local function updateTitleText(OverrideShuffle: boolean?)
	UiSyncer.UpdateTitleText(OverrideShuffle)
end

local function updateTitleSize()
	UiSyncer.UpdateTitleSize()
end

local function updateProgressBar()
	UiSyncer.UpdateProgressBar()
end

RunService.Heartbeat:Connect(function()
	updateProgressBar()
	updateTitleSize()
end)

local function toggleVolumeController()
	volumeControlsVisible = not volumeControlsVisible
	local newSize
	local newTransparency

	if volumeControlsVisible then
		newSize = UDim2.fromScale(0.319, 1)
		newTransparency = 0
	else
		newSize = UDim2.fromScale(0, 1)
		newTransparency = 1
	end

	local sizeTween = TweenService:Create(
		actions.VolumeController,
		TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
		{GroupTransparency = newTransparency, Size = newSize}
	)

	sizeTween:Play()
end
actionButtons.VolumeToggle.Button.MouseButton1Click:Connect(toggleVolumeController)

local function dragVolume()
	local volumeControllerMaster = actions.VolumeController.Master

	local function update()
		local minX = volumeControllerMaster.AbsolutePosition.X
		local maxX = minX + volumeControllerMaster.AbsoluteSize.X
		local currentX = mouse.X
		local newButtonAbsoluteX = math.clamp(currentX, minX, maxX)
		local newButtonX = newButtonAbsoluteX - minX
		local fillFraction = newButtonX / volumeControllerMaster.AbsoluteSize.X
		local newVolume = fillFraction * 2

		volumeControllerMaster.Button.Position = UDim2.new(0, newButtonX, 0.5, 0)
		volumeControllerMaster.Fill.Size = UDim2.fromScale(fillFraction, 1)
		audioPlayer.Volume = newVolume
	end

	local updateConnection = RunService.Heartbeat:Connect(update)

	local releaseConnection
	releaseConnection = mouse.Button1Up:Connect(function()
		updateConnection:Disconnect()
		releaseConnection:Disconnect()
	end)
end
actions.VolumeController.Master.Button.Button.MouseButton1Down:Connect(dragVolume)

local function changeVolume(Offset: number)
	local newVolume = audioPlayer.Volume + Offset
	newVolume = math.clamp(newVolume, 0, 2)
	audioPlayer.Volume = newVolume
	local volumePercentage = math.floor(newVolume / 2 * 100)
	actions.VolumeAmount.Text = tostring(volumePercentage) .. "%"
end

local function increaseVolume()
	changeVolume(0.25)
end
actions.VolumeUp.Button.MouseButton1Click:Connect(increaseVolume)

local function decreaseVolume()
	changeVolume(-0.25)
end
actions.VolumeDown.Button.MouseButton1Click:Connect(decreaseVolume)

local function fillVisualiser()
	for frequency = startFrequency, endFrequency, (endFrequency - startFrequency) / visualiserBarsCount do
		local bar = script.Bar:Clone()
		bar.Name = frequency
		bar.LayoutOrder = frequency
		bar.Parent = visualiser
		table.insert(visualiserBars, bar)
	end
end

local function updateBar(bar: Frame, index: number)
	local loudness = audioPlayer.IsPlaying and audioPlayer.PlaybackLoudness or 0
	local norm = math.clamp(loudness / 400, 0, 1)

	local total = #visualiserBars
	local center = (total + 1) / 2
	local distance = math.abs(index - center)
	local centerIntensity = 1 - distance / center

	local minRandom = 0.8
	local maxRandom = 1.2
	local randomFactor = math.random() * (maxRandom - minRandom) + minRandom

	local intensity = centerIntensity * randomFactor
	local height = math.clamp(norm * intensity + 0.05, 0, 1)

	local tween = TweenService:Create(
		bar,
		TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = UDim2.new(bar.Size.X.Scale, 0, height, 0)}
	)
	tween:Play()
	return tween.Completed
end

local function startUpdatingBars()
	for i, bar in ipairs(visualiserBars) do
		if not bar:IsA("Frame") then
			continue
		end

		task.spawn(function()
			while bar.Parent do
				RunService.Heartbeat:Wait()
				updateBar(bar, i):Wait()
			end
		end)
	end
end

local function togglePlayer()
	playerVisible = not playerVisible
	local newTransparency

	if playerVisible then
		newTransparency = 0
	else
		newTransparency = 1
	end

	if newTransparency == 0 then
		playerMaster.Position = UDim2.fromScale(0, 0)
		playerMaster.Visible = true
	end

	local playerTween = TweenService:Create(
		playerMaster,
		TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
		{GroupTransparency = newTransparency}
	)
	playerTween:Play()
	playerTween.Completed:Wait()
	if playerMaster.GroupTransparency == 1 then
		playerMaster.Visible = false
	end
end
script.Parent.TogglePlayer.MouseButton1Click:Connect(togglePlayer)

fillVisualiser()
startUpdatingBars()

local success, errorMessage = pcall(function()
	countryCode = LocalizationService:GetCountryRegionForPlayerAsync(Players.LocalPlayer)
end)

if not success then
	warn(errorMessage)
	countryCode = nil
end

changePlaylist("English", true)

if not Player.ShuffleEnabled then
	toggleShuffle()
end

updateTitleText(true)
updateTitleSize()

Player.SongChanged:Connect(function(CurrentSongId: number, OverrideShuffle: boolean)
	updateTitleText(OverrideShuffle)
end)
