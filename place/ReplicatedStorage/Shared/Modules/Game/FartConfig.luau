--!strict
-- ModuleScript: ReplicatedStorage.Shared.Modules.Game.FartConfig

local FartConfig = {
	-- Push
	PUSH_SPEED = 7, -- studs/s one Straight toot adds (the boat glides about 8 studs)
	SIDE_PUSH = 0.45, -- sideways push of a Left/Right fart, as a fraction of PUSH_SPEED
	SPIN_SPEED = 0.55, -- rad/s of turn one Left/Right toot adds (about 20 degrees)

	-- Toots and Mega Farts
	TOOT_COOLDOWN = 0.35, -- seconds between farts
	COOLDOWN_LENIENCY = 0.8, -- the server accepts farts this fraction of TOOT_COOLDOWN apart, since network packets can bunch up
	MEGA_MIN_HOLD = 0.3, -- hold a fart key at least this long (seconds) to make a Mega Fart
	MEGA_CHARGE_TIME = 1.2, -- seconds to fully charge a Mega Fart
	MEGA_MULT = 3, -- a fully charged Mega Fart pushes like this many toots

	-- Gas meter (each player's is in their "Gas" attribute)
	GAS_MAX = 100,
	TOOT_COST = 8,
	MEGA_COST = 35,
	GAS_REGEN = 12, -- per second, always refilling

	-- FARTQUAKE: Mega Farts from several players on one boat at almost the same moment
	FARTQUAKE_WINDOW = 0.35, -- seconds
	FARTQUAKE_MIN_PLAYERS = 3, -- or everyone on the boat if fewer (but always at least 2)
	FARTQUAKE_MULT = 1.5, -- every push in the FARTQUAKE gets this much stronger

	-- Effects
	BUTT_OFFSET = CFrame.new(0, -1, 0.6), -- where gas comes out, relative to the HumanoidRootPart
	GAS_ANGLE = math.rad(45), -- how far left or right of straight back the gas comes out on a Left/Right fart
	TOOT_PARTICLES = 10,
	MEGA_PARTICLES = 30,
	DUD_PARTICLES = 3, -- out of gas
	TOOT_VOLUME = 0.6,
	MEGA_VOLUME = 1,
	DUD_VOLUME = 0.25,
	MIN_PITCH = 0.85, -- every fart picks a random pitch between these
	MAX_PITCH = 1.15,
	MEGA_PITCH = 0.8, -- multiplies the pitch of Mega Farts (deeper)
	DUD_PITCH = 1.6, -- multiplies the pitch of duds (squeakier)
	SOUND_LIFETIME = 5, -- seconds before a played fart sound is cleaned up
	MEGA_SHAKE = 0.3, -- camera shake for your own Mega Fart, multiplied by its power
	FARTQUAKE_SHAKE = 1.5, -- camera shake for a FARTQUAKE
}

return FartConfig
