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

	LAUNCH_DELAY = 3, -- seconds between the last seat filling up and the boat leaving the dock
	EMPTY_DOCKED_TIMEOUT = 60, -- a boat waiting at a dock with nobody in it is removed after this many seconds
	CLEANUP_INTERVAL = 1, -- seconds between checks for boats to remove
}

return BoatConfig
