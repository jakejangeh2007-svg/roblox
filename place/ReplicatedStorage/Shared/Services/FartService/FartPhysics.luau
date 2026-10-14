--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.FartService.FartPhysics
--
-- The rules for what farting does. Pure math, shared by the server (which moves the
-- boat) and the client (which plays effects that match).
--
-- Strength: a fart pushes with a set acceleration that grows by a set amount every
-- second it has built up, up to a maximum (all in FartConfig). How far it has built up
-- is its "ramp time": it rises while the player farts and falls RAMP_DECAY times as
-- fast once they stop.
--
-- Direction: riders hang on to the outside of the boat facing its middle, and fart
-- straight out behind them, so a fart pushes the boat toward its middle from wherever
-- the rider is. It goes through the middle, so it moves the boat without spinning it.
-- Riders steer by sliding round the edge to push from a different side (RiderService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoatServiceShared = require(ReplicatedStorage.Shared.Services.BoatService.BoatServiceShared)
local FartConfig = require(ReplicatedStorage.Shared.Modules.Game.FartConfig)

local FartPhysics = {
	-- Seconds of farting it takes to build up to full strength
	MAX_RAMP_TIME = if FartConfig.PUSH_ACCELERATION_GAIN > 0
		then math.max(
			0,
			(FartConfig.MAX_PUSH_ACCELERATION - FartConfig.PUSH_ACCELERATION) / FartConfig.PUSH_ACCELERATION_GAIN
		)
		else 0,
}

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

-- A push of `pushAcceleration` (studs/s² on a boat of FartConfig.REFERENCE_MASS) from a
-- rider at `riderCFrame`, as a force on the boat in world space (Roblox force units): the
-- way the rider faces, toward the middle of the boat.
function FartPhysics.GetForce(boatPosition: Vector3, riderCFrame: CFrame, pushAcceleration: number): Vector3
	return BoatServiceShared.GetRiderFacing(boatPosition, riderCFrame) * pushAcceleration * FartConfig.REFERENCE_MASS
end

return FartPhysics
