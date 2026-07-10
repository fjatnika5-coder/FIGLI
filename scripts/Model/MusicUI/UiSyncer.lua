-- Changes the Ui Elements to reflect the state of the MusicPlayer

--[[SERVICES]]--

local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

--[[MODULES]]--

local Player = require(script.Parent.Player)
local SongInfo = require(script.Parent.Classes.SongInfo)
type SongInfo = SongInfo.SongInfo

--[[CONSTANTS]]--

--[[GLOBALS]]--

local UiSyncer = {}

local audioPlayer = script.Parent.MusicPlayer --script.Parent.AudioPlayer

local playerMaster = script.Parent.MusicPlayerMaster
local playerContent = playerMaster.MusicPlayer.Content

local titleMaster = playerContent.Title
local titleTextMaster = titleMaster.TextMaster
local titleTexts = {titleTextMaster.Title1}--, titleTextMaster.Title2}
local titleMoveTween: Tween = nil

local progressBar = playerContent.ProgressBar
local progressFill = progressBar.Master.Fill

--[[LOCAL FUNCTIONS]]--

local function formatTime(Time: number): string

	Time = math.floor(Time)

	local minutes = math.floor(Time / 60)
	local seconds = Time - (minutes * 60)
	local parts = {minutes, seconds}
	local stringParts = {}

	for index, part in pairs(parts) do

		local partString = tostring(part)
		if #partString == 1 then

			partString = "0" .. partString

		end
		stringParts[index] = partString

	end

	return stringParts[1] .. ":" .. stringParts[2]


end

--local function resetTitleText()

--	if titleMoveTween then

--		titleMoveTween:Cancel()

--	end

--end

--local function scrollTitleText()

--	titleMoveTween = TweenService:Create(
--		titleTextMaster,
--		TweenInfo.new(#titleTexts[1].Text * 0.05, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
--		{CanvasPosition = Vector2.new(titleTexts[1].AbsoluteSize.X, 0)}
--	)
--	titleMoveTween:Play()

--end

--[[MODULAR FUNCTIONS]]--

function UiSyncer.UpdateTitleSize()


	for index, titleText in pairs(titleTexts) do

		titleText.TextScaled = false
		titleText.TextSize = titleText.AbsoluteSize.Y

	end

	local title1 = titleTexts[1]
	local getTextBoundsParams = Instance.new("GetTextBoundsParams")
	getTextBoundsParams.Text = title1.Text
	getTextBoundsParams.Size = title1.TextSize
	getTextBoundsParams.Font = Font.fromName("FredokaOne", Enum.FontWeight.Regular, Enum.FontStyle.Italic)
	getTextBoundsParams.Width = 99999999
	local textBounds = TextService:GetTextBoundsAsync(getTextBoundsParams)

	for index, titleText in pairs(titleTexts) do

		titleText.Size = UDim2.new(0, textBounds.X, 1, 0)

	end
	titleTextMaster.Size = UDim2.new(0, textBounds.X * 1.1, 1, 0)

end

function UiSyncer.UpdateTitleText(OverrideShuffle: boolean)
	
	print(OverrideShuffle)
	local currentSong = Player.GetCurrentSong(OverrideShuffle)
	for index, titleText in pairs(titleTexts) do

		titleText.Text = currentSong.Title

	end

end

function UiSyncer.UpdateProgressBar()

	local currentTime = audioPlayer.TimePosition
	local length = audioPlayer.TimeLength
	local fraction = currentTime / length
	if fraction ~= fraction then
		--fraction is nan
		fraction = 0

	end

	progressFill.Size = UDim2.fromScale(fraction, 1)
	progressBar.CurrentTime.Text = formatTime(currentTime)
	progressBar.Length.Text = formatTime(length)

end


return UiSyncer
