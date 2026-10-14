--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.RiderService.RiderServiceShared
--
-- Names both halves of RiderService agree on.

local RiderServiceShared = {
	SERVICE_NAME = "RiderService",

	-- Remotes
	REQUEST_SLIDE = "RequestSlide", -- RemoteEvent client -> server (direction: number): -1 slide left, 1 slide right, 0 stop
}

return RiderServiceShared
