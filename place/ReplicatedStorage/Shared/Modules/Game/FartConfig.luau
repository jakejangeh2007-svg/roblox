--!strict
-- ModuleScript: ReplicatedStorage.Shared.Modules.Game.FartConfig

local FartConfig = {
	-- Strength. Holding a fart key pushes the boat with a set acceleration that builds up
	-- the longer you keep farting, up to a maximum. Switching direction keeps it built up,
	-- and after you let go it fades instead of resetting, so a quick re-press picks up
	-- close to where you left off. How much a push moves a boat depends on the boat's size
	-- (BoatConfig.HANDLING); water drag decides how fast it ends up going (WaterConfig).

	-- Pushing, in studs/s²: how much speed a fart adds every second
	STRAIGHT_ACCELERATION = 18, -- when a fart starts
	STRAIGHT_ACCELERATION_GAIN = 12, -- added for every second you keep farting
	MAX_STRAIGHT_ACCELERATION = 45, -- reached after 2.25 seconds of farting

	-- Turning, in rad/s² (1 rad is about 57 degrees). A Left/Right fart turns the boat
	-- around the rider (see the Hull class), so it swings round them like a steered boat.
	TURN_ACCELERATION = 1.6, -- when a Left/Right fart starts
	TURN_ACCELERATION_GAIN = 1.2, -- added for every second you keep farting
	MAX_TURN_ACCELERATION = 4, -- reached after 2 seconds of farting

	RAMP_DECAY = 3, -- after you let go, built-up strength fades this many times faster than it built up

	-- Smoothness. A fart doesn't snap on, off or around: what it does eases toward where
	-- it's aimed, getting most of the way there (63%) in this many seconds. So starting
	-- swells in, letting go trails off, and switching from Straight to Left fades the
	-- push out as the turn builds in.
	PUSH_RESPONSE_TIME = 0.2,
	TURN_RESPONSE_TIME = 0.35, -- a little slower, so turns ease in instead of jerking the boat around

	-- Gas meter (each player's is in their "Gas" attribute)
	GAS_MAX = 100,
	GAS_DRAIN = 10, -- per second while farting, the same however long you've farted: a full tank lasts 10 seconds
	GAS_REGEN = 15, -- per second while not farting
	MIN_GAS_TO_START = 5, -- below this, pressing a fart key just gives a sad little puff
	REQUEST_COOLDOWN = 0.1, -- seconds between start or switch requests the server acts on for one player;
	-- a request that comes sooner is held and acted on when the time is up

	-- Effects. They grow with the fart's strength, from when it starts to full acceleration.
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
