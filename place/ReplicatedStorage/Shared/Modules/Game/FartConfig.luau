--!strict
-- ModuleScript: ReplicatedStorage.Shared.Modules.Game.FartConfig

local FartConfig = {
	-- A fart is a jet out of the rider's butt, straight out behind them as they hang on to
	-- the boat, so it pushes the boat toward its middle from wherever they are. Riders
	-- steer by sliding round the edge (RiderConfig). The boat moves the way real physics
	-- says (the Hull class).

	-- Strength. Holding the fart key pushes with a strength that builds up the longer you
	-- keep farting, up to a maximum. After you let go it fades instead of resetting, so a
	-- quick re-press picks up close to where you left off. Strengths are in studs/s²: how
	-- much speed a fart adds every second to a boat weighing REFERENCE_MASS. Heavier boats
	-- speed up slower, lighter ones faster.
	PUSH_ACCELERATION = 18, -- when a fart starts
	PUSH_ACCELERATION_GAIN = 10, -- added for every second you keep farting
	MAX_PUSH_ACCELERATION = 36, -- reached after 1.8 seconds of farting
	REFERENCE_MASS = 89, -- the test kit's one-seat boat with its rider aboard
	RAMP_DECAY = 3, -- after you let go, built-up strength fades this many times faster than it built up
	PUSH_RESPONSE_TIME = 0.08, -- a fart's push eases in and out, most of the way in this many seconds

	-- Gas meter (each player's is in their "Gas" attribute)
	GAS_MAX = 100,
	GAS_DRAIN = 10, -- per second while farting, the same however long you've farted: a full tank lasts 10 seconds
	GAS_REGEN = 15, -- per second while not farting
	MIN_GAS_TO_START = 5, -- below this, pressing a fart key just gives a sad little puff
	REQUEST_COOLDOWN = 0.1, -- seconds between start requests the server acts on for one player;
	-- a request that comes sooner is held and acted on when the time is up

	-- Effects. They grow with the fart's strength, from when it starts to full acceleration.
	BUTT_OFFSET = CFrame.new(0, -1, 0.6), -- where gas comes out, relative to the HumanoidRootPart
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
