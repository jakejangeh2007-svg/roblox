--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.FartService.FartPhysics
--
-- The rules for what farting does. Pure math, shared by the server (which moves the
-- boat) and the client (which plays effects that match).
--
-- A fart speeds the boat up at a set acceleration that grows by a set amount every
-- second it keeps going, up to a maximum (all in FartConfig).
--
-- Riders face the middle of the boat. "Straight" pushes the boat away from the
-- rider. "Left" turns the boat left, the same way from every seat, plus a small
-- sideways push. So with seats spread around the ring, everyone farting Straight
-- cancels out, and everyone farting Left spins the boat on the spot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoatServiceShared = require(ReplicatedStorage.Shared.Services.BoatService.BoatServiceShared)
local FartConfig = require(ReplicatedStorage.Shared.Modules.Game.FartConfig)

export type Direction = "Left" | "Straight" | "Right"

local FartPhysics = {}

function FartPhysics.IsDirection(value: unknown): boolean
	return value == "Left" or value == "Straight" or value == "Right"
end

-- Studs/s² of push after `fartingTime` seconds of nonstop farting.
function FartPhysics.GetStraightAcceleration(fartingTime: number): number
	return math.min(
		FartConfig.MAX_STRAIGHT_ACCELERATION,
		FartConfig.STRAIGHT_ACCELERATION + FartConfig.STRAIGHT_ACCELERATION_GAIN * fartingTime
	)
end

-- Rad/s² of turn after `fartingTime` seconds of nonstop farting.
function FartPhysics.GetSpinAcceleration(fartingTime: number): number
	return math.min(
		FartConfig.MAX_SPIN_ACCELERATION,
		FartConfig.SPIN_ACCELERATION + FartConfig.SPIN_ACCELERATION_GAIN * fartingTime
	)
end

-- How far a fart has grown: 0 when it starts, 1 once it's at full acceleration.
-- Used to grow the effects.
function FartPhysics.GetRampProgress(fartingTime: number): number
	local range = FartConfig.MAX_STRAIGHT_ACCELERATION - FartConfig.STRAIGHT_ACCELERATION
	if range <= 0 then
		return 1
	end
	return math.clamp(
		(FartPhysics.GetStraightAcceleration(fartingTime) - FartConfig.STRAIGHT_ACCELERATION) / range,
		0,
		1
	)
end

-- How fast a fart from `seatCFrame` speeds the boat up (studs/s²) and turns it (rad/s²)
-- after `fartingTime` seconds. A positive turn is a LEFT turn (counter-clockwise seen
-- from above). Multiply both by the frame's time to get the change for that frame.
function FartPhysics.GetThrust(
	boatPosition: Vector3,
	seatCFrame: CFrame,
	direction: Direction,
	fartingTime: number
): (Vector3, number)
	local facing = BoatServiceShared.GetRiderFacing(boatPosition, seatCFrame)
	local right = facing:Cross(Vector3.yAxis) -- the rider's right hand
	local straightAcceleration = FartPhysics.GetStraightAcceleration(fartingTime)

	if direction == "Straight" then
		-- Gas goes out behind the rider, so the boat moves away from them.
		return facing * straightAcceleration, 0
	end
	local sidePush = straightAcceleration * FartConfig.SIDE_PUSH_FRACTION
	local spinAcceleration = FartPhysics.GetSpinAcceleration(fartingTime)
	if direction == "Left" then
		-- Like an outboard motor: shove our side right so the far side swings left.
		return right * sidePush, spinAcceleration
	else
		return -right * sidePush, -spinAcceleration
	end
end

return FartPhysics
