--!strict
-- ModuleScript: ServerScriptService.Classes.Obstacles.Spinner
--
-- An obstacle that turns round and round, like fan blades slicing the water or spinning
-- spike arms. Its Moving part (and everything welded to it) turns around the line
-- through the middle of its Base along Base's front face, at a steady speed nothing can
-- stop. See ObstacleRig for the parts it needs.
--
-- Settings (attributes on the Model, defaults in ObstacleConfig.SPINNER):
--   Speed   turns a minute; negative turns the other way

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Attributes = require(ReplicatedStorage.Shared.Modules.Core.Attributes)
local ObstacleConfig = require(ReplicatedStorage.Shared.Modules.Game.ObstacleConfig)
local ObstacleRig = require(ServerScriptService.Classes.Obstacles.ObstacleRig)

local Spinner = {}
Spinner.__index = Spinner

type SpinnerMembers = {
	Model: Model,
	Hinge: HingeConstraint,
}

export type Spinner = typeof(setmetatable({} :: SpinnerMembers, Spinner))

-- Sets `model` spinning, or returns a description of what's wrong with it.
function Spinner.new(model: Model): (Spinner?, string?)
	local rig, problem = ObstacleRig.new(model)
	if not rig then
		return nil, problem
	end
	local turnsPerMinute = Attributes.GetNumber(model, "Speed", ObstacleConfig.SPINNER.Speed)

	local hinge = rig:AddHinge()
	hinge.ActuatorType = Enum.ActuatorType.Motor
	hinge.MotorMaxTorque = math.huge
	hinge.MotorMaxAcceleration = math.huge
	hinge.AngularVelocity = turnsPerMinute * 2 * math.pi / 60
	rig:Release()

	return setmetatable({ Model = model, Hinge = hinge } :: SpinnerMembers, Spinner), nil
end

return Spinner
