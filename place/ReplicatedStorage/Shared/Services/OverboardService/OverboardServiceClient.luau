--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.OverboardService.OverboardServiceClient
--
-- The client half of OverboardService. Riders who get knocked off their boat go limp for
-- a moment, then have to swim back to it and grab on along their own stretch of its edge
-- (the server decides all of that; see OverboardServiceServer).
--
-- Swimming: farting pushes you the way you face (FartService: W, Up arrow, Space or RT,
-- with the same gas), and you turn with
--   Turn left     A, Left arrow, Q, LB, or the left stick pushed left
--   Turn right    D, Right arrow, E, RB, or the left stick pushed right
-- If you hold both, the one you pressed last wins. On-screen buttons for touch devices
-- (UI, to be built) call PressTurn and ReleaseTurn. The server does the turning.
--
-- Posing: every swimmer is posed on this player's screen, doggy-paddling: leaning forward
-- with their arms paddling and legs kicking. It overrides their animation every frame,
-- so it needs no animation assets. Knocked-out players are limp (that's physics) and
-- show a dazed effect over their head. All the angles are in OverboardConfig.
--
-- For the UI: StateChanged fires (state: OverboardState?) when the local player is knocked
-- out, starts swimming, or is back aboard (nil). LeftBehind fires (reason:
-- LeftBehindReason) when they didn't make it back and are sent to their checkpoint.
-- GetSecondsUntilWake and GetSecondsUntilGiveUp are for countdowns.
--
-- Asset contract:
--   ReplicatedStorage.Assets.VFX.Dazed   ParticleEmitter (optional): shown over a knocked-out
--                                        player's head (in an attachment at the top of it)

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local OverboardConfig = require(ReplicatedStorage.Shared.Modules.Game.OverboardConfig)
local OverboardServiceShared = require(ReplicatedStorage.Shared.Services.OverboardService.OverboardServiceShared)
local Remotes = require(ReplicatedStorage.Shared.Modules.Core.Remotes)
local RigPose = require(ReplicatedStorage.Packages.RigPose)
local Signal = require(ReplicatedStorage.Packages.Signal)

export type Side = "Left" | "Right"

local SERVICE_NAME = OverboardServiceShared.SERVICE_NAME
local TURN_ACTIONS: { [string]: Side } = {
	SwimTurnLeft = "Left",
	SwimTurnRight = "Right",
}
local SIDE_DIRECTIONS: { [Side]: number } = {
	Left = -1,
	Right = 1,
}
local STICK_INPUT = "Thumbstick1" -- what the left stick counts as among the held turn inputs
local DAZED_NAME = "Dazed"

local localPlayer = Players.LocalPlayer

local OverboardServiceClient = {}

type OverboardServiceClientMembers = {
	HeldTurns: { { Input: string, Side: Side } }, -- turn keys and buttons held down, in the order pressed
	TurnDirection: number, -- what the server was last asked: -1 left, 1 right, 0 not turning
	RequestSwimTurnRemote: RemoteEvent?, -- set once the server has created it
	Rigs: { [Model]: RigPose.Rig }, -- each swimmer's joints, by character
	DazedEffects: { [Player]: Attachment }, -- the dazed effect over each knocked-out player's head
	DazedTemplate: ParticleEmitter?,
	StateChanged: Signal.Signal, -- fires (state: OverboardServiceShared.OverboardState?) when the local player's changes
	LeftBehind: Signal.Signal, -- fires (reason: OverboardServiceShared.LeftBehindReason) when the local player didn't make it back
}

export type OverboardServiceClient = typeof(OverboardServiceClient) & OverboardServiceClientMembers

local function IsLocalSwimming(): boolean
	return OverboardServiceShared.GetState(localPlayer) == "Swimming"
end

local function FindDazedTemplate(): ParticleEmitter?
	local vfxFolder = ReplicatedStorage.Assets:FindFirstChild("VFX")
	local dazed = if vfxFolder then vfxFolder:FindFirstChild(DAZED_NAME) else nil
	if dazed and dazed:IsA("ParticleEmitter") then
		return dazed
	end
	warn(
		`Asset missing: ReplicatedStorage.Assets.VFX.{DAZED_NAME} (a ParticleEmitter). Knocked-out players won't show it.`
	)
	return nil
end

-- Seconds until server time attribute `name` on the local player, or nil if it isn't set.
local function GetSecondsUntil(name: string): number?
	local serverTime = localPlayer:GetAttribute(name)
	if typeof(serverTime) ~= "number" then
		return nil
	end
	return math.max(0, serverTime - workspace:GetServerTimeNow())
end

function OverboardServiceClient.Init(self: OverboardServiceClient)
	self.HeldTurns = {}
	self.TurnDirection = 0
	self.RequestSwimTurnRemote = nil
	self.Rigs = setmetatable({}, { __mode = "k" }) :: any
	self.DazedEffects = {}
	self.DazedTemplate = FindDazedTemplate()
	self.StateChanged = Signal.new()
	self.LeftBehind = Signal.new()

	local function OnTurnAction(actionName: string, inputState: Enum.UserInputState, input: InputObject)
		local side: Side? = TURN_ACTIONS[actionName]
		if not side then
			return Enum.ContextActionResult.Pass
		end
		local inputName = input.KeyCode.Name
		if inputState == Enum.UserInputState.Begin then
			if not IsLocalSwimming() then
				-- Not swimming: let the keys do their normal job (like sliding or walking).
				return Enum.ContextActionResult.Pass
			end
			self:PressTurn(side, inputName)
			return Enum.ContextActionResult.Sink
		end
		-- Letting go: only take it if the press was a turn, so other keys still let go normally.
		for _, held in self.HeldTurns do
			if held.Input == inputName then
				self:ReleaseTurn(side, inputName)
				return Enum.ContextActionResult.Sink
			end
		end
		return Enum.ContextActionResult.Pass
	end
	ContextActionService:BindAction(
		"SwimTurnLeft",
		OnTurnAction,
		false,
		Enum.KeyCode.A,
		Enum.KeyCode.Left,
		Enum.KeyCode.Q,
		Enum.KeyCode.ButtonL1
	)
	ContextActionService:BindAction(
		"SwimTurnRight",
		OnTurnAction,
		false,
		Enum.KeyCode.D,
		Enum.KeyCode.Right,
		Enum.KeyCode.E,
		Enum.KeyCode.ButtonR1
	)
	ContextActionService:BindAction("SwimTurnStick", function(_actionName, _inputState, input: InputObject)
		local x = input.Position.X
		local side: Side? = if not IsLocalSwimming()
			then nil
			elseif x <= -OverboardConfig.STICK_DEADZONE then "Left"
			elseif x >= OverboardConfig.STICK_DEADZONE then "Right"
			else nil
		self:SetHeldTurn(STICK_INPUT, side)
		-- Let the stick do its normal job too (it doesn't walk while swimming).
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Thumbstick1)

	localPlayer:GetAttributeChangedSignal(OverboardServiceShared.STATE_ATTRIBUTE):Connect(function()
		local state = OverboardServiceShared.GetState(localPlayer)
		if state ~= "Swimming" and #self.HeldTurns > 0 then
			table.clear(self.HeldTurns)
			self:UpdateTurnDirection()
		end
		self.StateChanged:Fire(state)
	end)

	-- After animations are applied each frame, so the pose wins over them.
	RunService.PreSimulation:Connect(function()
		self:Update()
	end)

	-- Remotes are waited for in a separate thread so Init never yields.
	task.spawn(function()
		self.RequestSwimTurnRemote = Remotes.WaitForEvent(SERVICE_NAME, OverboardServiceShared.REQUEST_SWIM_TURN)
		Remotes.WaitForEvent(SERVICE_NAME, OverboardServiceShared.NOTIFY_LEFT_BEHIND).OnClientEvent
			:Connect(function(reason: OverboardServiceShared.LeftBehindReason)
				self.LeftBehind:Fire(reason)
			end)
	end)
end

-- A turn key (or on-screen button, which can leave out `inputName`) went down.
function OverboardServiceClient.PressTurn(self: OverboardServiceClient, side: Side, inputName: string?)
	if IsLocalSwimming() then
		self:SetHeldTurn(inputName or `Button{side}`, side)
	end
end

-- A turn key (or on-screen button) was let go.
function OverboardServiceClient.ReleaseTurn(self: OverboardServiceClient, side: Side, inputName: string?)
	self:SetHeldTurn(inputName or `Button{side}`, nil)
end

-- Records that `input` is now holding a turn to `side`, or nothing (nil), and tells the
-- server if that changes which way to turn.
function OverboardServiceClient.SetHeldTurn(self: OverboardServiceClient, input: string, side: Side?)
	for index = #self.HeldTurns, 1, -1 do
		if self.HeldTurns[index].Input == input then
			if self.HeldTurns[index].Side == side then
				return -- already held that way
			end
			table.remove(self.HeldTurns, index)
		end
	end
	if side then
		table.insert(self.HeldTurns, { Input = input, Side = side })
	end
	self:UpdateTurnDirection()
end

-- Tells the server which way to turn (the last turn key pressed that's still held), if
-- that changed.
function OverboardServiceClient.UpdateTurnDirection(self: OverboardServiceClient)
	local lastHeld = self.HeldTurns[#self.HeldTurns]
	local direction = if lastHeld then SIDE_DIRECTIONS[lastHeld.Side] else 0
	local remote = self.RequestSwimTurnRemote
	if direction == self.TurnDirection or not remote then
		return
	end
	self.TurnDirection = direction
	remote:FireServer(direction)
end

-- Seconds until the local player comes round, or nil if they aren't knocked out.
function OverboardServiceClient.GetSecondsUntilWake(self: OverboardServiceClient): number?
	return GetSecondsUntil(OverboardServiceShared.WAKE_TIME_ATTRIBUTE)
end

-- Seconds the local player has left to get back aboard, or nil if they aren't swimming.
function OverboardServiceClient.GetSecondsUntilGiveUp(self: OverboardServiceClient): number?
	return GetSecondsUntil(OverboardServiceShared.GIVE_UP_TIME_ATTRIBUTE)
end

function OverboardServiceClient.Update(self: OverboardServiceClient)
	local time = os.clock()
	for _, player in Players:GetPlayers() do
		local state = OverboardServiceShared.GetState(player)
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if state == "Swimming" and character and humanoid then
			self:PoseSwimmer(player, character, humanoid, time)
		end
		self:SetDazed(player, state == "KnockedOut")
	end
	for player in self.DazedEffects do
		if not player.Parent then
			self:SetDazed(player, false)
		end
	end
end

-- Poses one swimmer, doggy-paddling.
function OverboardServiceClient.PoseSwimmer(
	self: OverboardServiceClient,
	player: Player,
	character: Model,
	humanoid: Humanoid,
	time: number
)
	local existingRig = self.Rigs[character]
	local rig: RigPose.Rig = if existingRig and RigPose.IsCurrent(existingRig)
		then existingRig
		else RigPose.FindRig(character, humanoid)
	self.Rigs[character] = rig
	local beat = time + player.UserId % 10 -- each swimmer at their own beat

	-- Leaning forward into the water
	RigPose.PoseJoint(rig.Root, CFrame.Angles(-OverboardConfig.SWIM_LEAN, 0, 0))

	-- Arms reaching forward and paddling, one after the other
	local paddle = math.sin(beat * OverboardConfig.PADDLE_SPEED) * OverboardConfig.PADDLE_ANGLE
	RigPose.PoseJoint(rig.RightShoulder, CFrame.Angles(OverboardConfig.PADDLE_REACH + paddle, 0, 0))
	RigPose.PoseJoint(rig.LeftShoulder, CFrame.Angles(OverboardConfig.PADDLE_REACH - paddle, 0, 0))
	local elbowBend = CFrame.Angles(OverboardConfig.ELBOW_BEND, 0, 0)
	RigPose.PoseJoint(rig.RightElbow, elbowBend)
	RigPose.PoseJoint(rig.LeftElbow, elbowBend)

	-- Legs kicking behind
	local kick = math.sin(beat * OverboardConfig.KICK_SPEED) * OverboardConfig.KICK_ANGLE
	RigPose.PoseJoint(rig.RightHip, CFrame.Angles(kick, 0, 0))
	RigPose.PoseJoint(rig.LeftHip, CFrame.Angles(-kick, 0, 0))
	local kneeBend = CFrame.Angles(-OverboardConfig.KNEE_BEND, 0, 0)
	RigPose.PoseJoint(rig.RightKnee, kneeBend)
	RigPose.PoseJoint(rig.LeftKnee, kneeBend)
end

-- Shows or hides the dazed effect over `player`'s head.
function OverboardServiceClient.SetDazed(self: OverboardServiceClient, player: Player, isDazed: boolean)
	local existing = self.DazedEffects[player]
	local character = player.Character
	local head = if character then character:FindFirstChild("Head") else nil
	if isDazed and existing and head and existing.Parent == head then
		return -- already showing
	end
	if existing then
		existing:Destroy()
		self.DazedEffects[player] = nil
	end
	local template = self.DazedTemplate
	if not isDazed or not template or not head or not head:IsA("BasePart") then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = DAZED_NAME
	attachment.Position = Vector3.new(0, head.Size.Y / 2, 0)
	template:Clone().Parent = attachment
	attachment.Parent = head
	self.DazedEffects[player] = attachment
end

return OverboardServiceClient :: OverboardServiceClient
