--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.FartService.FartServiceShared
--
-- Names both halves of FartService agree on.

local FartServiceShared = {
	SERVICE_NAME = "FartService",
	GAS_ATTRIBUTE = "Gas", -- on each Player: their current gas, a whole number from 0 to FartConfig.GAS_MAX

	-- Remotes
	REQUEST_FART = "RequestFart", -- RemoteEvent client -> server (direction: string, heldTime: number)
	PLAY_FART = "PlayFart", -- RemoteEvent server -> other clients (farter: Player, direction: string, power: number, isMega: boolean)
	PLAY_FARTQUAKE = "PlayFartquake", -- RemoteEvent server -> each crew member of a boat that just FARTQUAKEd
}

return FartServiceShared
