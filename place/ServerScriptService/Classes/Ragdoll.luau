--!strict
-- ModuleScript: ServerScriptService.Classes.Ragdoll
--
-- Makes a character go limp, and back. Every Motor6D joint except the one holding the
-- HumanoidRootPart to the body is switched off and a ball-and-socket joint stands in for
-- it, so arms, legs and head flop around under physics. Each joint can only swing so far
-- from how the body was when it went limp (OverboardConfig), so limbs never bend the
-- wrong way. Works for R15 and R6 characters. The server should be running the
-- character's physics while it's limp (the Swimmer class makes sure of that).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OverboardConfig = require(ReplicatedStorage.Shared.Modules.Game.OverboardConfig)

local JOINT_NAME = "RagdollJoint"
local SPINE_JOINT_NAMES = { "Neck", "Waist" }
local MIN_LIMB_LENGTH = 0.05 -- a limb whose middle is closer than this to its joint (studs) hangs straight down

local Ragdoll = {}
Ragdoll.__index = Ragdoll

type RagdollMembers = {
	Humanoid: Humanoid,
	Motors: { Motor6D }, -- the joints switched off
	Joints: { Instance }, -- the ball-and-socket joints standing in for them, and their attachments
	RequiredNeck: boolean, -- what Humanoid.RequiresNeck was before (it's off while limp)
}

export type Ragdoll = typeof(setmetatable({} :: RagdollMembers, Ragdoll))

-- An attachment in `part` at `worldCFrame`.
local function MakeAttachment(part: BasePart, worldCFrame: CFrame): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = JOINT_NAME
	attachment.CFrame = part.CFrame:ToObjectSpace(worldCFrame)
	attachment.Parent = part
	return attachment
end

-- Swaps `motor` for a ball-and-socket joint where it is now. The joint's cone of swing
-- points along the limb, from the joint toward the middle of the part it moves.
local function MakeJoint(motor: Motor6D, part0: BasePart, part1: BasePart): { Instance }
	local jointPosition = (part0.CFrame * motor.C0).Position
	local limb = part1.Position - jointPosition
	local along = if limb.Magnitude >= MIN_LIMB_LENGTH then limb.Unit else -part0.CFrame.UpVector
	local reference = if math.abs(along:Dot(part0.CFrame.LookVector)) < 0.9
		then part0.CFrame.LookVector
		else part0.CFrame.UpVector
	local across = (reference - along * reference:Dot(along)).Unit
	local jointCFrame = CFrame.fromMatrix(jointPosition, along, across)

	local isSpine = table.find(SPINE_JOINT_NAMES, motor.Name) ~= nil
	local attachment0 = MakeAttachment(part0, jointCFrame)
	local attachment1 = MakeAttachment(part1, jointCFrame)
	local socket = Instance.new("BallSocketConstraint")
	socket.Name = JOINT_NAME
	socket.Attachment0 = attachment0
	socket.Attachment1 = attachment1
	socket.LimitsEnabled = true
	socket.UpperAngle = if isSpine then OverboardConfig.SPINE_SWING else OverboardConfig.LIMB_SWING
	socket.TwistLimitsEnabled = true
	socket.TwistLowerAngle = -OverboardConfig.JOINT_TWIST
	socket.TwistUpperAngle = OverboardConfig.JOINT_TWIST
	socket.Parent = part1
	return { socket, attachment0, attachment1 }
end

-- Makes `character` go limp now.
function Ragdoll.new(character: Model, humanoid: Humanoid): Ragdoll
	local rootPart = humanoid.RootPart
	local motors = {}
	local joints = {}
	for _, descendant in character:GetDescendants() do
		if not descendant:IsA("Motor6D") or not descendant.Enabled then
			continue
		end
		local part0, part1 = descendant.Part0, descendant.Part1
		if not part0 or not part1 or part0 == rootPart or part1 == rootPart then
			continue -- the HumanoidRootPart stays joined to the body
		end
		for _, joint in MakeJoint(descendant, part0, part1) do
			table.insert(joints, joint)
		end
		descendant.Enabled = false
		table.insert(motors, descendant)
	end

	local self = setmetatable(
		{
			Humanoid = humanoid,
			Motors = motors,
			Joints = joints,
			RequiredNeck = humanoid.RequiresNeck,
		} :: RagdollMembers,
		Ragdoll
	)
	-- A switched-off neck would otherwise count as a broken one, and kill them.
	humanoid.RequiresNeck = false
	return self
end

-- Stiffens the body back up: switches its joints back on and removes the stand-ins.
function Ragdoll.Destroy(self: Ragdoll)
	for _, joint in self.Joints do
		joint:Destroy()
	end
	table.clear(self.Joints)
	for _, motor in self.Motors do
		if motor.Parent then
			motor.Enabled = true
		end
	end
	table.clear(self.Motors)
	if self.Humanoid.Parent then
		self.Humanoid.RequiresNeck = self.RequiredNeck
	end
end

return Ragdoll
