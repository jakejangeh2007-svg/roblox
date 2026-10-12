--!strict
-- On-screen bits: gas meter, Mega Fart charge bar, big notices and a controls hint.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer

local Hud = {}

local GAS_COLOR = Color3.fromRGB(150, 210, 60)
local LOW_GAS_COLOR = Color3.fromRGB(230, 80, 60)
local CHARGE_START_COLOR = Color3.fromRGB(255, 220, 60)
local CHARGE_FULL_COLOR = Color3.fromRGB(255, 70, 40)
local DARK = Color3.fromRGB(35, 35, 40)

local KEYBOARD_HINT = "A / ← : fart left     W / ↑ / Space : fart straight     D / → : fart right\n"
	.. "Hold to charge a MEGA FART     V : camera"
local TOUCH_HINT = "LEFT / FART / RIGHT buttons. Hold to charge a MEGA FART."

local gasFill: Frame
local chargeBar: Frame
local chargeFill: Frame
local noticeLabel: TextLabel
local chargeStartedAt: number? = nil
local noticeCount = 0

local function makeBar(parent: Instance, size: UDim2, position: UDim2, color: Color3): Frame
	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame
	return frame
end

local function makeLabel(parent: Instance, text: string, size: UDim2, position: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.TextScaled = true
	label.Parent = parent
	return label
end

local function update()
	local gas = player:GetAttribute("Gas")
	local fraction = if typeof(gas) == "number" then math.clamp(gas / Config.GAS_MAX, 0, 1) else 0
	gasFill.Size = UDim2.fromScale(fraction, 1)
	gasFill.BackgroundColor3 = if fraction < 0.25 then LOW_GAS_COLOR else GAS_COLOR

	local held = if chargeStartedAt then os.clock() - chargeStartedAt else 0
	if held >= Config.MEGA_MIN_HOLD then
		local charge = math.clamp(held / Config.MEGA_CHARGE_TIME, 0, 1)
		chargeBar.Visible = true
		chargeFill.Size = UDim2.fromScale(charge, 1)
		chargeFill.BackgroundColor3 = CHARGE_START_COLOR:Lerp(CHARGE_FULL_COLOR, charge)
	else
		chargeBar.Visible = false
	end
end

function Hud.startCharge()
	chargeStartedAt = os.clock()
end

function Hud.stopCharge()
	chargeStartedAt = nil
end

function Hud.notice(text: string, color: Color3)
	noticeCount += 1
	local thisNotice = noticeCount
	noticeLabel.Text = text
	noticeLabel.TextColor3 = color
	noticeLabel.TextTransparency = 0
	noticeLabel.TextStrokeTransparency = 0
	task.delay(2.5, function()
		if noticeCount == thisNotice then
			TweenService:Create(noticeLabel, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 })
				:Play()
		end
	end)
end

function Hud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "FartHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local gasBack = makeBar(gui, UDim2.fromOffset(260, 18), UDim2.new(0.5, -130, 1, -40), DARK)
	gasFill = makeBar(gasBack, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), GAS_COLOR)
	makeLabel(gasBack, "GAS", UDim2.fromOffset(44, 18), UDim2.fromOffset(-50, 0))

	chargeBar = makeBar(gui, UDim2.fromOffset(260, 10), UDim2.new(0.5, -130, 1, -56), DARK)
	chargeFill = makeBar(chargeBar, UDim2.fromScale(0, 1), UDim2.fromScale(0, 0), CHARGE_START_COLOR)
	chargeBar.Visible = false

	noticeLabel = makeLabel(gui, "", UDim2.new(1, 0, 0, 80), UDim2.fromScale(0, 0.18))
	noticeLabel.TextTransparency = 1
	noticeLabel.TextStrokeTransparency = 1

	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local hint = makeLabel(
		gui,
		if touchOnly then TOUCH_HINT else KEYBOARD_HINT,
		UDim2.new(0, 520, 0, 36),
		UDim2.new(0.5, -260, 1, -100)
	)
	hint.TextTransparency = 0.25

	RunService.RenderStepped:Connect(update)
end

return Hud
