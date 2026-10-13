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
-- the rider. "Left" turns the boat left, the same way from every seat; the boat turns
-- around whoever is turning it (see the Hull class). So with seats spread around the
-- ring, everyone farting Straight cancels out, and everyone farting Left spins the boat
-- on the spot.
--
-- What a fart does is worked out in the rider's own terms (GetOutput): forward push and
-- turn. FartService eases each rider's output toward that, then GetPush turns the
-- forward push into a push on the boat.

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

-- What a fart in `direction` (nil when not farting) does after `rampTime` seconds of
-- build-up, in the rider's own terms:
--   forward   studs/s² pushing the boat away from the rider
--   turn      rad/s² turning the boat; positive is a LEFT turn (counter-clockwise seen
--             from above)
-- This is the raw fart; the boat's size scales what it does (BoatConfig.HANDLING).
function FartPhysics.GetOutput(direction: Direction?, rampTime: number): (number, number)
	if direction == "Straight" then
		-- Gas goes out behind the rider, so the boat moves away from them.
		return FartPhysics.GetStraightAcceleration(rampTime), 0
	elseif direction == "Left" then
		return 0, FartPhysics.GetTurnAcceleration(rampTime)
	elseif direction == "Right" then
		return 0, -FartPhysics.GetTurnAcceleration(rampTime)
	end
	return 0, 0
end

-- A rider's `forward` push (see GetOutput) from `seatCFrame`, as a push on the boat in
-- world space (studs/s²).
function FartPhysics.GetPush(boatPosition: Vector3, seatCFrame: CFrame, forward: number): Vector3
	return BoatServiceShared.GetRiderFacing(boatPosition, seatCFrame) * forward
end

return FartPhysics
