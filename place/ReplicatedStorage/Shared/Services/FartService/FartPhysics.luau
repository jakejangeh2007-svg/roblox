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
-- Direction: a fart is a jet at the rider's seat. The gas goes one way and pushes the
-- boat the opposite way. Riders face the middle of the boat. "Straight" farts behind the
-- rider, pushing the boat the way they face, through its middle, so it only moves it.
-- "Left" farts out to the rider's left, pushing their side of the boat to the right;
-- since they sit at the edge, that spins the boat left (counter-clockwise seen from
-- above) and nudges it right. "Right" is the mirror image. The Hull class does the
-- physics. Everyone on a ring farting Straight cancels out, and everyone farting Left
-- spins it left on the spot.
--
-- What a fart does is worked out in the rider's own terms (GetOutput): forward and
-- rightward push. FartService eases each rider's output toward that, then GetForce turns
-- it into a force on the boat.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoatServiceShared = require(ReplicatedStorage.Shared.Services.BoatService.BoatServiceShared)
local FartConfig = require(ReplicatedStorage.Shared.Modules.Game.FartConfig)

export type Direction = "Left" | "Straight" | "Right"

local FartPhysics = {
	-- Seconds of farting it takes to build up to full strength
	MAX_RAMP_TIME = if FartConfig.PUSH_ACCELERATION_GAIN > 0
		then math.max(
			0,
			(FartConfig.MAX_PUSH_ACCELERATION - FartConfig.PUSH_ACCELERATION) / FartConfig.PUSH_ACCELERATION_GAIN
		)
		else 0,
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

-- Studs/s² of push (on a boat of FartConfig.REFERENCE_MASS) after `rampTime` seconds of build-up.
function FartPhysics.GetPushAcceleration(rampTime: number): number
	return math.min(
		FartConfig.MAX_PUSH_ACCELERATION,
		FartConfig.PUSH_ACCELERATION + FartConfig.PUSH_ACCELERATION_GAIN * rampTime
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

-- What a fart in `direction` (nil when not farting) pushes after `rampTime` seconds of
-- build-up, in the rider's own terms (studs/s² on a boat of FartConfig.REFERENCE_MASS):
--   forward   the way the rider faces
--   right     to the rider's right (negative is to their left)
function FartPhysics.GetOutput(direction: Direction?, rampTime: number): (number, number)
	if not direction then
		return 0, 0
	end
	local pushAcceleration = FartPhysics.GetPushAcceleration(rampTime)
	if direction == "Straight" then
		-- Gas out behind the rider pushes the boat forward.
		return pushAcceleration, 0
	elseif direction == "Left" then
		-- Gas out to the rider's left pushes the boat to their right.
		return 0, pushAcceleration
	end
	return 0, -pushAcceleration
end

-- A rider's `forward` and `right` push (see GetOutput) from `seatCFrame`, as a force on
-- the boat in world space (Roblox force units).
function FartPhysics.GetForce(boatPosition: Vector3, seatCFrame: CFrame, forward: number, right: number): Vector3
	local facing = BoatServiceShared.GetRiderFacing(boatPosition, seatCFrame)
	local rightward = facing:Cross(Vector3.yAxis) -- the rider's right hand
	return (facing * forward + rightward * right) * FartConfig.REFERENCE_MASS
end

return FartPhysics
