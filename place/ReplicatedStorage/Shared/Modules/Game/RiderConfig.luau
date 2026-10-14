--!strict
-- ModuleScript: ReplicatedStorage.Shared.Modules.Game.RiderConfig
--
-- Riders hang on to the outside of their boat instead of sitting in it, and slide round
-- its edge to choose where they push from.

local RiderConfig = {
	-- Where a rider's HumanoidRootPart goes, from their Seat (the Boat class puts them
	-- there). Seats face the middle of the boat, so +Z is outward: this hangs riders just
	-- below and outside their seat, with their arms over the side and their legs in the water.
	HANG_OFFSET = CFrame.new(0, -0.35, 1),

	-- Sliding round the edge (A and D). Each rider has their own stretch of the edge: from
	-- their seat halfway to the next seat each way, or all the way round on a one-seat boat.
	SLIDE_SPEED = 6, -- studs/s along the edge
	SLIDE_RESPONSE_TIME = 0.12, -- sliding speeds up and slows down most of the way (63%) in this many seconds
	SLIDE_SOFT_END = 1.5, -- studs before a blocker a rider starts easing into it...
	SLIDE_END_SPEED = 0.25, -- ...down to this fraction of SLIDE_SPEED when they reach it
	RIDER_SPACING = 2.5, -- studs kept between neighbouring riders at the ends of their stretches
	OTHER_RIDER_SMOOTHING = 0.08, -- other players' riders glide to where the server has them, most of the way in this many seconds
	SLIDE_CORRECTION_TIME = 0.25, -- once you stop, your rider settles onto where the server has you over about this long
	SLIDE_SNAP_DISTANCE = 4, -- studs your rider can be from where the server has you before it jumps straight there
	STICK_DEADZONE = 0.5, -- how far a controller's left stick has to be pushed left or right to slide

	-- Their pose while they hang on (RiderService, on every player's screen)
	ARM_REACH = math.rad(60), -- arms raised forward this far from hanging down, to hold on to the boat
	ELBOW_BEND = math.rad(15),
	KNEE_BEND = math.rad(15),
	KICK_ANGLE = math.rad(10), -- legs kick back and forth this far in the water...
	KICK_SPEED = 5, -- ...this fast (radians of the kick cycle per second)
	SHIMMY_ANGLE = math.rad(20), -- while sliding, each arm reaches this much further and back, hand over hand...
	SHIMMY_STRIDE = 2, -- ...one full hand-over-hand for every this many studs slid
}

return RiderConfig
