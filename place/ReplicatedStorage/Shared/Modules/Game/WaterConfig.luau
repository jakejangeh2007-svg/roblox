--!strict
-- ModuleScript: ReplicatedStorage.Shared.Modules.Game.WaterConfig

local WaterConfig = {
	WATER_DRAG = 0.9, -- how fast boats slow down
	SPIN_DRAG = 1.6, -- how fast spinning stops
	TILT_DRAG = 4, -- how fast wobbling stops

	FLOAT_HEIGHT = 0, -- how far above the water surface a boat's PrimaryPart sits
	FLOAT_STIFFNESS = 60, -- how strongly boats snap onto the surface
	FLOAT_DAMPING = 8, -- how quickly bobbing stops
	WATER_CHECK_ABOVE = 4, -- boats look for water from this far above their PrimaryPart...
	WATER_CHECK_BELOW = 8, -- ...down to this far below it

	FALL_DISTANCE = 30, -- a boat this far below the last water it floated on has fallen off the river

	-- Water parts named one of these flow toward their front face at this many studs/s.
	-- Any other water part is still water.
	CURRENT_SPEEDS = {
		Current = 4,
		Rapids = 8,
	} :: { [string]: number },
}

return WaterConfig
