--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.FartService.FartServiceClient
--
-- The client half of FartService: turns key and controller presses into farting, and
-- plays everyone's fart effects. Hold the fart key to keep farting; its push builds up
-- the longer you keep farting (FartPhysics), and letting go stops. Riders fart straight
-- out behind them, pushing the boat toward its middle; they steer by sliding round the
-- edge of the boat (RiderService). Riders knocked off their boat swim back by farting
-- (OverboardService). Your own fart starts the moment you press, so it feels instant;
-- the server still decides whether it pushes anything, and tells this client to stop if
-- it says no.
--
--   Fart   W, Up arrow, Space, or RT
--
-- An on-screen button for touch devices (UI, to be built) calls PressFart on press and
-- ReleaseFart on release. A gas meter reads the player's "Gas" attribute.
--
-- Asset contract:
--   ReplicatedStorage.Assets.VFX.FartCloud      ParticleEmitter: the gas cloud, emitting out of its
--                                               attachment's Back. While farting, its Rate and
--                                               Speed grow with the fart.
--   ReplicatedStorage.Assets.Sounds.Farts       Folder of Sounds; each fart loops one at random

local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BoatServiceShared = require(ReplicatedStorage.Shared.Services.BoatService.BoatServiceShared)
local FartConfig = require(ReplicatedStorage.Shared.Modules.Game.FartConfig)
local FartPhysics = require(ReplicatedStorage.Shared.Services.FartService.FartPhysics)
local FartServiceShared = require(ReplicatedStorage.Shared.Services.FartService.FartServiceShared)
local OverboardServiceShared = require(ReplicatedStorage.Shared.Services.OverboardService.OverboardServiceShared)
local Remotes = require(ReplicatedStorage.Shared.Modules.Core.Remotes)
local Signal = require(ReplicatedStorage.Packages.Signal)

local SERVICE_NAME = FartServiceShared.SERVICE_NAME
local FART_ACTION = "Fart"
local BUTTON_INPUT = "Button" -- what PressFart counts an on-screen button as
local BUTT_ATTACHMENT_NAME = "FartButt"
local FART_CLOUD_NAME = "FartCloud"
local FART_SOUNDS_NAME = "Farts"

local localPlayer = Players.LocalPlayer

-- One player's fart that's happening right now, and its effects.
type Stream = {
	Emitter: ParticleEmitter?,
	Sound: Sound?,
	BasePitch: number,
}

local FartServiceClient = {}

type FartServiceClientMembers = {
	HeldInputs: { [string]: boolean }, -- the fart keys and buttons the local player is holding down
	IsLocalFarting: boolean,
	Streams: { [Player]: Stream }, -- everyone farting right now, the local player included
	RampTimes: { [Player]: number }, -- how far each player's fart has built up, the same way the server works it out
	Random: Random,
	FartCloudTemplate: ParticleEmitter?,
	FartSounds: { Sound },
	RequestStartFartRemote: RemoteEvent?, -- set once the server has created it
	RequestStopFartRemote: RemoteEvent?,
	FartStarted: Signal.Signal, -- fires () when the local player starts farting
	FartStopped: Signal.Signal, -- fires () when the local player stops farting
}

export type FartServiceClient = typeof(FartServiceClient) & FartServiceClientMembers

-- True while the local player hangs on to a boat that's on the river, or is swimming
-- back to theirs.
local function CanFart(): boolean
	if OverboardServiceShared.GetState(localPlayer) == "Swimming" then
		return true
	end
	local character = localPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local seat = if humanoid then humanoid.SeatPart else nil
	local boatModel = if seat then BoatServiceShared.GetBoatModelFromPart(seat) else nil
	return boatModel ~= nil and boatModel:GetAttribute(BoatServiceShared.STATE_ATTRIBUTE) == "Launched"
end

local function GetLocalGas(): number
	local gas = localPlayer:GetAttribute(FartServiceShared.GAS_ATTRIBUTE)
	return if typeof(gas) == "number" then gas else 0
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
	self.HeldInputs = {}
	self.IsLocalFarting = false
	self.Streams = {}
	self.RampTimes = {}
	self.Random = Random.new()
	self.RequestStartFartRemote = nil
	self.RequestStopFartRemote = nil
	self.FartStarted = Signal.new()
	self.FartStopped = Signal.new()
	self.FartCloudTemplate, self.FartSounds = FindAssets()

	ContextActionService:BindAction(
		FART_ACTION,
		function(_actionName: string, inputState: Enum.UserInputState, input: InputObject)
			local inputName = input.KeyCode.Name
			if inputState == Enum.UserInputState.Begin then
				if not CanFart() then
					-- Not on the river: let the keys do their normal job (like walking).
					return Enum.ContextActionResult.Pass
				end
				self:PressFart(inputName)
				return Enum.ContextActionResult.Sink
			end
			-- Letting go: only take it if the press was a fart, so walking keys still let go normally.
			if not self.HeldInputs[inputName] then
				return Enum.ContextActionResult.Pass
			end
			self:ReleaseFart(inputName)
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.KeyCode.W,
		Enum.KeyCode.Up,
		Enum.KeyCode.Space,
		Enum.KeyCode.ButtonR2
	)

	RunService.RenderStepped:Connect(function(deltaTime)
		self:Update(deltaTime)
	end)

	-- Remotes are waited for in a separate thread so Init never yields.
	task.spawn(function()
		self.RequestStartFartRemote = Remotes.WaitForEvent(SERVICE_NAME, FartServiceShared.REQUEST_START_FART)
		self.RequestStopFartRemote = Remotes.WaitForEvent(SERVICE_NAME, FartServiceShared.REQUEST_STOP_FART)
		Remotes.WaitForEvent(SERVICE_NAME, FartServiceShared.PLAY_FART).OnClientEvent:Connect(function(farter: Player?)
			if farter then -- nil if they left before this arrived
				self:StartStream(farter)
			end
		end)
		Remotes.WaitForEvent(SERVICE_NAME, FartServiceShared.STOP_FART).OnClientEvent:Connect(function(farter: Player?)
			if farter == localPlayer then
				-- The server stopped our fart (out of gas, or we left the boat).
				table.clear(self.HeldInputs)
				self:SetLocalFarting(false)
			elseif farter then
				self:StopStream(farter)
			end
		end)
	end)
end

-- A fart key (or on-screen button, which can leave out `inputName`) went down.
function FartServiceClient.PressFart(self: FartServiceClient, inputName: string?)
	self.HeldInputs[inputName or BUTTON_INPUT] = true
	if self.IsLocalFarting then
		return
	end
	if GetLocalGas() < FartConfig.MIN_GAS_TO_START then
		self:PlayDudEffect(localPlayer)
		return
	end
	self:SetLocalFarting(true)
end

-- A fart key (or on-screen button) was let go: stop once nothing is holding the fart down.
function FartServiceClient.ReleaseFart(self: FartServiceClient, inputName: string?)
	self.HeldInputs[inputName or BUTTON_INPUT] = nil
	if next(self.HeldInputs) == nil then
		self:SetLocalFarting(false)
	end
end

-- Starts or stops the local player's fart, and tells the server.
function FartServiceClient.SetLocalFarting(self: FartServiceClient, isFarting: boolean)
	if isFarting == self.IsLocalFarting then
		return
	end
	local startRemote = self.RequestStartFartRemote
	local stopRemote = self.RequestStopFartRemote
	if not startRemote or not stopRemote then
		return -- the server hasn't set up yet
	end

	self.IsLocalFarting = isFarting
	if isFarting then
		self:StartStream(localPlayer)
		startRemote:FireServer()
		self.FartStarted:Fire()
	else
		self:StopStream(localPlayer)
		stopRemote:FireServer()
		self.FartStopped:Fire()
	end
end

-- Every frame: build up (or fade) everyone's fart strength, grow each fart's effects
-- with it, and stop the local fart if the player ran out of gas or can't fart any more
-- (knocked off their boat, say).
function FartServiceClient.Update(self: FartServiceClient, deltaTime: number)
	if self.IsLocalFarting and (GetLocalGas() <= 0 or not CanFart()) then
		table.clear(self.HeldInputs)
		self:SetLocalFarting(false)
	end

	for player, rampTime in self.RampTimes do
		if not self.Streams[player] then
			local fadedRampTime = FartPhysics.UpdateRampTime(rampTime, false, deltaTime)
			if fadedRampTime > 0 and player.Parent then
				self.RampTimes[player] = fadedRampTime
			else
				self.RampTimes[player] = nil
			end
		end
	end
	for player, stream in self.Streams do
		if not player.Parent then
			self:StopStream(player)
			self.RampTimes[player] = nil
			continue
		end
		local rampTime = FartPhysics.UpdateRampTime(self.RampTimes[player] or 0, true, deltaTime)
		self.RampTimes[player] = rampTime

		local progress = FartPhysics.GetRampProgress(rampTime)
		local emitter = stream.Emitter
		local template = self.FartCloudTemplate
		if emitter and template then
			local speedMultiplier = 1 + (FartConfig.MAX_PARTICLE_SPEED_MULTIPLIER - 1) * progress
			emitter.Rate = FartConfig.MIN_PARTICLE_RATE
				+ (FartConfig.MAX_PARTICLE_RATE - FartConfig.MIN_PARTICLE_RATE) * progress
			emitter.Speed = NumberRange.new(template.Speed.Min * speedMultiplier, template.Speed.Max * speedMultiplier)
		end
		local sound = stream.Sound
		if sound then
			sound.PlaybackSpeed = stream.BasePitch * (1 + FartConfig.PITCH_RISE * progress)
			sound.Volume = FartConfig.STREAM_VOLUME
				+ (FartConfig.MAX_STREAM_VOLUME - FartConfig.STREAM_VOLUME) * progress
		end
	end
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

-- Starts `player`'s fart effects: a steady gas cloud and a looping sound.
function FartServiceClient.StartStream(self: FartServiceClient, player: Player)
	if self.Streams[player] then
		return
	end
	local butt, emitter = self:GetButt(player)
	if not butt then
		return
	end
	if emitter then
		emitter.Enabled = true
	end

	local sound: Sound? = nil
	local basePitch = self.Random:NextNumber(FartConfig.MIN_PITCH, FartConfig.MAX_PITCH)
	if #self.FartSounds > 0 then
		local newSound = self.FartSounds[self.Random:NextInteger(1, #self.FartSounds)]:Clone()
		newSound.Looped = true
		newSound.Volume = FartConfig.STREAM_VOLUME
		newSound.PlaybackSpeed = basePitch
		newSound.Parent = butt
		newSound:Play()
		sound = newSound
	end

	self.Streams[player] = {
		Emitter = emitter,
		Sound = sound,
		BasePitch = basePitch,
	}
end

function FartServiceClient.StopStream(self: FartServiceClient, player: Player)
	local stream = self.Streams[player]
	if not stream then
		return
	end
	self.Streams[player] = nil
	local emitter = stream.Emitter
	if emitter then
		emitter.Enabled = false
	end
	local sound = stream.Sound
	if sound then
		sound:Stop()
		sound:Destroy()
	end
end

-- Not enough gas: a sad little puff.
function FartServiceClient.PlayDudEffect(self: FartServiceClient, player: Player)
	local butt, emitter = self:GetButt(player)
	if not butt then
		return
	end
	if self.Streams[player] then
		return -- already farting; the stream's effects are showing
	end
	local template = self.FartCloudTemplate
	if emitter and template then
		emitter.Speed = template.Speed
		emitter:Emit(FartConfig.DUD_PARTICLES)
	end
	if #self.FartSounds > 0 then
		local sound = self.FartSounds[self.Random:NextInteger(1, #self.FartSounds)]:Clone()
		sound.Volume = FartConfig.DUD_VOLUME
		sound.PlaybackSpeed = self.Random:NextNumber(FartConfig.MIN_PITCH, FartConfig.MAX_PITCH) * FartConfig.DUD_PITCH
		sound.Parent = butt
		sound:Play()
		Debris:AddItem(sound, FartConfig.DUD_SOUND_LIFETIME)
	end
end

return FartServiceClient :: FartServiceClient
