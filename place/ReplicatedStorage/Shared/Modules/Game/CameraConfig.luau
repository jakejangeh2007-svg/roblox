--!strict
-- ModuleScript: ReplicatedStorage.Shared.Modules.Game.CameraConfig

local CameraConfig = {
	SEAT_CAM_BACK = 14, -- studs behind your seat
	SEAT_CAM_UP = 9, -- studs above your seat
	SEAT_CAM_LOOK_AHEAD = 10, -- how far past the middle of the boat the camera looks
	SEAT_CAM_SMOOTHING = 8, -- higher = the camera follows more tightly
	SHAKE_DECAY = 8, -- how fast camera shake dies down

	-- Your boat hitting something or landing hard shakes the Seat Cam
	IMPACT_SPEED_CHANGE = 12, -- studs/s your boat's speed has to change by at once to count
	IMPACT_SHAKE_PER_SPEED = 0.02, -- studs of shake per stud/s of that change
	MAX_IMPACT_SHAKE = 0.8, -- studs
}

return CameraConfig
