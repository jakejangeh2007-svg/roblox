--!strict
-- ModuleScript: ServerScriptService.Classes.Obstacles.Slider
--
-- An obstacle that slides back and forth along a line, like a gate that opens and closes
-- or a patrolling spike ball. Its Moving part (and everything welded to it) slides along
-- its Base's front face: it waits where it was built, slides Distance studs, waits,
-- slides back, and so on, with nothing able to stop it. See ObstacleRig for the parts it
-- needs.
--
-- Settings (attributes on the Model, defaults in ObstacleConfig.SLIDER):
--   Distance     studs it slides toward Base's front face (negative slides the other way)
--   MoveTime     seconds to slide from one end to the other
--   HoldTime     seconds it waits at each end
--   StartDelay   seconds to shift its cycle by

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Attributes = require(ReplicatedStorage.Shared.Modules.Core.Attributes)
local Cycle = require(ReplicatedStorage.Shared.Modules.Math.Cycle)
local ObstacleConfig = require(ReplicatedStorage.Shared.Modules.Game.ObstacleConfig)
local ObstacleRig = require(ServerScriptService.Classes.Obstacles.ObstacleRig)

local MIN_MOVE_TIME = 0.05

local Slider = {}
Slider.__index = Slider

type SliderMembers = {
	Model: Model,
	Prismatic: PrismaticConstraint,
	Distance: number,
	MoveTime: number,
	HoldTime: number,
	StartDelay: number,
}

export type Slider = typeof(setmetatable({} :: SliderMembers, Slider))

-- Sets `model` sliding, or returns a description of what's wrong with it.
function Slider.new(model: Model): (Slider?, string?)
	local rig, problem = ObstacleRig.new(model)
	if not rig then
		return nil, problem
	end
	local defaults = ObstacleConfig.SLIDER
	local distance = Attributes.GetNumber(model, "Distance", defaults.Distance)
	local moveTime = math.max(Attributes.GetNumber(model, "MoveTime", defaults.MoveTime), MIN_MOVE_TIME)

	local prismatic = rig:AddPrismatic()
	prismatic.ActuatorType = Enum.ActuatorType.Servo
	prismatic.ServoMaxForce = math.huge
	prismatic.Speed = math.abs(distance) / moveTime
	prismatic.TargetPosition = 0
	rig:Release()

	return setmetatable(
		{
			Model = model,
			Prismatic = prismatic,
			Distance = distance,
			MoveTime = moveTime,
			HoldTime = math.max(Attributes.GetNumber(model, "HoldTime", defaults.HoldTime), 0),
			StartDelay = Attributes.GetNumber(model, "StartDelay", defaults.StartDelay),
		} :: SliderMembers,
		Slider
	),
		nil
end

-- Points the slider at the end it should be heading for at server time `serverTime`.
function Slider.Update(self: Slider, serverTime: number)
	local isHeadingToEnd = Cycle.IsHeadingToSecondEnd(serverTime, self.MoveTime, self.HoldTime, self.StartDelay)
	local targetPosition = if isHeadingToEnd then self.Distance else 0
	if self.Prismatic.TargetPosition ~= targetPosition then
		self.Prismatic.TargetPosition = targetPosition
	end
end

return Slider
