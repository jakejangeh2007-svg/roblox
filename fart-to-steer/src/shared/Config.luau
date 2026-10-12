--!strict
-- Every tuning number for Fart to Steer. Change these while playtesting.
-- docs/fart-to-steer/GAME_PLAN.md (section 13) explains what each one is for.

local Config = {
	-- Fart push
	PUSH_SPEED = 7, -- studs/s one Straight toot adds (the boat glides about 8 studs)
	SIDE_PUSH = 0.45, -- sideways push of a Left/Right fart, as a fraction of PUSH_SPEED
	SPIN_SPEED = 0.55, -- rad/s of turn one Left/Right toot adds (about 20 degrees)

	-- Toots and Mega Farts
	TOOT_COOLDOWN = 0.35, -- seconds between farts
	MEGA_MIN_HOLD = 0.3, -- hold a fart key at least this long to make a Mega Fart
	MEGA_CHARGE_TIME = 1.2, -- seconds to fully charge a Mega Fart
	MEGA_MULT = 3, -- a fully charged Mega Fart pushes like this many toots

	-- Gas meter
	GAS_MAX = 100,
	TOOT_COST = 8,
	MEGA_COST = 35,
	GAS_REGEN = 12, -- per second, always refilling

	-- FARTQUAKE: Mega Farts from several players at almost the same moment
	FARTQUAKE_WINDOW = 0.35, -- seconds
	FARTQUAKE_MIN_PLAYERS = 3, -- or everyone on the boat if fewer (but always at least 2)
	FARTQUAKE_MULT = 1.5,

	-- Water
	WATER_DRAG = 0.9, -- how fast the boat slows down
	SPIN_DRAG = 1.6, -- how fast spinning stops
	TILT_DRAG = 4, -- how fast wobbling stops
	FLOAT_HEIGHT = 1.2, -- how high the middle of the ring sits above the water
	FLOAT_STIFFNESS = 60, -- how strongly the boat snaps onto the surface
	FLOAT_DAMPING = 8, -- how quickly bobbing stops

	-- Boats
	DEFAULT_BOAT = "PartyRing", -- one of the names in BoatTypes
	SEAT_HEIGHT = 1.3, -- how far above the top of the tube a rider's HumanoidRootPart sits
	RESET_DELAY = 1.5, -- seconds between falling off and respawning at the start
	FINISH_RESET_DELAY = 4, -- seconds between finishing and going back to the start

	-- Course
	WATER_Y = 120, -- water height of the grey-box test course
	KILL_Y = 80, -- a boat that falls below this height has fallen off the river

	-- Seat Cam
	CAMERA_BACK = 14, -- studs behind your seat
	CAMERA_UP = 9, -- studs above your seat
	CAMERA_LOOK_AHEAD = 10, -- how far past the middle of the boat the camera looks
	CAMERA_SMOOTHING = 8, -- higher = the camera follows more tightly

	-- Fart sounds. Paste audio ids from the Creator Store here, like "rbxassetid://123456".
	-- While the list is empty, a built-in splash sound pitched way down stands in.
	FART_SOUND_IDS = {} :: { string },
	PLACEHOLDER_SOUND_ID = "rbxasset://sounds/impact_water.mp3",
}

return Config
