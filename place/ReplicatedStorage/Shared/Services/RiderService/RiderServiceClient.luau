--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.RiderService.RiderServiceClient
--
-- Poses every player riding a boat, on this player's screen. Riders hang on to the
-- outside of their boat (the server puts them there; see the Boat class), and this gives
-- them the pose to match: arms reaching over the side, legs kicking in the water, and
-- their whole body twisted round to aim their butt the way they're farting
-- (FartServiceClient:GetAimAngle). It overrides their animation every frame, so it
-- needs no animation assets, and works for R15 and R6 characters. All the angles are in
-- RiderConfig.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BoatServiceShared = require(ReplicatedStorage.Shared.Services.BoatService.BoatServiceShared)
local FartServiceClient = require(ReplicatedStorage.Shared.Services.FartService.FartServiceClient)
local RiderConfig = require(ReplicatedStorage.Shared.Modules.Game.RiderConfig)

-- The joints a rider is posed by, by what they do (Root turns the whole body).
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

local RiderServiceClient = {}

type RiderServiceClientMembers = {
	Rigs: { [Model]: Rig }, -- each rider's joints, found the first time they're posed
}

export type RiderServiceClient = typeof(RiderServiceClient) & RiderServiceClientMembers

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
	self.Rigs = setmetatable({}, { __mode = "k" }) :: any

	-- After animations are applied each frame, so the pose wins over the sitting animation.
	RunService.PreSimulation:Connect(function()
		self:Update()
	end)
end

function RiderServiceClient.Update(self: RiderServiceClient)
	local time = os.clock()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local seat = if humanoid then humanoid.SeatPart else nil
		if character and humanoid and seat and BoatServiceShared.GetBoatModelFromPart(seat) then
			-- Found again if the character was rebuilt (its joints replaced)
			local cachedRig = self.Rigs[character]
			local cachedRoot = if cachedRig then cachedRig.Root else nil
			local isStale = cachedRoot ~= nil and cachedRoot.Parent == nil
			local rig: Rig = if cachedRig and not isStale then cachedRig else FindRig(character, humanoid)
			self.Rigs[character] = rig
			self:PoseRider(player, rig, time)
		end
	end
end

-- Poses one rider hanging on to their boat.
function RiderServiceClient.PoseRider(self: RiderServiceClient, player: Player, rig: Rig, time: number)
	-- Twisted round to aim their butt
	PoseJoint(rig.Root, CFrame.Angles(0, FartServiceClient:GetAimAngle(player), 0))

	-- Arms reaching forward over the side of the boat
	local armReach = CFrame.Angles(RiderConfig.ARM_REACH, 0, 0)
	PoseJoint(rig.RightShoulder, armReach)
	PoseJoint(rig.LeftShoulder, armReach)
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
