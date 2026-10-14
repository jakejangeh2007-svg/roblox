--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.FartService.FartServiceShared
--
-- Names both halves of FartService agree on.

local FartServiceShared = {
	SERVICE_NAME = "FartService",
	GAS_ATTRIBUTE = "Gas", -- on each Player: their current gas, a whole number from 0 to FartConfig.GAS_MAX

	-- Remotes
	REQUEST_START_FART = "RequestStartFart", -- RemoteEvent client -> server (): start farting
	REQUEST_STOP_FART = "RequestStopFart", -- RemoteEvent client -> server (): stop farting
	PLAY_FART = "PlayFart", -- RemoteEvent server -> clients (farter: Player): farter started farting
	STOP_FART = "StopFart", -- RemoteEvent server -> clients (farter: Player): farter stopped farting
}

return FartServiceShared
