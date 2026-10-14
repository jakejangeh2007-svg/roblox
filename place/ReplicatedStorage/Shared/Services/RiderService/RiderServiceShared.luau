--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.RiderService.RiderServiceShared
--
-- Names both halves of RiderService agree on.

local RiderServiceShared = {
	SERVICE_NAME = "RiderService",
	SLIDE_ANGLE_ATTRIBUTE = "SlideAngle", -- on each boat Seat: how far round the edge its rider has slid (see RiderSpots)

	-- Remotes
	REQUEST_SLIDE = "RequestSlide", -- RemoteEvent client -> server (direction: number): -1 slide left, 1 slide right, 0 stop
}

return RiderServiceShared
