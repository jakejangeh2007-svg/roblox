--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.FartService.FartPhysics
--
-- The rules for what farting does. Pure math, shared by the server (which moves the
-- boat) and the client (which plays effects that match).
--
-- Strength: a fart pushes with a set acceleration that grows by a set amount every
-- second it has built up, up to a maximum (all in FartConfig). How far it has built up
-- is its "ramp time": it rises while the player farts, in any direction, and falls
-- RAMP_DECAY times as fast once they stop.
--
-- Direction: riders face the middle of the boat. "Straight" pushes the boat away from
-- the rider. "Left" turns the boat left, the same way from every seat, plus a small
-- sideways push. So with seats spread around the ring, everyone farting Straight
-- cancels out, and everyone farting Left spins the boat on the spot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoatServiceShared = require(ReplicatedStorage.Shared.Services.BoatService.BoatServiceShared)
local FartConfig = require(ReplicatedStorage.Shared.Modules.Game.FartConfig)

export type Direction = "Left" | "Straight" | "Right"

-- Seconds of farting it takes to build up to full strength, pushing and turning both.
local function GetRampDuration(startAcceleration: number, gain: number, maxAcceleration: number): number
	return if gain > 0 then math.max(0, (maxAcceleration - startAcceleration) / gain) else 0
end

local FartPhysics = {
	MAX_RAMP_TIME = math.max(
		GetRampDuration(
			FartConfig.STRAIGHT_ACCELERATION,
			FartConfig.STRAIGHT_ACCELERATION_GAIN,
			FartConfig.MAX_STRAIGHT_ACCELERATION
		),
		GetRampDuration(
			FartConfig.TURN_ACCELERATION,
			FartConfig.TURN_ACCELERATION_GAIN,
			FartConfig.MAX_TURN_ACCELERATION
		)
	),
}

function FartPhysics.IsDirection(value: unknown): boolean
	return value == "Left" or value == "Straight" or value == "Right"
end

-- A player's ramp time `deltaTime` seconds later: built up while `isFarting`, fading otherwise.
function FartPhysics.UpdateRampTime(rampTime: number, isFarting: boolean, deltaTime: number): number
	if isFarting then
		return math.min(FartPhysics.MAX_RAMP_TIME, rampTime + deltaTime)
	end
	return math.max(0, rampTime - deltaTime * FartConfig.RAMP_DECAY)
end

-- Studs/s² of push after `rampTime` seconds of build-up.
function FartPhysics.GetStraightAcceleration(rampTime: number): number
	return math.min(
		FartConfig.MAX_STRAIGHT_ACCELERATION,
		FartConfig.STRAIGHT_ACCELERATION + FartConfig.STRAIGHT_ACCELERATION_GAIN * rampTime
	)
end

-- Rad/s² of turn after `rampTime` seconds of build-up.
function FartPhysics.GetTurnAcceleration(rampTime: number): number
	return math.min(
		FartConfig.MAX_TURN_ACCELERATION,
		FartConfig.TURN_ACCELERATION + FartConfig.TURN_ACCELERATION_GAIN * rampTime
	)
end

-- How far a fart has built up: 0 at its starting strength, 1 at full strength. Used to
-- grow the effects.
function FartPhysics.GetRampProgress(rampTime: number): number
	if FartPhysics.MAX_RAMP_TIME <= 0 then
		return 1
	end
	return math.clamp(rampTime / FartPhysics.MAX_RAMP_TIME, 0, 1)
end

-- How fast a fart from `seatCFrame` speeds the boat up (studs/s²) and turns it (rad/s²)
-- after `rampTime` seconds of build-up. A positive turn is a LEFT turn (counter-clockwise
-- seen from above). This is the raw fart; the boat's size scales what it does
-- (BoatConfig.HANDLING).
function FartPhysics.GetThrust(
	boatPosition: Vector3,
	seatCFrame: CFrame,
	direction: Direction,
	rampTime: number
): (Vector3, number)
	local facing = BoatServiceShared.GetRiderFacing(boatPosition, seatCFrame)
	local right = facing:Cross(Vector3.yAxis) -- the rider's right hand
	local straightAcceleration = FartPhysics.GetStraightAcceleration(rampTime)

	if direction == "Straight" then
		-- Gas goes out behind the rider, so the boat moves away from them.
		return facing * straightAcceleration, 0
	end
	local sidePush = straightAcceleration * FartConfig.SIDE_PUSH_FRACTION
	local turnAcceleration = FartPhysics.GetTurnAcceleration(rampTime)
	if direction == "Left" then
		-- Like an outboard motor: shove our side right so the far side swings left.
		return right * sidePush, turnAcceleration
	else
		return -right * sidePush, -turnAcceleration
	end
end

return FartPhysics
