--!strict
-- ModuleScript: ReplicatedStorage.Packages.RigPose
--
-- Poses a character by hand, every frame, without animation assets: find its joints
-- once with FindRig, then turn each one with PoseJoint (on RunService.PreSimulation, so
-- the pose wins over whatever animation is playing). Works for R15 and R6 characters;
-- joints a rig doesn't have (like an R6's elbows) are skipped.

-- A character's joints, by what they do: Root, RightShoulder, LeftShoulder, RightElbow,
-- LeftElbow, RightHip, LeftHip, RightKnee, LeftKnee.
export type Rig = { [string]: Motor6D }

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

local RigPose = {}

-- `character`'s joints, found by `humanoid`'s rig type.
function RigPose.FindRig(character: Model, humanoid: Humanoid): Rig
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

-- Whether `rig`'s joints still belong to a character (it gets rebuilt when they respawn).
function RigPose.IsCurrent(rig: Rig): boolean
	local root = rig.Root
	if not root then
		return true
	end
	return root.Parent ~= nil
end

-- Turns the part below `joint` by `rotation`, given in the axes of the part above it,
-- about the joint itself. (A joint's own axes are its C0's; this converts into them.)
function RigPose.PoseJoint(joint: Motor6D?, rotation: CFrame)
	if joint then
		local jointRotation = joint.C0.Rotation
		joint.Transform = jointRotation:Inverse() * rotation * jointRotation
	end
end

return RigPose
