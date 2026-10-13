--!strict
-- ModuleScript: ReplicatedStorage.Shared.Modules.Game.RiderConfig
--
-- Riders hang on to the outside of their boat instead of sitting in it.

local RiderConfig = {
	-- Where a rider's HumanoidRootPart goes, from their Seat (the Boat class puts them
	-- there). Seats face the middle of the boat, so +Z is outward: this hangs riders just
	-- below and outside their seat, with their arms over the side and their legs in the water.
	HANG_OFFSET = CFrame.new(0, -0.35, 1),

	-- Their pose while they hang on (RiderService, on every player's screen)
	ARM_REACH = math.rad(60), -- arms raised forward this far from hanging down, to hold on to the boat
	ELBOW_BEND = math.rad(15),
	KNEE_BEND = math.rad(15),
	KICK_ANGLE = math.rad(10), -- legs kick back and forth this far in the water...
	KICK_SPEED = 5, -- ...this fast (radians of the kick cycle per second)
	-- Farting Left or Right, a rider twists round to aim their butt that way: see
	-- FartConfig.AIM_ANGLE.
}

return RiderConfig
