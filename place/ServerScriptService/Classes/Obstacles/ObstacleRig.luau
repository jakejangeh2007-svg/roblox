--!strict
-- ModuleScript: ServerScriptService.Classes.Obstacles.ObstacleRig
--
-- Gets an obstacle Model ready to move, for the Spinner, Swinger, Slider and WindFan
-- classes. It finds the obstacle's Base (the fixed part) and Moving (the part that
-- moves, with everything welded to it), joins them with a physics constraint that the
-- obstacle class drives, and hands the moving parts to physics. The server runs that
-- physics, so obstacles shove boats properly and move smoothly for every player.
--
-- Spinners, Swingers and WindFans turn around the line through the middle of Base along
-- its front face; Sliders slide along its front face. Their moving parts and Base are put
-- in the Obstacles collision group, so they hit boats but pass through the map and each
-- other. Any other parts in the Model are scenery and stay as they are.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ObstacleServiceShared = require(ReplicatedStorage.Shared.Services.ObstacleService.ObstacleServiceShared)

local AXIS_ATTACHMENT_NAME = "ObstacleAxis"

local ObstacleRig = {}
ObstacleRig.__index = ObstacleRig

type ObstacleRigMembers = {
	Model: Model,
	Base: BasePart,
	Moving: BasePart,
	MovingParts: { BasePart }, -- Moving and everything welded to it
	AxisCFrame: CFrame, -- through the middle of Base, its X axis along Base's front face
}

export type ObstacleRig = typeof(setmetatable({} :: ObstacleRigMembers, ObstacleRig))

-- Every part in `model` welded to `start`, directly or through other welded parts,
-- `start` included.
local function GetWeldedParts(model: Model, start: BasePart): { [BasePart]: boolean }
	local neighbors: { [BasePart]: { BasePart } } = {}
	local function Link(first: BasePart, second: BasePart)
		local list = neighbors[first] or {}
		neighbors[first] = list
		table.insert(list, second)
	end
	for _, descendant in model:GetDescendants() do
		local part0: BasePart?, part1: BasePart? = nil, nil
		if descendant:IsA("WeldConstraint") or descendant:IsA("JointInstance") then
			part0, part1 = descendant.Part0, descendant.Part1
		end
		if part0 and part1 and part0:IsDescendantOf(model) and part1:IsDescendantOf(model) then
			Link(part0, part1)
			Link(part1, part0)
		end
	end

	local reached: { [BasePart]: boolean } = { [start] = true }
	local toVisit = { start }
	while #toVisit > 0 do
		local part = table.remove(toVisit) :: BasePart
		local partNeighbors: { BasePart } = neighbors[part] or {}
		for _, neighbor in partNeighbors do
			if not reached[neighbor] then
				reached[neighbor] = true
				table.insert(toVisit, neighbor)
			end
		end
	end
	return reached
end

-- An attachment in `part` at `worldCFrame`.
local function MakeAttachment(part: BasePart, worldCFrame: CFrame): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = AXIS_ATTACHMENT_NAME
	attachment.CFrame = part.CFrame:ToObjectSpace(worldCFrame)
	attachment.Parent = part
	return attachment
end

-- Gets `model` ready, or returns a description of what's wrong with it.
function ObstacleRig.new(model: Model): (ObstacleRig?, string?)
	local base = model:FindFirstChild(ObstacleServiceShared.BASE_NAME)
	if not base or not base:IsA("BasePart") then
		return nil, `has no part named {ObstacleServiceShared.BASE_NAME}`
	end
	local moving = model:FindFirstChild(ObstacleServiceShared.MOVING_NAME)
	if not moving or not moving:IsA("BasePart") then
		return nil, `has no part named {ObstacleServiceShared.MOVING_NAME}`
	end
	local weldedParts = GetWeldedParts(model, moving)
	if weldedParts[base] then
		return nil,
			`has its {ObstacleServiceShared.MOVING_NAME} welded to its {ObstacleServiceShared.BASE_NAME}, so it can't move`
	end

	local movingParts = {}
	for part in weldedParts do
		part.CollisionGroup = ObstacleServiceShared.COLLISION_GROUP
		table.insert(movingParts, part)
	end
	base.Anchored = true
	base.CollisionGroup = ObstacleServiceShared.COLLISION_GROUP

	local axisCFrame = CFrame.fromMatrix(base.Position, base.CFrame.LookVector, base.CFrame.UpVector)
	return setmetatable(
		{
			Model = model,
			Base = base,
			Moving = moving,
			MovingParts = movingParts,
			AxisCFrame = axisCFrame,
		} :: ObstacleRigMembers,
		ObstacleRig
	),
		nil
end

-- A hinge that turns Moving around the axis. Its angle is 0 where Moving was built.
function ObstacleRig.AddHinge(self: ObstacleRig): HingeConstraint
	local hinge = Instance.new("HingeConstraint")
	hinge.Attachment0 = MakeAttachment(self.Base, self.AxisCFrame)
	hinge.Attachment1 = MakeAttachment(self.Moving, self.AxisCFrame)
	hinge.LimitsEnabled = false
	hinge.Parent = self.Base
	return hinge
end

-- A slider that moves Moving along the axis. Its position is 0 where Moving was built.
function ObstacleRig.AddPrismatic(self: ObstacleRig): PrismaticConstraint
	local prismatic = Instance.new("PrismaticConstraint")
	prismatic.Attachment0 = MakeAttachment(self.Base, self.AxisCFrame)
	prismatic.Attachment1 = MakeAttachment(self.Moving, self.AxisCFrame)
	prismatic.LimitsEnabled = false
	prismatic.Parent = self.Base
	return prismatic
end

-- Lets the moving parts move (call once the constraint is set up), with the server
-- running their physics.
function ObstacleRig.Release(self: ObstacleRig)
	for _, part in self.MovingParts do
		part.Anchored = false
	end
	local moving = self.Moving
	if moving:IsDescendantOf(workspace) and moving:CanSetNetworkOwnership() then
		moving:SetNetworkOwner(nil)
	end
end

return ObstacleRig
