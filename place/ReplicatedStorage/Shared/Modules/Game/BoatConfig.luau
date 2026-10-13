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

	-- Multiplies every fart push and turn, by boat size. Bigger boats are heavier to steer.
	PUSH_SCALES = {
		[1] = 1.2,
		[2] = 1.1,
		[3] = 1.05,
		[4] = 1,
		[5] = 0.9,
		[6] = 0.8,
	} :: { [number]: number },
	SPIN_SCALES = {
		[1] = 1.5,
		[2] = 1.2,
		[3] = 1.1,
		[4] = 1,
		[5] = 0.85,
		[6] = 0.7,
	} :: { [number]: number },

	-- Joining
	JOIN_TIME = 30, -- seconds players have to get in after the party leader spawns a boat
	LAUNCH_DELAY = 3, -- countdown (seconds) once every seat is taken or the leader starts the run early
	JOIN_DISTANCE = 40, -- how close (studs) a player must be to a boat to ask to join it
	REQUEST_COOLDOWN = 1, -- seconds a player has to wait between join or start requests
	CLEANUP_INTERVAL = 1, -- seconds between checks for boats to remove (also re-claims boat physics for the server)
	WIPE_DELAY = 1.5, -- seconds a boat that fell off the river hangs frozen before its crew respawns

	UPRIGHT_RESPONSIVENESS = 25, -- how quickly a tipped boat rights itself
	CENTER_SEAT_RADIUS = 1, -- a seat closer than this (studs) to the middle of the boat counts as a middle seat
}

return BoatConfig
