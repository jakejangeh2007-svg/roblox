--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.DockService.DockServiceShared
--
-- Names both halves of DockService agree on.

local DockServiceShared = {
	SERVICE_NAME = "DockService",
	DOCKS_FOLDER_NAME = "Docks", -- the folder of dock models in each location
	SPAWN_BOAT_PROMPT_NAME = "SpawnBoatPrompt", -- the ProximityPrompt inside each dock model

	-- Remotes
	REQUEST_SPAWN_BOAT = "RequestSpawnBoat", -- RemoteFunction (dock: Model, seatCount: number) -> (success: boolean, message: string?)
}

return DockServiceShared
