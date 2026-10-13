--!strict
-- ModuleScript: ReplicatedStorage.Shared.Modules.Game.DockConfig

local DockConfig = {
	SPAWN_COOLDOWN = 3, -- seconds a player has to wait between boat spawn requests
	MAX_REQUEST_DISTANCE = 40, -- how close (in studs) a player must be to a dock's BoatSpawn to use it
}

return DockConfig
