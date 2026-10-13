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
-- Direction: a fart is a push on the boat at the rider's seat, like a jet. Riders face
-- the middle of the boat. "Straight" pushes the boat the way the rider faces, "Left" to
-- their left and "Right" to their right. Where it pushes matters (the Hull class does
-- the physics): Straight pushes through the middle of the boat, so it only moves it;
-- Left and Right push across the edge, so they move it and spin it too. Everyone on a
-- ring farting Straight cancels out, and everyone farting Left spins it on the spot.
--
-- What a fart does is worked out in the rider's own terms (GetOutput): forward and
-- leftward push. FartService eases each rider's output toward that, then GetForce turns
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
--   left      to the rider's left (negative is to their right)
function FartPhysics.GetOutput(direction: Direction?, rampTime: number): (number, number)
	if not direction then
		return 0, 0
	end
	-- The gas goes out the opposite way, behind or beside the rider.
	local pushAcceleration = FartPhysics.GetPushAcceleration(rampTime)
	if direction == "Straight" then
		return pushAcceleration, 0
	elseif direction == "Left" then
		return 0, pushAcceleration
	end
	return 0, -pushAcceleration
end

-- A rider's `forward` and `left` push (see GetOutput) from `seatCFrame`, as a force on
-- the boat in world space (Roblox force units).
function FartPhysics.GetForce(boatPosition: Vector3, seatCFrame: CFrame, forward: number, left: number): Vector3
	local facing = BoatServiceShared.GetRiderFacing(boatPosition, seatCFrame)
	local leftward = Vector3.yAxis:Cross(facing) -- the rider's left hand
	return (facing * forward + leftward * left) * FartConfig.REFERENCE_MASS
end

return FartPhysics
