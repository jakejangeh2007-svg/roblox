--!strict
-- ModuleScript: ReplicatedStorage.Shared.Modules.Game.BoatConfig

local BoatConfig = {
	MIN_SEATS = 1,
	MAX_SEATS = 6,

	-- The boat template for each size, in ReplicatedStorage.Assets.Boats.
	-- Each template needs exactly that many Seats.
	TEMPLATE_NAMES = {
		[1] = "Boat1",
		[2] = "Boat2",
		[3] = "Boat3",
		[4] = "Boat4",
		[5] = "Boat5",
		[6] = "Boat6",
	} :: { [number]: string },

	-- Joining
	JOIN_TIME = 30, -- seconds players have to get in after the party leader spawns a boat
	LAUNCH_DELAY = 3, -- countdown (seconds) once every seat is taken or the leader starts the run early
	JOIN_DISTANCE = 40, -- how close (studs) a player must be to a boat to ask to join it
	REQUEST_COOLDOWN = 1, -- seconds a player has to wait between join or start requests
	CLEANUP_INTERVAL = 1, -- seconds between checks for removed boats to forget
	WIPE_DELAY = 1.5, -- seconds a boat that fell off the river hangs frozen before its crew respawns

	-- Tilting. A boat on the river rocks with the waves and leans away from the way it's
	-- speeding up or turning (its far side lifts when it surges forward, and it heels over
	-- in a turn or when it hits something), then rights itself.
	UPRIGHT_RESPONSIVENESS = 12, -- how quickly it tilts to follow the waves and its lean (higher = stiffer)
	LEAN_PER_ACCELERATION = 0.0035, -- radians of lean per stud/s² of speeding up, slowing down or turning
	LEAN_SMOOTHING = 6, -- how quickly the lean follows changes (higher = snappier, lower = smoother)
	MAX_TILT = math.rad(12), -- it never tilts further than this from level (waves and lean together)

	-- Every part of a spawned boat gets these, keeping its own density: a slippery,
	-- slightly bouncy hull that glances off rocks and banks instead of sticking to them.
	HULL_FRICTION = 0.05,
	HULL_ELASTICITY = 0.3,
	HULL_FRICTION_WEIGHT = 50, -- how much the hull's friction wins over what it touches
	HULL_ELASTICITY_WEIGHT = 50, -- how much the hull's bounciness wins over what it touches

	CENTER_SEAT_RADIUS = 1, -- a seat closer than this (studs) to the middle of the boat counts as a middle seat
}

return BoatConfig
