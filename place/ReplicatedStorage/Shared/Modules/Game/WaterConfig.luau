--!strict
-- ModuleScript: ReplicatedStorage.Shared.Modules.Game.WaterConfig
--
-- How water acts on boats (WaterService samples the water, the Hull class moves the boat).

export type Wave = {
	Height: number, -- studs a crest rises above the still surface (a trough sinks as far below)
	Length: number, -- studs from one crest to the next
	Period: number, -- seconds between crests passing the same spot
	Direction: Vector2, -- which way it travels, flat on the water (X, Z)
}

export type WaterType = {
	Speed: number, -- studs/s the water flows toward its part's front face
	WaveScale: number, -- multiplies the height of every wave in WAVES
	Turbulence: number, -- studs/s² of random shoving, like rapids grabbing the boat
	TurnTurbulence: number, -- rad/s² of random twisting
}

local WaterConfig = {
	-- Drag. Water slows a boat toward the speed of the water under it, in two parts: a
	-- gentle drag at any speed, so a boat glides on when its crew stops farting, and a
	-- drag that grows with speed, so a boat levels off smoothly at its top speed instead
	-- of hitting a limit.
	GLIDE_DRAG = 0.5, -- per second
	TOP_SPEED = 24, -- studs/s one rider pushing at full strength levels a boat of FartConfig.REFERENCE_MASS off at
	-- Spinning is slowed by the same water drag acting round the boat's rim, times this
	-- (the hull and the riders' legs churn the water as it spins). Higher = less spin.
	SPIN_DRAG_SCALE = 10,
	AIR_DRAG = 0.15, -- out of the water, drag is this fraction of the water's

	-- Floating. The water holds a boat up at the surface like a soft spring, so it bobs on
	-- the waves and settles after a drop instead of bouncing back out.
	FLOAT_HEIGHT = 0, -- how far above the surface a boat's PrimaryPart floats
	FLOAT_STIFFNESS = 40, -- studs/s² of push back up for every stud a boat is pushed under
	MAX_FLOAT_DEPTH = 3, -- pushing a boat deeper than this doesn't push it back up any harder
	FLOAT_DAMPING = 9, -- how quickly bobbing dies down, per second
	SPLASH_DAMPING = 0.25, -- extra damping that grows with up/down speed, so a boat hitting the water fast stops quickly
	AIRBORNE_HEIGHT = 1.5, -- a boat's PrimaryPart this far above the surface is out of the water;
	-- between there and the surface the water's hold fades in, so leaving and landing are smooth
	TILT_DAMPING = 2, -- how quickly rocking dies down, per second

	-- Waves: gentle swells that boats bob and rock on. The water parts stay flat; only the
	-- boats move. Set WAVES to {} for flat water.
	WAVES = {
		{ Height = 0.2, Length = 40, Period = 3.2, Direction = Vector2.new(0.8, 0.6) },
		{ Height = 0.12, Length = 26, Period = 2.3, Direction = Vector2.new(-0.5, 0.85) },
	} :: { Wave },

	-- Rough water: turbulence changes smoothly over this many studs and seconds
	TURBULENCE_SIZE = 14,
	TURBULENCE_TIME = 2,

	-- Water parts are named after an entry here, or are calm, still water.
	WATER_TYPES = {
		Current = { Speed = 4, WaveScale = 1.3, Turbulence = 0, TurnTurbulence = 0 },
		Rapids = { Speed = 8, WaveScale = 2, Turbulence = 8, TurnTurbulence = 0.5 },
	} :: { [string]: WaterType },
	CALM_WATER = { Speed = 0, WaveScale = 1, Turbulence = 0, TurnTurbulence = 0 } :: WaterType,

	-- Finding the water. Boats look for a surface from this far above their PrimaryPart
	-- down to this far below it. Don't put two water surfaces within this range of each
	-- other, one above the other.
	WATER_CHECK_ABOVE = 8,
	WATER_CHECK_BELOW = 8,

	FALL_DISTANCE = 30, -- a boat this far below the last water it floated on has fallen off the river
	MAX_STEP_TIME = 0.1, -- a laggy frame never moves boats more than this many seconds' worth
}

return WaterConfig
