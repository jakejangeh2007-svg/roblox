--!strict
-- ModuleScript: ServerScriptService.Classes.Hull
--
-- How a boat on the river moves. This is the one place a floating boat's velocity is
-- worked out, all in one go every frame, so nothing fights over it. A Boat makes its
-- Hull when it launches, and WaterService steps it every frame with what the water
-- under it is doing and how hard its crew is farting (FartService):
--   - Farts push and turn it, scaled by its size's handling (BoatConfig.HANDLING).
--   - Water drags it toward the water's own speed: gently when it's slow, so it glides
--     on when the crew stops, and harder when it's fast, so it levels off smoothly at
--     its top speed. Currents carry it along, and rough water shoves and twists it.
--   - The water holds it up like a soft spring, so it bobs on the waves and settles
--     after a drop instead of bouncing back out. Above the surface that hold fades out;
--     in the air only gravity, a little air drag and the farts act on it.
--   - It rocks with the waves and leans away from the way it's speeding up or turning.
-- Bumping into things is left to Roblox physics, which the server runs for the boat.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoatConfig = require(ReplicatedStorage.Shared.Modules.Game.BoatConfig)
local FartConfig = require(ReplicatedStorage.Shared.Modules.Game.FartConfig)
local WaterConfig = require(ReplicatedStorage.Shared.Modules.Game.WaterConfig)

-- What the water under a boat is doing (WaterService works it out).
export type Water = {
	SurfaceHeight: number, -- height of the surface right under the boat, waves included
	SurfaceNormal: Vector3, -- straight up from the surface there, tilted by the waves
	FlowVelocity: Vector3, -- how fast the water itself is moving
	Turbulence: Vector3, -- shove from rough water, in studs/s²
	TurnTurbulence: number, -- twist from rough water, in rad/s² (positive turns left)
}

-- The part of water drag that grows with speed, sized so one rider farting Straight at
-- full strength (on a boat with PushScale 1) levels off at TOP_SPEED.
local SPEED_DRAG = math.max(
	0,
	(FartConfig.MAX_STRAIGHT_ACCELERATION - WaterConfig.GLIDE_DRAG * WaterConfig.TOP_SPEED) / WaterConfig.TOP_SPEED ^ 2
)
-- Changes to the tilt the boat aims for smaller than this aren't worth sending to the
-- Upright constraint (every change is sent to every player).
local MIN_UPRIGHT_CHANGE = math.rad(0.5)

local Hull = {}
Hull.__index = Hull

type HullMembers = {
	PrimaryPart: BasePart,
	Handling: BoatConfig.Handling,
	TurnSpeedDrag: number, -- like SPEED_DRAG but for turning, sized from Handling.TopTurnSpeed
	Upright: AlignOrientation, -- tilts the boat toward the up direction it should have
	Buoyancy: VectorForce, -- holds up the boat's weight while it's in the water
	LastWaterHeight: number, -- the surface height it was last over (its launch height at first)
	LastFlatVelocity: Vector3, -- its velocity across the water after the last step
	LeanAcceleration: Vector3, -- its recent acceleration across the water, smoothed, for leaning
}

export type Hull = typeof(setmetatable({} :: HullMembers, Hull))

-- The turning drag that grows with turn speed, sized so one rider turning at full
-- strength levels off at the boat's TopTurnSpeed.
local function GetTurnSpeedDrag(handling: BoatConfig.Handling): number
	local topTurnSpeed = handling.TopTurnSpeed
	if topTurnSpeed <= 0 then
		return 0
	end
	local maxTurnAcceleration = FartConfig.MAX_TURN_ACCELERATION * handling.TurnScale
	return math.max(0, (maxTurnAcceleration - WaterConfig.TURN_GLIDE_DRAG * topTurnSpeed) / topTurnSpeed ^ 2)
end

-- `up` (made unit length), tilted back toward straight up if it's more than `maxTilt`
-- radians away from it.
local function LimitTilt(up: Vector3, maxTilt: number): Vector3
	if up.Magnitude < 1e-6 then
		return Vector3.yAxis
	end
	local unitUp = up.Unit
	local flat = Vector3.new(unitUp.X, 0, unitUp.Z)
	if math.acos(math.clamp(unitUp.Y, -1, 1)) <= maxTilt or flat.Magnitude < 1e-6 then
		return unitUp
	end
	return Vector3.yAxis * math.cos(maxTilt) + flat.Unit * math.sin(maxTilt)
end

-- Hands the boat whose PrimaryPart is `primaryPart` over to physics: unanchors it,
-- makes the server run it and starts keeping it upright. `seatCount` picks its handling.
function Hull.new(primaryPart: BasePart, seatCount: number): Hull
	local handling = BoatConfig.HANDLING[seatCount] or BoatConfig.HANDLING[BoatConfig.MAX_SEATS]

	local attachment = Instance.new("Attachment")
	attachment.Name = "HullAttachment"
	-- The attachment's primary axis (its X axis) points along the boat's up direction.
	attachment.CFrame = CFrame.fromMatrix(Vector3.zero, Vector3.yAxis, Vector3.xAxis)
	attachment.Parent = primaryPart

	local upright = Instance.new("AlignOrientation")
	upright.Name = "Upright"
	upright.Mode = Enum.OrientationAlignmentMode.OneAttachment
	upright.AlignType = Enum.AlignType.PrimaryAxisParallel
	upright.PrimaryAxis = Vector3.yAxis
	upright.Attachment0 = attachment
	upright.MaxTorque = math.huge
	upright.Responsiveness = BoatConfig.UPRIGHT_RESPONSIVENESS
	upright.Parent = primaryPart

	local buoyancy = Instance.new("VectorForce")
	buoyancy.Name = "Buoyancy"
	buoyancy.Attachment0 = attachment
	buoyancy.RelativeTo = Enum.ActuatorRelativeTo.World
	buoyancy.ApplyAtCenterOfMass = true
	buoyancy.Force = Vector3.zero
	buoyancy.Parent = primaryPart

	local self = setmetatable(
		{
			PrimaryPart = primaryPart,
			Handling = handling,
			TurnSpeedDrag = GetTurnSpeedDrag(handling),
			Upright = upright,
			Buoyancy = buoyancy,
			LastWaterHeight = primaryPart.Position.Y,
			LastFlatVelocity = Vector3.zero,
			LeanAcceleration = Vector3.zero,
		} :: HullMembers,
		Hull
	)

	primaryPart.Anchored = false
	primaryPart.AssemblyLinearVelocity = Vector3.zero
	primaryPart.AssemblyAngularVelocity = Vector3.zero
	self:ClaimNetworkOwnership()
	return self
end

-- Makes sure the server runs the boat's physics. Seated players can otherwise end up
-- running it, so this is checked every step.
function Hull.ClaimNetworkOwnership(self: Hull)
	local primaryPart = self.PrimaryPart
	if not primaryPart:CanSetNetworkOwnership() then
		return
	end
	if primaryPart:GetNetworkOwnershipAuto() or primaryPart:GetNetworkOwner() ~= nil then
		primaryPart:SetNetworkOwner(nil)
	end
end

-- Moves the boat on by `deltaTime` seconds. `water` is what the water under it is doing,
-- or nil if there's no water under it. `thrust` (studs/s²) and `turn` (rad/s², positive
-- turns left) are its crew's farts, before its handling scales them.
function Hull.Step(self: Hull, water: Water?, thrust: Vector3, turn: number, deltaTime: number)
	if deltaTime <= 0 then
		return
	end
	self:ClaimNetworkOwnership()
	local primaryPart = self.PrimaryPart
	local handling = self.Handling
	local velocity = primaryPart.AssemblyLinearVelocity
	local spin = primaryPart.AssemblyAngularVelocity

	-- How much the boat is in the water: 1 at or below the surface, fading to 0 at
	-- AIRBORNE_HEIGHT above it. Everything the water does is scaled by this.
	local depth = 0
	local wetness = 0
	local flow = Vector3.zero
	local shove = Vector3.zero
	local twist = 0
	local surfaceUp = Vector3.yAxis
	if water then
		self.LastWaterHeight = water.SurfaceHeight
		depth = water.SurfaceHeight + WaterConfig.FLOAT_HEIGHT - primaryPart.Position.Y
		wetness = math.clamp(1 + depth / math.max(WaterConfig.AIRBORNE_HEIGHT, 1e-3), 0, 1)
		flow = Vector3.new(water.FlowVelocity.X, 0, water.FlowVelocity.Z) * wetness
		shove = Vector3.new(water.Turbulence.X, 0, water.Turbulence.Z) * wetness
		twist = water.TurnTurbulence * wetness
		surfaceUp = Vector3.yAxis:Lerp(water.SurfaceNormal, wetness)
	end
	local dragScale = WaterConfig.AIR_DRAG + (1 - WaterConfig.AIR_DRAG) * wetness

	-- Across the water: farts and rough water push it, and drag pulls its speed toward
	-- the water's. Drag is applied implicitly (dividing instead of subtracting), so it
	-- can never overshoot and send the boat backwards, however long the frame.
	local push = Vector3.new(thrust.X, 0, thrust.Z) + shove
	local relativeVelocity = Vector3.new(velocity.X, 0, velocity.Z) - flow
	local drag = dragScale * (WaterConfig.GLIDE_DRAG + SPEED_DRAG * relativeVelocity.Magnitude)
	relativeVelocity = (relativeVelocity + push * handling.PushScale * deltaTime) / (1 + drag * deltaTime)
	local flatVelocity = relativeVelocity + flow

	-- Turning, the same way.
	local turnSpeed = spin.Y
	local turnDrag = dragScale * (WaterConfig.TURN_GLIDE_DRAG + self.TurnSpeedDrag * math.abs(turnSpeed))
	turnSpeed = (turnSpeed + (turn + twist) * handling.TurnScale * deltaTime) / (1 + turnDrag * deltaTime)

	-- Up and down: Buoyancy holds the boat's weight while it's in the water, the water
	-- pushes back up on a boat that's pushed under, and damping settles the bobbing
	-- (harder the faster it's moving, so a boat landing hard stops quickly).
	self:SetBuoyancy(wetness)
	local verticalSpeed = velocity.Y
	local submergedDepth = math.clamp(depth, 0, WaterConfig.MAX_FLOAT_DEPTH)
	local verticalDamping = wetness * (WaterConfig.FLOAT_DAMPING + WaterConfig.SPLASH_DAMPING * math.abs(verticalSpeed))
	verticalSpeed = (verticalSpeed + WaterConfig.FLOAT_STIFFNESS * submergedDepth * deltaTime)
		/ (1 + verticalDamping * deltaTime)

	primaryPart.AssemblyLinearVelocity = Vector3.new(flatVelocity.X, verticalSpeed, flatVelocity.Z)
	local tiltDamping = math.exp(-WaterConfig.TILT_DAMPING * wetness * deltaTime)
	primaryPart.AssemblyAngularVelocity = Vector3.new(spin.X * tiltDamping, turnSpeed, spin.Z * tiltDamping)

	-- Tilt: with the waves, and away from the way it's speeding up, slowing down or
	-- turning (bumps included), smoothed so it eases into and out of each lean.
	local acceleration = (flatVelocity - self.LastFlatVelocity) / deltaTime
	self.LastFlatVelocity = flatVelocity
	local leanBlend = 1 - math.exp(-BoatConfig.LEAN_SMOOTHING * deltaTime)
	self.LeanAcceleration = self.LeanAcceleration:Lerp(acceleration, leanBlend)
	self:SetUpDirection(surfaceUp - self.LeanAcceleration * BoatConfig.LEAN_PER_ACCELERATION)
end

-- Has the water hold up `wetness` (0 to 1) of the boat's weight.
function Hull.SetBuoyancy(self: Hull, wetness: number)
	local force = Vector3.new(0, self.PrimaryPart.AssemblyMass * workspace.Gravity * wetness, 0)
	-- Only changes are sent; while the boat floats this stays the same.
	if self.Buoyancy.Force ~= force then
		self.Buoyancy.Force = force
	end
end

-- Has the boat tilt toward `up` (within BoatConfig.MAX_TILT of level).
function Hull.SetUpDirection(self: Hull, up: Vector3)
	local target = LimitTilt(up, BoatConfig.MAX_TILT)
	if self.Upright.PrimaryAxis:Dot(target) < math.cos(MIN_UPRIGHT_CHANGE) then
		self.Upright.PrimaryAxis = target
	end
end

return Hull
