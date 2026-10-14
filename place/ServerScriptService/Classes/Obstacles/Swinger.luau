--!strict
-- ModuleScript: ServerScriptService.Classes.Obstacles.Swinger
--
-- An obstacle that swings back and forth between two angles on a hinge, like swinging
-- doors or a swinging spiked mace. Its Moving part (and everything welded to it) swings
-- around the line through the middle of its Base along Base's front face: it waits at
-- FromAngle, swings to ToAngle, waits, swings back, and so on, with nothing able to stop
-- it. See ObstacleRig for the parts it needs. Angles turn the right-hand way around
-- Base's front face (curl your right hand's fingers with your thumb along it).
--
-- Settings (attributes on the Model, defaults in ObstacleConfig.SWINGER):
--   FromAngle, ToAngle   degrees from how it was built (-180 to 180)
--   MoveTime             seconds to swing from one angle to the other
--   HoldTime             seconds it waits at each end
--   StartDelay           seconds to shift its cycle by

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Attributes = require(ReplicatedStorage.Shared.Modules.Core.Attributes)
local Cycle = require(ReplicatedStorage.Shared.Modules.Math.Cycle)
local ObstacleConfig = require(ReplicatedStorage.Shared.Modules.Game.ObstacleConfig)
local ObstacleRig = require(ServerScriptService.Classes.Obstacles.ObstacleRig)

local MIN_MOVE_TIME = 0.05

local Swinger = {}
Swinger.__index = Swinger

type SwingerMembers = {
	Model: Model,
	Hinge: HingeConstraint,
	FromAngle: number,
	ToAngle: number,
	MoveTime: number,
	HoldTime: number,
	StartDelay: number,
}

export type Swinger = typeof(setmetatable({} :: SwingerMembers, Swinger))

-- Sets `model` swinging, or returns a description of what's wrong with it.
function Swinger.new(model: Model): (Swinger?, string?)
	local rig, problem = ObstacleRig.new(model)
	if not rig then
		return nil, problem
	end
	local defaults = ObstacleConfig.SWINGER
	local fromAngle = math.clamp(Attributes.GetNumber(model, "FromAngle", defaults.FromAngle), -180, 180)
	local toAngle = math.clamp(Attributes.GetNumber(model, "ToAngle", defaults.ToAngle), -180, 180)
	local moveTime = math.max(Attributes.GetNumber(model, "MoveTime", defaults.MoveTime), MIN_MOVE_TIME)

	local hinge = rig:AddHinge()
	hinge.ActuatorType = Enum.ActuatorType.Servo
	hinge.ServoMaxTorque = math.huge
	hinge.AngularSpeed = math.rad(math.abs(toAngle - fromAngle)) / moveTime
	hinge.TargetAngle = fromAngle
	rig:Release()

	return setmetatable(
		{
			Model = model,
			Hinge = hinge,
			FromAngle = fromAngle,
			ToAngle = toAngle,
			MoveTime = moveTime,
			HoldTime = math.max(Attributes.GetNumber(model, "HoldTime", defaults.HoldTime), 0),
			StartDelay = Attributes.GetNumber(model, "StartDelay", defaults.StartDelay),
		} :: SwingerMembers,
		Swinger
	),
		nil
end

-- Points the hinge at the end it should be heading for at server time `serverTime`.
function Swinger.Update(self: Swinger, serverTime: number)
	local isHeadingToEnd = Cycle.IsHeadingToSecondEnd(serverTime, self.MoveTime, self.HoldTime, self.StartDelay)
	local targetAngle = if isHeadingToEnd then self.ToAngle else self.FromAngle
	if self.Hinge.TargetAngle ~= targetAngle then
		self.Hinge.TargetAngle = targetAngle
	end
end

return Swinger
