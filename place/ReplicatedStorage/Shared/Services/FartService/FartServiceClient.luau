--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.FartService.FartServiceClient
--
-- The client half of FartService: turns key and controller presses into fart
-- requests, and plays fart effects. Tap = toot, hold then let go = Mega Fart.
-- Your own farts play the moment you let go, so they feel instant; the server
-- still decides whether the boat moves.
--
--   Fart Left       A, Left arrow, Q, or LB
--   Fart Straight   W, Up arrow, Space, or RT
--   Fart Right      D, Right arrow, E, or RB
--
-- On-screen buttons for touch devices (UI, to be built) call StartCharge and
-- ReleaseCharge. A gas meter reads the player's "Gas" attribute, and a charge bar
-- listens to ChargeStarted and ChargeEnded.
--
-- Asset contract:
--   ReplicatedStorage.Assets.VFX.FartCloud      ParticleEmitter: the gas cloud. Set Rate to 0;
--                                               farts call Emit. Its Speed is multiplied by fart power.
--   ReplicatedStorage.Assets.Sounds.Farts       Folder of Sounds; each fart picks one at random

local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoatServiceShared = require(ReplicatedStorage.Shared.Services.BoatService.BoatServiceShared)
local CameraServiceClient = require(ReplicatedStorage.Shared.Services.CameraService.CameraServiceClient)
local FartConfig = require(ReplicatedStorage.Shared.Modules.Game.FartConfig)
local FartPhysics = require(ReplicatedStorage.Shared.Services.FartService.FartPhysics)
local FartServiceShared = require(ReplicatedStorage.Shared.Services.FartService.FartServiceShared)
local Remotes = require(ReplicatedStorage.Shared.Modules.Core.Remotes)
local Signal = require(ReplicatedStorage.Packages.Signal)

local SERVICE_NAME = FartServiceShared.SERVICE_NAME
local BUTT_ATTACHMENT_NAME = "FartButt"
local FART_CLOUD_NAME = "FartCloud"
local FART_SOUNDS_NAME = "Farts"

local ACTION_DIRECTIONS: { [string]: FartPhysics.Direction } = {
	FartLeft = "Left",
	FartStraight = "Straight",
	FartRight = "Right",
}

local localPlayer = Players.LocalPlayer

local FartServiceClient = {}

type FartServiceClientMembers = {
	PressedAt: { [string]: number }, -- direction -> os.clock() its key went down
	LastFartTime: number,
	Random: Random,
	FartCloudTemplate: ParticleEmitter?,
	FartSounds: { Sound },
	RequestFartRemote: RemoteEvent?, -- set once the server has created it
	ChargeStarted: Signal.Signal, -- fires (direction: string) when a fart key goes down while riding
	ChargeEnded: Signal.Signal, -- fires () when it's let go or cancelled
	Fartquake: Signal.Signal, -- fires () when this player's boat FARTQUAKEs
}

export type FartServiceClient = typeof(FartServiceClient) & FartServiceClientMembers

-- True while the local player sits in a boat that's on the river.
local function IsRiding(): boolean
	local character = localPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local seat = if humanoid then humanoid.SeatPart else nil
	local boatModel = if seat then BoatServiceShared.GetBoatModelFromPart(seat) else nil
	return boatModel ~= nil and boatModel:GetAttribute(BoatServiceShared.STATE_ATTRIBUTE) == "Launched"
end

local function FindAssets(): (ParticleEmitter?, { Sound })
	local assets = ReplicatedStorage.Assets
	local vfxFolder = assets:FindFirstChild("VFX")
	local fartCloud = if vfxFolder then vfxFolder:FindFirstChild(FART_CLOUD_NAME) else nil
	if not fartCloud or not fartCloud:IsA("ParticleEmitter") then
		warn(`Asset missing: ReplicatedStorage.Assets.VFX.{FART_CLOUD_NAME} (a ParticleEmitter). Farts won't show.`)
		fartCloud = nil
	end

	local fartSounds = {}
	local soundsFolder = assets:FindFirstChild("Sounds")
	local fartSoundsFolder = if soundsFolder then soundsFolder:FindFirstChild(FART_SOUNDS_NAME) else nil
	if fartSoundsFolder then
		for _, child in fartSoundsFolder:GetChildren() do
			if child:IsA("Sound") then
				table.insert(fartSounds, child)
			end
		end
	end
	if #fartSounds == 0 then
		warn(`Asset missing: Sounds in ReplicatedStorage.Assets.Sounds.{FART_SOUNDS_NAME}. Farts will be silent.`)
	end
	return fartCloud :: ParticleEmitter?, fartSounds
end

function FartServiceClient.Init(self: FartServiceClient)
	self.PressedAt = {}
	self.LastFartTime = 0
	self.Random = Random.new()
	self.RequestFartRemote = nil
	self.ChargeStarted = Signal.new()
	self.ChargeEnded = Signal.new()
	self.Fartquake = Signal.new()
	self.FartCloudTemplate, self.FartSounds = FindAssets()

	local function OnAction(actionName: string, inputState: Enum.UserInputState, _input: InputObject)
		local direction: FartPhysics.Direction? = ACTION_DIRECTIONS[actionName]
		if not direction or not IsRiding() then
			-- Not on the river: let the keys do their normal job (like walking).
			return Enum.ContextActionResult.Pass
		end
		if inputState == Enum.UserInputState.Begin then
			self:StartCharge(direction)
		elseif inputState == Enum.UserInputState.End then
			self:ReleaseCharge(direction)
		elseif inputState == Enum.UserInputState.Cancel then
			self:CancelCharge(direction)
		end
		return Enum.ContextActionResult.Sink
	end
	ContextActionService:BindAction(
		"FartLeft",
		OnAction,
		false,
		Enum.KeyCode.A,
		Enum.KeyCode.Left,
		Enum.KeyCode.Q,
		Enum.KeyCode.ButtonL1
	)
	ContextActionService:BindAction(
		"FartStraight",
		OnAction,
		false,
		Enum.KeyCode.W,
		Enum.KeyCode.Up,
		Enum.KeyCode.Space,
		Enum.KeyCode.ButtonR2
	)
	ContextActionService:BindAction(
		"FartRight",
		OnAction,
		false,
		Enum.KeyCode.D,
		Enum.KeyCode.Right,
		Enum.KeyCode.E,
		Enum.KeyCode.ButtonR1
	)

	-- Remotes are waited for in a separate thread so Init never yields.
	task.spawn(function()
		self.RequestFartRemote = Remotes.WaitForEvent(SERVICE_NAME, FartServiceShared.REQUEST_FART)
		Remotes.WaitForEvent(SERVICE_NAME, FartServiceShared.PLAY_FART).OnClientEvent
			:Connect(function(farter: Player?, direction: string, power: number, isMega: boolean)
				if farter then -- nil if they left before this arrived
					self:PlayFartEffect(farter, direction, power, isMega)
				end
			end)
		Remotes.WaitForEvent(SERVICE_NAME, FartServiceShared.PLAY_FARTQUAKE).OnClientEvent:Connect(function()
			CameraServiceClient:Shake(FartConfig.FARTQUAKE_SHAKE)
			self.Fartquake:Fire()
		end)
	end)
end

-- A fart key (or on-screen button) went down: start timing the hold.
function FartServiceClient.StartCharge(self: FartServiceClient, direction: FartPhysics.Direction)
	if not IsRiding() then
		return
	end
	self.PressedAt[direction] = os.clock()
	self.ChargeStarted:Fire(direction)
end

-- The key was let go: fart, if the cooldown and gas allow it.
function FartServiceClient.ReleaseCharge(self: FartServiceClient, direction: FartPhysics.Direction)
	local pressedAt = self.PressedAt[direction]
	self.PressedAt[direction] = nil
	self.ChargeEnded:Fire()
	if not pressedAt or not IsRiding() then
		return
	end

	local requestFartRemote = self.RequestFartRemote
	local now = os.clock()
	if not requestFartRemote or now - self.LastFartTime < FartConfig.TOOT_COOLDOWN then
		return
	end
	local heldTime = math.min(now - pressedAt, FartConfig.MEGA_CHARGE_TIME)
	local gas = localPlayer:GetAttribute(FartServiceShared.GAS_ATTRIBUTE)
	if typeof(gas) ~= "number" or gas < FartPhysics.GetCost(heldTime) then
		self:PlayDudEffect(localPlayer)
		return
	end

	self.LastFartTime = now
	local power = FartPhysics.GetPower(heldTime)
	local isMega = FartPhysics.IsMega(heldTime)
	self:PlayFartEffect(localPlayer, direction, power, isMega)
	if isMega then
		CameraServiceClient:Shake(FartConfig.MEGA_SHAKE * power)
	end
	requestFartRemote:FireServer(direction, heldTime)
end

function FartServiceClient.CancelCharge(self: FartServiceClient, direction: FartPhysics.Direction)
	self.PressedAt[direction] = nil
	self.ChargeEnded:Fire()
end

-- The attachment and emitter at a player's butt, made the first time they fart.
function FartServiceClient.GetButt(self: FartServiceClient, player: Player): (Attachment?, ParticleEmitter?)
	local character = player.Character
	local rootPart = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not rootPart or not rootPart:IsA("BasePart") then
		return nil, nil
	end

	local existing = rootPart:FindFirstChild(BUTT_ATTACHMENT_NAME)
	if existing and existing:IsA("Attachment") then
		return existing, existing:FindFirstChildOfClass("ParticleEmitter")
	end

	local butt = Instance.new("Attachment")
	butt.Name = BUTT_ATTACHMENT_NAME
	butt.CFrame = FartConfig.BUTT_OFFSET
	butt.Parent = rootPart
	local emitter: ParticleEmitter? = nil
	local template = self.FartCloudTemplate
	if template then
		local newEmitter = template:Clone()
		newEmitter.Enabled = false
		newEmitter.Parent = butt
		emitter = newEmitter
	end
	return butt, emitter
end

function FartServiceClient.PlaySound(self: FartServiceClient, parent: Instance, volume: number, pitch: number)
	if #self.FartSounds == 0 then
		return
	end
	local sound = self.FartSounds[self.Random:NextInteger(1, #self.FartSounds)]:Clone()
	sound.Volume = volume
	sound.PlaybackSpeed = self.Random:NextNumber(FartConfig.MIN_PITCH, FartConfig.MAX_PITCH) * pitch
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, FartConfig.SOUND_LIFETIME)
end

function FartServiceClient.PlayFartEffect(
	self: FartServiceClient,
	player: Player,
	direction: string,
	power: number,
	isMega: boolean
)
	local butt, emitter = self:GetButt(player)
	if not butt then
		return
	end
	-- Gas comes out behind the rider, angled to the side on a Left or Right fart.
	local gasAngle = if direction == "Left"
		then -FartConfig.GAS_ANGLE
		elseif direction == "Right" then FartConfig.GAS_ANGLE
		else 0
	butt.CFrame = FartConfig.BUTT_OFFSET * CFrame.Angles(0, gasAngle, 0)

	local template = self.FartCloudTemplate
	if emitter and template then
		emitter.Speed = NumberRange.new(template.Speed.Min * power, template.Speed.Max * power)
		emitter:Emit(if isMega then FartConfig.MEGA_PARTICLES else FartConfig.TOOT_PARTICLES)
	end
	self:PlaySound(
		butt,
		if isMega then FartConfig.MEGA_VOLUME else FartConfig.TOOT_VOLUME,
		if isMega then FartConfig.MEGA_PITCH else 1
	)
end

-- Out of gas: a sad little puff.
function FartServiceClient.PlayDudEffect(self: FartServiceClient, player: Player)
	local butt, emitter = self:GetButt(player)
	if not butt then
		return
	end
	butt.CFrame = FartConfig.BUTT_OFFSET
	local template = self.FartCloudTemplate
	if emitter and template then
		emitter.Speed = template.Speed
		emitter:Emit(FartConfig.DUD_PARTICLES)
	end
	self:PlaySound(butt, FartConfig.DUD_VOLUME, FartConfig.DUD_PITCH)
end

return FartServiceClient :: FartServiceClient
