--!strict
-- Fart clouds and sounds. Other players' farts arrive from the server; our own
-- play the moment we let go of the key, so they feel instant.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoatCamera = require(script.Parent.BoatCamera)
local Config = require(ReplicatedStorage.Shared.Config)

local FartFX = {}

local BUTT_OFFSET = CFrame.new(0, -1, 0.6) -- below and behind the HumanoidRootPart
-- Which way the gas comes out. Riders face the middle, so +Z (behind them) is over the water.
local GAS_ANGLE: { [string]: number } = {
	Left = -math.pi / 4, -- gas out to the left pushes our side right, turning the boat left
	Straight = 0,
	Right = math.pi / 4,
}
local CLOUD_COLOR = ColorSequence.new(Color3.fromRGB(160, 210, 70), Color3.fromRGB(110, 140, 60))

local random = Random.new()

-- The attachment and particle emitter at a player's butt, made the first time they fart.
local function getButt(player: Player): (Attachment?, ParticleEmitter?)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not (rootPart and rootPart:IsA("BasePart")) then
		return nil, nil
	end

	local existing = rootPart:FindFirstChild("FartButt")
	if existing and existing:IsA("Attachment") then
		return existing, existing:FindFirstChildOfClass("ParticleEmitter")
	end

	local butt = Instance.new("Attachment")
	butt.Name = "FartButt"
	butt.CFrame = BUTT_OFFSET
	butt.Parent = rootPart

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = CLOUD_COLOR
	emitter.EmissionDirection = Enum.NormalId.Back
	emitter.Rate = 0 -- only bursts from Emit()
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.SpreadAngle = Vector2.new(20, 20)
	emitter.Drag = 3
	emitter.Acceleration = Vector3.new(0, 3, 0)
	emitter.Transparency = NumberSequence.new(0.2, 1)
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.Parent = butt
	return butt, emitter
end

local function playSound(parent: Instance, volume: number, pitch: number)
	local sound = Instance.new("Sound")
	local ids = Config.FART_SOUND_IDS
	if #ids > 0 then
		sound.SoundId = ids[random:NextInteger(1, #ids)]
		sound.PlaybackSpeed = random:NextNumber(0.85, 1.15) * pitch
	else
		sound.SoundId = Config.PLACEHOLDER_SOUND_ID
		sound.PlaybackSpeed = random:NextNumber(0.35, 0.5) * pitch -- pitched way down so it burbles
	end
	sound.Volume = volume
	sound.RollOffMaxDistance = 150
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, 5)
end

function FartFX.play(player: Player, direction: string, power: number, isMega: boolean)
	local butt, emitter = getButt(player)
	if not (butt and emitter) then
		return
	end
	butt.CFrame = BUTT_OFFSET * CFrame.Angles(0, GAS_ANGLE[direction] or 0, 0)

	local size = if isMega then 2 else 1
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8 * size),
		NumberSequenceKeypoint.new(1, 3.5 * size),
	})
	emitter.Speed = NumberRange.new(6 * power, 12 * power)
	emitter:Emit(if isMega then 30 else 10)
	playSound(butt, if isMega then 1 else 0.6, if isMega then 0.8 else 1)

	if isMega and player == Players.LocalPlayer then
		BoatCamera.shake(0.3 * power)
	end
end

-- Out of gas: a sad little puff.
function FartFX.dud(player: Player)
	local butt, emitter = getButt(player)
	if not (butt and emitter) then
		return
	end
	butt.CFrame = BUTT_OFFSET
	emitter.Size = NumberSequence.new(0.4, 0.9)
	emitter.Speed = NumberRange.new(1, 2)
	emitter:Emit(3)
	playSound(butt, 0.25, 1.6)
end

return FartFX
