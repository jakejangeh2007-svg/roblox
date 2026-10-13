--!strict
-- ModuleScript: ReplicatedStorage.Shared.Modules.Game.FartConfig

local FartConfig = {
	-- Push. Holding a fart key farts nonstop. Power starts at MIN_POWER and grows to
	-- MAX_POWER over POWER_RAMP_TIME seconds of farting; letting go resets it.
	THRUST = 8, -- studs/s² a Straight fart speeds the boat up by, at power 1
	SIDE_THRUST = 0.45, -- sideways push of a Left/Right fart, as a fraction of THRUST
	SPIN_THRUST = 0.7, -- rad/s² a Left/Right fart turns the boat by, at power 1
	MIN_POWER = 1,
	MAX_POWER = 2.5,
	POWER_RAMP_TIME = 3, -- seconds of nonstop farting to reach MAX_POWER

	-- Gas meter (each player's is in their "Gas" attribute)
	GAS_MAX = 100,
	GAS_DRAIN = 10, -- per second while farting, the same at any power: a full tank lasts 10 seconds
	GAS_REGEN = 15, -- per second while not farting
	MIN_GAS_TO_START = 5, -- below this, pressing a fart key just gives a sad little puff
	REQUEST_COOLDOWN = 0.1, -- seconds the server waits between accepting start requests from one player

	-- Effects
	BUTT_OFFSET = CFrame.new(0, -1, 0.6), -- where gas comes out, relative to the HumanoidRootPart
	GAS_ANGLE = math.rad(45), -- how far left or right of straight back the gas comes out on a Left/Right fart
	STREAM_PARTICLE_RATE = 25, -- particles per second while farting, multiplied by power
	DUD_PARTICLES = 3, -- the puff when there isn't enough gas
	STREAM_VOLUME = 0.5, -- sound volume at MIN_POWER...
	MAX_STREAM_VOLUME = 1, -- ...rising to this at MAX_POWER
	MIN_PITCH = 0.85, -- every fart picks a random starting pitch between these
	MAX_PITCH = 1.15,
	PITCH_RISE_PER_POWER = 0.15, -- the pitch rises by this much for each point of power above MIN_POWER
	DUD_VOLUME = 0.25,
	DUD_PITCH = 1.6, -- multiplies the pitch of duds (squeakier)
	DUD_SOUND_LIFETIME = 3, -- seconds before a dud sound is cleaned up
}

return FartConfig
