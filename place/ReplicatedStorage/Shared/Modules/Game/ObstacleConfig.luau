--!strict
-- ModuleScript: ReplicatedStorage.Shared.Modules.Game.ObstacleConfig
--
-- Obstacles' settings when they don't set their own. Any obstacle (or the marker it's
-- made from) can change one for itself with an attribute of the same name, like Speed.
-- Times are in seconds. StartDelay shifts where an obstacle is in its cycle, so
-- obstacles of the same kind can be staggered instead of moving in step.

local ObstacleConfig = {
	-- Spinner: turns round and round (fan blades, spinning spike arms)
	SPINNER = {
		Speed = 12, -- turns a minute; negative turns the other way
	},

	-- Swinger: swings between two angles on a hinge (swinging doors, a swinging mace)
	SWINGER = {
		FromAngle = 0, -- degrees from how it was built
		ToAngle = 90,
		MoveTime = 1.2, -- to swing from one angle to the other
		HoldTime = 1.5, -- it waits this long at each end
		StartDelay = 0,
	},

	-- Slider: slides back and forth along a line (opening gates, a patrolling spike ball)
	SLIDER = {
		Distance = 10, -- studs it slides from where it was built
		MoveTime = 1,
		HoldTime = 2,
		StartDelay = 0,
	},

	-- WindFan: blows boats in its wind zone sideways, on and off (a big fan on the side)
	WIND_FAN = {
		Strength = 28, -- studs/s² of push on a boat of FartConfig.REFERENCE_MASS (heavier boats are pushed less)
		OnTime = 3,
		OffTime = 3,
		StartDelay = 0,
		Speed = 120, -- turns a minute its fan spins at while it blows
	},
	FAN_SPIN_ACCELERATION = 8, -- rad/s² a WindFan's fan speeds up and slows down at
}

return ObstacleConfig
