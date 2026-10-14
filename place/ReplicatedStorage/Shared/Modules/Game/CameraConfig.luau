--!strict
-- ModuleScript: ReplicatedStorage.Shared.Modules.Game.CameraConfig

local CameraConfig = {
	SEAT_CAM_BACK = 14, -- studs behind your seat
	SEAT_CAM_UP = 9, -- studs above your seat
	SEAT_CAM_LOOK_AHEAD = 10, -- how far past the middle of the boat the camera looks
	SEAT_CAM_SMOOTHING = 8, -- higher = the camera follows more tightly (every cam here uses this)
	SHAKE_DECAY = 8, -- how fast camera shake dies down

	-- Your boat hitting something or landing hard shakes the Seat Cam
	IMPACT_SPEED_CHANGE = 12, -- studs/s your boat's speed has to change by at once to count
	IMPACT_SHAKE_PER_SPEED = 0.02, -- studs of shake per stud/s of that change
	MAX_IMPACT_SHAKE = 0.8, -- studs

	-- Knocked off your boat (OverboardService)
	KNOCK_OFF_SHAKE = 0.6, -- studs of shake when you're knocked off
	KNOCKOUT_CAM_BACK = 16, -- while you're knocked out, the camera follows you from this far away...
	KNOCKOUT_CAM_UP = 10, -- ...and this far above you
	SWIM_CAM_BACK = 10, -- while you swim, the camera sits this far behind you...
	SWIM_CAM_UP = 6, -- ...and this far above you...
	SWIM_CAM_LOOK_AHEAD = 6, -- ...looking at a point this far in front of you
}

return CameraConfig
