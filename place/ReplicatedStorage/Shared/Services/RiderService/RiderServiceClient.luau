--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.RiderService.RiderServiceClient
--
-- The client half of RiderService. Riders hang on to the outside of their boat (the
-- server puts them there; see the Boat class).
--
-- Sliding: hold a slide key to slide round the edge of your boat, within your own
-- stretch of it.
--   Slide left    A, Left arrow, Q, LB, or the left stick pushed left
--   Slide right   D, Right arrow, E, RB, or the left stick pushed right
-- If you hold both, the one you pressed last wins. On-screen buttons for touch devices
-- (UI, to be built) call PressSlide and ReleaseSlide.
-- The server decides where everyone is (RiderServiceServer), but your own slide shows
-- straight away: this runs the same rules (RiderSpots) and settles onto the server's
-- answer once you stop. Other riders glide smoothly to where the server has them.
--
-- Posing: every player hanging on to a boat is posed on this player's screen: arms
-- reaching over the side (going hand over hand while they slide) and legs kicking in
-- the water. It overrides their animation every frame, so it needs no animation assets,
-- and works for R15 and R6 characters. All the angles are in RiderConfig.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BoatServiceShared = require(ReplicatedStorage.Shared.Services.BoatService.BoatServiceShared)
local Remotes = require(ReplicatedStorage.Shared.Modules.Core.Remotes)
local RiderConfig = require(ReplicatedStorage.Shared.Modules.Game.RiderConfig)
local RiderServiceShared = require(ReplicatedStorage.Shared.Services.RiderService.RiderServiceShared)
local RiderSpots = require(ReplicatedStorage.Shared.Services.RiderService.RiderSpots)

export type Side = "Left" | "Right"

local SLIDE_ACTIONS: { [string]: Side } = {
	SlideLeft = "Left",
	SlideRight = "Right",
}
local SIDE_DIRECTIONS: { [Side]: number } = {
	Left = -1,
	Right = 1,
}
local STICK_INPUT = "Thumbstick1" -- what the left stick counts as among the held slide inputs
local MIN_SLIDE_SPEED = 0.01 -- a slide that has eased below this (studs/s) has stopped

-- The joints a rider is posed by, by what they do.
type Rig = { [string]: Motor6D }

-- Where each joint is, as { the part it's in, its name }.
local R15_JOINTS: { [string]: { string } } = {
	Root = { "LowerTorso", "Root" },
	RightShoulder = { "RightUpperArm", "RightShoulder" },
	LeftShoulder = { "LeftUpperArm", "LeftShoulder" },
	RightElbow = { "RightLowerArm", "RightElbow" },
	LeftElbow = { "LeftLowerArm", "LeftElbow" },
	RightHip = { "RightUpperLeg", "RightHip" },
	LeftHip = { "LeftUpperLeg", "LeftHip" },
	RightKnee = { "RightLowerLeg", "RightKnee" },
	LeftKnee = { "LeftLowerLeg", "LeftKnee" },
}
local R6_JOINTS: { [string]: { string } } = {
	Root = { "HumanoidRootPart", "RootJoint" },
	RightShoulder = { "Torso", "Right Shoulder" },
	LeftShoulder = { "Torso", "Left Shoulder" },
	RightHip = { "Torso", "Right Hip" },
	LeftHip = { "Torso", "Left Hip" },
}

-- Where a seat's rider is shown, and who that is (so a new rider starts fresh).
type ShownAngle = {
	Rider: Player,
	Angle: number, -- radians round from the seat
}

-- What a rider's pose remembers between frames.
type Rider = {
	Rig: Rig,
	LastAngle: number?, -- where they were round their boat last frame (radians)
	ShimmyPhase: number, -- how far through a hand-over-hand they are (radians)
}

local localPlayer = Players.LocalPlayer

local RiderServiceClient = {}

type RiderServiceClientMembers = {
	HeldSlides: { { Input: string, Side: Side } }, -- slide keys and buttons held down, in the order pressed
	SlideDirection: number, -- what the server was last asked: -1 left, 1 right, 0 not sliding
	RequestSlideRemote: RemoteEvent?, -- set once the server has created it
	Riders: { [Model]: Rider }, -- each rider's pose state, by character
	BoatSpots: { [Model]: { [BasePart]: RiderSpots.RiderSpot } }, -- each boat's rider spots, worked out once
	ShownAngles: { [BasePart]: ShownAngle }, -- how far round from each seat its rider is shown
	LocalSeat: BasePart?, -- the seat the local player's own slide is being worked out from
	LocalAngle: number, -- where the local player is shown, ahead of the server
	LocalSpeed: number,
}

export type RiderServiceClient = typeof(RiderServiceClient) & RiderServiceClientMembers

-- The seat `character` is hanging on at, if it's a boat's.
local function GetBoatSeat(character: Model?): (Humanoid?, BasePart?, Model?)
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local seat = if humanoid then humanoid.SeatPart else nil
	local boatModel = if seat then BoatServiceShared.GetBoatModelFromPart(seat) else nil
	if not humanoid or not seat or not boatModel then
		return nil, nil, nil
	end
	return humanoid, seat, boatModel
end

-- `character`'s joints for posing.
local function FindRig(character: Model, humanoid: Humanoid): Rig
	local jointPlaces: { [string]: { string } } = if humanoid.RigType == Enum.HumanoidRigType.R15
		then R15_JOINTS
		else R6_JOINTS
	local rig: Rig = {}
	for role, place in jointPlaces do
		local part = character:FindFirstChild(place[1])
		local joint = if part then part:FindFirstChild(place[2]) else nil
		if joint and joint:IsA("Motor6D") then
			rig[role] = joint
		end
	end
	return rig
end

-- Turns the part below `joint` by `rotation`, given in the axes of the part above it,
-- about the joint itself. (A joint's own axes are its C0's; this converts into them.)
local function PoseJoint(joint: Motor6D?, rotation: CFrame)
	if joint then
		local jointRotation = joint.C0.Rotation
		joint.Transform = jointRotation:Inverse() * rotation * jointRotation
	end
end

function RiderServiceClient.Init(self: RiderServiceClient)
	self.HeldSlides = {}
	self.SlideDirection = 0
	self.RequestSlideRemote = nil
	self.Riders = setmetatable({}, { __mode = "k" }) :: any
	self.BoatSpots = setmetatable({}, { __mode = "k" }) :: any
	self.ShownAngles = setmetatable({}, { __mode = "k" }) :: any
	self.LocalSeat = nil
	self.LocalAngle = 0
	self.LocalSpeed = 0

	local function OnSlideAction(actionName: string, inputState: Enum.UserInputState, input: InputObject)
		local side: Side? = SLIDE_ACTIONS[actionName]
		if not side then
			return Enum.ContextActionResult.Pass
		end
		local inputName = input.KeyCode.Name
		if inputState == Enum.UserInputState.Begin then
			local _, seat = GetBoatSeat(localPlayer.Character)
			if not seat then
				-- Not hanging on to a boat: let the keys do their normal job (like walking).
				return Enum.ContextActionResult.Pass
			end
			self:PressSlide(side, inputName)
			return Enum.ContextActionResult.Sink
		end
		-- Letting go: only take it if the press was a slide, so walking keys still let go normally.
		for _, held in self.HeldSlides do
			if held.Input == inputName then
				self:ReleaseSlide(side, inputName)
				return Enum.ContextActionResult.Sink
			end
		end
		return Enum.ContextActionResult.Pass
	end
	ContextActionService:BindAction(
		"SlideLeft",
		OnSlideAction,
		false,
		Enum.KeyCode.A,
		Enum.KeyCode.Left,
		Enum.KeyCode.Q,
		Enum.KeyCode.ButtonL1
	)
	ContextActionService:BindAction(
		"SlideRight",
		OnSlideAction,
		false,
		Enum.KeyCode.D,
		Enum.KeyCode.Right,
		Enum.KeyCode.E,
		Enum.KeyCode.ButtonR1
	)
	ContextActionService:BindAction("SlideStick", function(_actionName, _inputState, input: InputObject)
		local _, seat = GetBoatSeat(localPlayer.Character)
		local x = input.Position.X
		local side: Side? = if not seat
			then nil
			elseif x <= -RiderConfig.STICK_DEADZONE then "Left"
			elseif x >= RiderConfig.STICK_DEADZONE then "Right"
			else nil
		self:SetHeldSlide(STICK_INPUT, side)
		-- Let the stick do its normal job too (it doesn't walk while hanging on).
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Thumbstick1)

	-- After animations are applied each frame, so the pose wins over the sitting animation.
	RunService.PreSimulation:Connect(function(deltaTime)
		self:Update(deltaTime)
	end)

	-- The remote is waited for in a separate thread so Init never yields.
	task.spawn(function()
		self.RequestSlideRemote =
			Remotes.WaitForEvent(RiderServiceShared.SERVICE_NAME, RiderServiceShared.REQUEST_SLIDE)
	end)
end

-- A slide key (or on-screen button, which can leave out `inputName`) went down.
function RiderServiceClient.PressSlide(self: RiderServiceClient, side: Side, inputName: string?)
	self:SetHeldSlide(inputName or `Button{side}`, side)
end

-- A slide key (or on-screen button) was let go.
function RiderServiceClient.ReleaseSlide(self: RiderServiceClient, side: Side, inputName: string?)
	self:SetHeldSlide(inputName or `Button{side}`, nil)
end

-- Records that `input` is now holding a slide to `side`, or nothing (nil), and tells the
-- server if that changes which way to slide.
function RiderServiceClient.SetHeldSlide(self: RiderServiceClient, input: string, side: Side?)
	for index = #self.HeldSlides, 1, -1 do
		if self.HeldSlides[index].Input == input then
			if self.HeldSlides[index].Side == side then
				return -- already held that way
			end
			table.remove(self.HeldSlides, index)
		end
	end
	if side then
		table.insert(self.HeldSlides, { Input = input, Side = side })
	end
	self:UpdateSlideDirection()
end

-- Tells the server which way to slide (the last slide key pressed that's still held),
-- if that changed.
function RiderServiceClient.UpdateSlideDirection(self: RiderServiceClient)
	local lastHeld = self.HeldSlides[#self.HeldSlides]
	local direction = if lastHeld then SIDE_DIRECTIONS[lastHeld.Side] else 0
	local remote = self.RequestSlideRemote
	if direction == self.SlideDirection or not remote then
		return
	end
	self.SlideDirection = direction
	remote:FireServer(direction)
end

function RiderServiceClient.Update(self: RiderServiceClient, deltaTime: number)
	-- Got off the boat: stop sliding, and start fresh next time.
	local _, localSeat = GetBoatSeat(localPlayer.Character)
	if not localSeat then
		self.LocalSeat = nil
		if #self.HeldSlides > 0 then
			table.clear(self.HeldSlides)
			self:UpdateSlideDirection()
		end
	end

	local time = os.clock()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid, seat, boatModel = GetBoatSeat(character)
		if character and humanoid and seat and boatModel then
			self:PlaceRider(player, seat, boatModel, deltaTime)
			self:PoseRider(player, character, humanoid, boatModel, time)
		end
	end
end

-- Where riders on `boatModel` hang on and can slide, worked out once per boat.
function RiderServiceClient.GetSpot(self: RiderServiceClient, boatModel: Model, seat: BasePart): RiderSpots.RiderSpot?
	local spots = self.BoatSpots[boatModel]
	if spots and spots[seat] then
		return spots[seat]
	end
	local primaryPart = boatModel.PrimaryPart
	if not primaryPart then
		return nil
	end
	local seats: { BasePart } = {}
	for _, descendant in boatModel:GetDescendants() do
		if descendant:IsA("Seat") then
			table.insert(seats, descendant)
		end
	end
	local newSpots = RiderSpots.GetSpots(primaryPart.CFrame, seats)
	self.BoatSpots[boatModel] = newSpots
	return newSpots[seat]
end

-- Hangs `player` where they should be shown round `seat`: the local player straight
-- away (ahead of the server), everyone else gliding to where the server has them.
function RiderServiceClient.PlaceRider(
	self: RiderServiceClient,
	player: Player,
	seat: BasePart,
	boatModel: Model,
	deltaTime: number
)
	local spot = self:GetSpot(boatModel, seat)
	if not spot then
		return
	end
	local serverValue = seat:GetAttribute(RiderServiceShared.SLIDE_ANGLE_ATTRIBUTE)
	local serverAngle = if typeof(serverValue) == "number" then serverValue else 0

	local angle: number
	if player == localPlayer then
		angle = self:PredictLocalSlide(seat, spot, serverAngle, deltaTime)
	else
		local shown = self.ShownAngles[seat]
		local current = if shown and shown.Rider == player then shown.Angle else serverAngle
		local blend = if RiderConfig.OTHER_RIDER_SMOOTHING > 0
			then 1 - math.exp(-deltaTime / RiderConfig.OTHER_RIDER_SMOOTHING)
			else 1
		angle = current + RiderSpots.GetAngleDifference(current, serverAngle) * blend
	end
	self.ShownAngles[seat] = { Rider = player, Angle = angle }

	local seatWeld = seat:FindFirstChild("SeatWeld")
	if seatWeld and seatWeld:IsA("Weld") then
		seatWeld.C0 = RiderSpots.GetSeatWeldC0(spot, angle)
		seatWeld.C1 = CFrame.identity
	end
end

-- Moves the local player's own rider on by one frame with the same rules the server
-- uses, so their slide shows straight away. Once they stop, it settles onto where the
-- server has them; if it's ever far off (the server stopped them), it jumps there.
function RiderServiceClient.PredictLocalSlide(
	self: RiderServiceClient,
	seat: BasePart,
	spot: RiderSpots.RiderSpot,
	serverAngle: number,
	deltaTime: number
): number
	if self.LocalSeat ~= seat then
		self.LocalSeat = seat
		self.LocalAngle = serverAngle
		self.LocalSpeed = 0
	end
	local angle, speed = RiderSpots.StepSlide(spot, self.LocalAngle, self.LocalSpeed, self.SlideDirection, deltaTime)

	local offBy = RiderSpots.GetAngleDifference(angle, serverAngle)
	if math.abs(offBy) * math.max(spot.Radius, 1) > RiderConfig.SLIDE_SNAP_DISTANCE then
		angle = serverAngle
		speed = 0
	elseif self.SlideDirection == 0 and math.abs(speed) < MIN_SLIDE_SPEED then
		local blend = if RiderConfig.SLIDE_CORRECTION_TIME > 0
			then 1 - math.exp(-deltaTime / RiderConfig.SLIDE_CORRECTION_TIME)
			else 1
		angle += offBy * blend
	end
	self.LocalAngle = angle
	self.LocalSpeed = speed
	return angle
end

-- Poses one rider hanging on to their boat.
function RiderServiceClient.PoseRider(
	self: RiderServiceClient,
	player: Player,
	character: Model,
	humanoid: Humanoid,
	boatModel: Model,
	time: number
)
	-- Their joints, found again if the character was rebuilt
	local existingRider = self.Riders[character]
	local existingRoot = if existingRider then existingRider.Rig.Root else nil
	local isStale = existingRoot ~= nil and existingRoot.Parent == nil
	local rider: Rider = if existingRider and not isStale
		then existingRider
		else { Rig = FindRig(character, humanoid), LastAngle = nil, ShimmyPhase = 0 }
	self.Riders[character] = rider
	local rig = rider.Rig

	-- How far they slid round the boat since last frame moves their hands along.
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local primaryPart = boatModel.PrimaryPart
	if rootPart and rootPart:IsA("BasePart") and primaryPart then
		local offset = primaryPart.CFrame:PointToObjectSpace(rootPart.Position)
		local angle = math.atan2(offset.X, offset.Z)
		local lastAngle = rider.LastAngle
		if lastAngle then
			local turned = (angle - lastAngle + math.pi) % (2 * math.pi) - math.pi
			local distance = turned * Vector3.new(offset.X, 0, offset.Z).Magnitude
			if RiderConfig.SHIMMY_STRIDE > 0 then
				rider.ShimmyPhase += distance / RiderConfig.SHIMMY_STRIDE * 2 * math.pi
			end
		end
		rider.LastAngle = angle
	end

	-- Upright, facing the boat (undoing the sitting animation)
	PoseJoint(rig.Root, CFrame.identity)

	-- Arms reaching forward over the side of the boat, hand over hand as they slide
	local shimmy = math.sin(rider.ShimmyPhase) * RiderConfig.SHIMMY_ANGLE
	PoseJoint(rig.RightShoulder, CFrame.Angles(RiderConfig.ARM_REACH + shimmy, 0, 0))
	PoseJoint(rig.LeftShoulder, CFrame.Angles(RiderConfig.ARM_REACH - shimmy, 0, 0))
	local elbowBend = CFrame.Angles(RiderConfig.ELBOW_BEND, 0, 0)
	PoseJoint(rig.RightElbow, elbowBend)
	PoseJoint(rig.LeftElbow, elbowBend)

	-- Legs hanging in the water, kicking (each rider at their own beat)
	local kick = math.sin(time * RiderConfig.KICK_SPEED + player.UserId % 10) * RiderConfig.KICK_ANGLE
	PoseJoint(rig.RightHip, CFrame.Angles(kick, 0, 0))
	PoseJoint(rig.LeftHip, CFrame.Angles(-kick, 0, 0))
	local kneeBend = CFrame.Angles(-RiderConfig.KNEE_BEND, 0, 0)
	PoseJoint(rig.RightKnee, kneeBend)
	PoseJoint(rig.LeftKnee, kneeBend)
end

return RiderServiceClient :: RiderServiceClient
