--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.BoatService.BoatServiceShared
--
-- Names both halves of BoatService agree on.

export type BoatState = "Docked" | "Launching" | "Launched" | "Destroyed"

local BoatServiceShared = {
	BOATS_FOLDER_NAME = "Boats", -- Workspace.Boats holds every spawned boat
	TEMPLATES_FOLDER_NAME = "Boats", -- ReplicatedStorage.Assets.Boats holds the boat templates

	-- Attributes on each spawned boat model, for clients and UI
	STATE_ATTRIBUTE = "State", -- a BoatState
	LAUNCH_TIME_ATTRIBUTE = "LaunchTime", -- server time (workspace:GetServerTimeNow()) the boat leaves the dock
}

return BoatServiceShared
