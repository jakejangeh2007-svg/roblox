--!strict
-- The rules for what one fart does. Pure math with no side effects, shared by
-- the server (which moves the boat) and the client (which predicts gas use and
-- plays effects straight away).

local Config = require(script.Parent.Config)

local FartPhysics = {}

export type Direction = "Left" | "Straight" | "Right"

function FartPhysics.isDirection(value: unknown): boolean
	return value == "Left" or value == "Straight" or value == "Right"
end

-- Holding a fart key at least MEGA_MIN_HOLD seconds turns a toot into a Mega Fart.
function FartPhysics.isMega(heldTime: number): boolean
	return heldTime >= Config.MEGA_MIN_HOLD
end

function FartPhysics.getCost(heldTime: number): number
	return if FartPhysics.isMega(heldTime) then Config.MEGA_COST else Config.TOOT_COST
end

-- 1 for a toot, up to MEGA_MULT for a fully charged Mega Fart.
function FartPhysics.getPower(heldTime: number): number
	if not FartPhysics.isMega(heldTime) then
		return 1
	end
	local charge = math.clamp(heldTime / Config.MEGA_CHARGE_TIME, 0, 1)
	return 1 + (Config.MEGA_MULT - 1) * charge
end

-- How much one fart from a seat changes the boat's velocity (studs/s) and its
-- turn speed (rad/s). A positive turn is a LEFT turn (counter-clockwise seen
-- from above), and "Left" means a left turn from every seat.
--
-- Riders face the middle of the boat, so with seats spread evenly around the
-- ring everyone farting Straight cancels out, and everyone farting Left spins
-- the boat on the spot.
function FartPhysics.getKick(
	boatCFrame: CFrame,
	seatPosition: Vector3,
	direction: Direction,
	power: number
): (Vector3, number)
	local toCenter = (boatCFrame.Position - seatPosition) * Vector3.new(1, 0, 1)
	if toCenter.Magnitude < 1e-3 then
		return Vector3.zero, 0
	end
	local facing = toCenter.Unit -- the way this rider faces
	local right = facing:Cross(Vector3.yAxis) -- this rider's right hand

	if direction == "Straight" then
		-- gas goes out behind the rider, so the boat moves away from them
		return facing * Config.PUSH_SPEED * power, 0
	elseif direction == "Left" then
		-- like an outboard motor: shove our side right so the far side swings left
		return right * Config.PUSH_SPEED * Config.SIDE_PUSH * power, Config.SPIN_SPEED * power
	else
		return -right * Config.PUSH_SPEED * Config.SIDE_PUSH * power, -Config.SPIN_SPEED * power
	end
end

return FartPhysics
