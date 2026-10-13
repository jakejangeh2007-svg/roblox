--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.FartService.FartPhysics
--
-- The rules for what one fart does. Pure math, shared by the server (which moves
-- the boat) and the client (which predicts gas use and plays effects straight away).
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

-- Holding a fart key at least MEGA_MIN_HOLD seconds turns a toot into a Mega Fart.
function FartPhysics.IsMega(heldTime: number): boolean
	return heldTime >= FartConfig.MEGA_MIN_HOLD
end

function FartPhysics.GetCost(heldTime: number): number
	return if FartPhysics.IsMega(heldTime) then FartConfig.MEGA_COST else FartConfig.TOOT_COST
end

-- 1 for a toot, up to MEGA_MULT for a fully charged Mega Fart.
function FartPhysics.GetPower(heldTime: number): number
	if not FartPhysics.IsMega(heldTime) then
		return 1
	end
	local charge = math.clamp(heldTime / FartConfig.MEGA_CHARGE_TIME, 0, 1)
	return 1 + (FartConfig.MEGA_MULT - 1) * charge
end

-- How much one fart from `seatCFrame` changes the boat's velocity (studs/s) and its
-- turn speed (rad/s). A positive turn is a LEFT turn (counter-clockwise seen from above).
function FartPhysics.GetKick(
	boatPosition: Vector3,
	seatCFrame: CFrame,
	direction: Direction,
	power: number
): (Vector3, number)
	local facing = BoatServiceShared.GetRiderFacing(boatPosition, seatCFrame)
	local right = facing:Cross(Vector3.yAxis) -- the rider's right hand

	if direction == "Straight" then
		-- Gas goes out behind the rider, so the boat moves away from them.
		return facing * FartConfig.PUSH_SPEED * power, 0
	elseif direction == "Left" then
		-- Like an outboard motor: shove our side right so the far side swings left.
		return right * FartConfig.PUSH_SPEED * FartConfig.SIDE_PUSH * power, FartConfig.SPIN_SPEED * power
	else
		return -right * FartConfig.PUSH_SPEED * FartConfig.SIDE_PUSH * power, -FartConfig.SPIN_SPEED * power
	end
end

return FartPhysics
