--!strict
-- ModuleScript: ReplicatedStorage.Shared.Modules.Game.FartConfig

local FartConfig = {
	-- Pushing. Holding a fart key speeds the boat up at a set acceleration, which grows
	-- by a set amount every second you keep farting, up to a maximum. Letting go resets it.
	-- Accelerations are in studs/s²: how much speed a fart adds every second.
	STRAIGHT_ACCELERATION = 18, -- when a fart starts
	STRAIGHT_ACCELERATION_GAIN = 12, -- added for every second you keep farting
	MAX_STRAIGHT_ACCELERATION = 45, -- reached after 2.25 seconds of farting
	SIDE_PUSH_FRACTION = 0.45, -- a Left/Right fart also pushes sideways at this fraction of the above

	-- Turning, in rad/s² (1 rad is about 57 degrees)
	SPIN_ACCELERATION = 1.6, -- when a Left/Right fart starts
	SPIN_ACCELERATION_GAIN = 1.2, -- added for every second you keep farting
	MAX_SPIN_ACCELERATION = 4, -- reached after 2 seconds of farting

	-- Farting can't push a boat faster than these
	MAX_SPEED = 30, -- studs/s
	MAX_SPIN_SPEED = 2.5, -- rad/s (about 140 degrees a second)

	-- Gas meter (each player's is in their "Gas" attribute)
	GAS_MAX = 100,
	GAS_DRAIN = 10, -- per second while farting, the same however long you've farted: a full tank lasts 10 seconds
	GAS_REGEN = 15, -- per second while not farting
	MIN_GAS_TO_START = 5, -- below this, pressing a fart key just gives a sad little puff
	REQUEST_COOLDOWN = 0.1, -- seconds the server waits between accepting start requests from one player

	-- Effects. They grow with the fart, from its start to when it reaches full acceleration.
	BUTT_OFFSET = CFrame.new(0, -1, 0.6), -- where gas comes out, relative to the HumanoidRootPart
	GAS_ANGLE = math.rad(45), -- how far left or right of straight back the gas comes out on a Left/Right fart
	MIN_PARTICLE_RATE = 20, -- particles per second when a fart starts...
	MAX_PARTICLE_RATE = 60, -- ...and at full acceleration
	MAX_PARTICLE_SPEED_MULTIPLIER = 2.5, -- the cloud's Speed is multiplied by up to this at full acceleration
	STREAM_VOLUME = 0.5, -- sound volume when a fart starts...
	MAX_STREAM_VOLUME = 1, -- ...and at full acceleration
	MIN_PITCH = 0.85, -- every fart picks a random starting pitch between these
	MAX_PITCH = 1.15,
	PITCH_RISE = 0.25, -- the pitch rises by this fraction by full acceleration
	DUD_PARTICLES = 3, -- the puff when there isn't enough gas
	DUD_VOLUME = 0.25,
	DUD_PITCH = 1.6, -- multiplies the pitch of duds (squeakier)
	DUD_SOUND_LIFETIME = 3, -- seconds before a dud sound is cleaned up
}

return FartConfig
