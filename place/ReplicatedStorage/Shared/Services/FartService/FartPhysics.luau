--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.FartService.FartPhysics
--
-- The rules for what farting does. Pure math, shared by the server (which moves the
-- boat) and the client (which plays effects that match).
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

-- A fart's power after `fartingTime` seconds of nonstop farting: MIN_POWER at the
-- start, growing evenly to MAX_POWER after POWER_RAMP_TIME.
function FartPhysics.GetPower(fartingTime: number): number
	local progress = math.clamp(fartingTime / FartConfig.POWER_RAMP_TIME, 0, 1)
	return FartConfig.MIN_POWER + (FartConfig.MAX_POWER - FartConfig.MIN_POWER) * progress
end

-- How fast a fart from `seatCFrame` speeds the boat up (studs/s²) and turns it
-- (rad/s²) at `power`. A positive turn is a LEFT turn (counter-clockwise seen from above).
-- Multiply both by the frame's time to get the change for that frame.
function FartPhysics.GetThrust(
	boatPosition: Vector3,
	seatCFrame: CFrame,
	direction: Direction,
	power: number
): (Vector3, number)
	local facing = BoatServiceShared.GetRiderFacing(boatPosition, seatCFrame)
	local right = facing:Cross(Vector3.yAxis) -- the rider's right hand

	if direction == "Straight" then
		-- Gas goes out behind the rider, so the boat moves away from them.
		return facing * FartConfig.THRUST * power, 0
	elseif direction == "Left" then
		-- Like an outboard motor: shove our side right so the far side swings left.
		return right * FartConfig.THRUST * FartConfig.SIDE_THRUST * power, FartConfig.SPIN_THRUST * power
	else
		return -right * FartConfig.THRUST * FartConfig.SIDE_THRUST * power, -FartConfig.SPIN_THRUST * power
	end
end

return FartPhysics
