--!strict
-- ModuleScript: ServerScriptService.Classes.Hull
--
-- How a boat on the river moves: as a real rigid body. This is the one place a floating
-- boat's velocity is worked out, all in one go every frame, so nothing fights over it.
-- A Boat makes its Hull when it launches, and WaterService steps it every frame with
-- what the water under it is doing and the pushes from its crew's farts (FartService).
--   - Each fart is a force applied where its rider sits. The forces speed the boat up by
--     force / mass, and spin it by torque / moment of inertia, both worked out from the
--     boat's real parts and riders. A push through the middle only moves the boat; a push
--     off to one side also spins it. Big, heavy boats are slower to move and to spin.
--   - Water drags it toward the water's own speed: gently when it's slow, so it glides
--     on when the crew stops, and harder when it's fast, so it levels off smoothly at
--     its top speed. The same water drag, acting round the rim, slows its spinning.
--     Currents carry it along, and rough water shoves and twists it.
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

-- A force on the boat (in Roblox force units) and the point in the world it acts at.
export type AppliedForce = {
	Position: Vector3,
	Force: Vector3,
}

-- The part of water drag that grows with speed, sized so one rider pushing at full
-- strength levels a boat of FartConfig.REFERENCE_MASS off at TOP_SPEED.
local SPEED_DRAG = math.max(
	0,
	(FartConfig.MAX_PUSH_ACCELERATION - WaterConfig.GLIDE_DRAG * WaterConfig.TOP_SPEED) / WaterConfig.TOP_SPEED ^ 2
)
-- Changes to the tilt the boat aims for smaller than this aren't worth sending to the
-- Upright constraint (every change is sent to every player).
local MIN_UPRIGHT_CHANGE = math.rad(0.5)

local Hull = {}
Hull.__index = Hull

type HullMembers = {
	PrimaryPart: BasePart,
	Upright: AlignOrientation, -- tilts the boat toward the up direction it should have
	Buoyancy: VectorForce, -- holds up the boat's weight while it's in the water
	Mass: number, -- what the boat and its riders weigh, when SpinInertia was worked out
	SpinInertia: number, -- moment of inertia for spinning flat on the water, about its center of mass
	LastWaterHeight: number, -- the surface height it was last over (its launch height at first)
	LastFlatVelocity: Vector3, -- its velocity across the water after the last step
	LeanAcceleration: Vector3, -- its recent acceleration across the water, smoothed, for leaning
}

export type Hull = typeof(setmetatable({} :: HullMembers, Hull))

-- `part`'s moment of inertia for spinning about a vertical line through its own middle.
-- Balls and cylinders use their own shapes; anything else counts as a box.
local function GetPartSpinInertia(part: BasePart): number
	local mass = part:GetMass()
	local size = part.Size
	if part:IsA("Part") and part.Shape == Enum.PartType.Ball then
		return 0.4 * mass * (math.min(size.X, size.Y, size.Z) / 2) ^ 2
	end

	-- About the part's own X, Y and Z axes
	local inertiaX, inertiaY, inertiaZ
	if part:IsA("Part") and part.Shape == Enum.PartType.Cylinder then
		-- A cylinder's length runs along its X axis.
		local radius = math.min(size.Y, size.Z) / 2
		inertiaX = 0.5 * mass * radius ^ 2
		inertiaY = mass * (3 * radius ^ 2 + size.X ^ 2) / 12
		inertiaZ = inertiaY
	else
		inertiaX = mass * (size.Y ^ 2 + size.Z ^ 2) / 12
		inertiaY = mass * (size.X ^ 2 + size.Z ^ 2) / 12
		inertiaZ = mass * (size.X ^ 2 + size.Y ^ 2) / 12
	end
	-- Straight up, in the part's own axes
	local up = part.CFrame:VectorToObjectSpace(Vector3.yAxis)
	return inertiaX * up.X ^ 2 + inertiaY * up.Y ^ 2 + inertiaZ * up.Z ^ 2
end

-- The moment of inertia for spinning flat on the water of everything joined to
-- `primaryPart` (the boat and its seated riders), about their shared center of mass.
local function GetSpinInertia(primaryPart: BasePart): number
	local centerOfMass = primaryPart.AssemblyCenterOfMass
	local parts: { [BasePart]: boolean } = { [primaryPart] = true }
	for _, part in primaryPart:GetConnectedParts(true) do
		parts[part] = true
	end
	local inertia = 0
	for part in parts do
		if not part.Massless then
			local offset = part.Position - centerOfMass
			inertia += GetPartSpinInertia(part) + part:GetMass() * (offset.X ^ 2 + offset.Z ^ 2)
		end
	end
	return math.max(inertia, 1e-3)
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
-- makes the server run it and starts keeping it upright. Its riders must be seated.
function Hull.new(primaryPart: BasePart): Hull
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
			Upright = upright,
			Buoyancy = buoyancy,
			Mass = primaryPart.AssemblyMass,
			SpinInertia = GetSpinInertia(primaryPart),
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
-- or nil if there's no water under it. `forces` are the pushes from its crew's farts.
function Hull.Step(self: Hull, water: Water?, forces: { AppliedForce }, deltaTime: number)
	if deltaTime <= 0 then
		return
	end
	self:ClaimNetworkOwnership()
	local primaryPart = self.PrimaryPart
	local velocity = primaryPart.AssemblyLinearVelocity
	local spin = primaryPart.AssemblyAngularVelocity

	-- What it weighs changes when a rider leaves; its moment of inertia changes with it.
	local mass = primaryPart.AssemblyMass
	if mass ~= self.Mass then
		self.Mass = mass
		self.SpinInertia = GetSpinInertia(primaryPart)
	end

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

	-- The farts, added up: their total force and their total torque about the center of
	-- mass (only the flat parts matter; the boat is kept upright).
	local centerOfMass = primaryPart.AssemblyCenterOfMass
	local totalForce = Vector3.zero
	local totalTorque = 0 -- about the vertical axis; positive spins it left (counter-clockwise from above)
	for _, appliedForce in forces do
		local force = Vector3.new(appliedForce.Force.X, 0, appliedForce.Force.Z)
		local offset = appliedForce.Position - centerOfMass
		totalForce += force
		totalTorque += offset.Z * force.X - offset.X * force.Z
	end

	-- Across the water: the farts and rough water speed it up, and drag pulls its speed
	-- toward the water's. Drag is applied implicitly (dividing instead of subtracting), so
	-- it can never overshoot and send the boat backwards, however long the frame.
	local acceleration = totalForce / mass + shove
	local relativeVelocity = Vector3.new(velocity.X, 0, velocity.Z) - flow
	local drag = dragScale * (WaterConfig.GLIDE_DRAG + SPEED_DRAG * relativeVelocity.Magnitude)
	relativeVelocity = (relativeVelocity + acceleration * deltaTime) / (1 + drag * deltaTime)
	local flatVelocity = relativeVelocity + flow

	-- Spinning: the torque turns it by torque / moment of inertia, and the water drags on
	-- its rim, which moves at the spin speed times its radius of gyration.
	local spinSpeed = spin.Y
	local gyrationRadius = math.sqrt(self.SpinInertia / mass)
	local rimSpeed = math.abs(spinSpeed) * gyrationRadius
	local spinDrag = dragScale * WaterConfig.SPIN_DRAG_SCALE * (WaterConfig.GLIDE_DRAG + SPEED_DRAG * rimSpeed)
	local spinAcceleration = totalTorque / self.SpinInertia + twist
	spinSpeed = (spinSpeed + spinAcceleration * deltaTime) / (1 + spinDrag * deltaTime)

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
	primaryPart.AssemblyAngularVelocity = Vector3.new(spin.X * tiltDamping, spinSpeed, spin.Z * tiltDamping)

	-- Tilt: with the waves, and away from the way it's speeding up, slowing down or
	-- turning (bumps included), smoothed so it eases into and out of each lean.
	local flatAcceleration = (flatVelocity - self.LastFlatVelocity) / deltaTime
	self.LastFlatVelocity = flatVelocity
	local leanBlend = 1 - math.exp(-BoatConfig.LEAN_SMOOTHING * deltaTime)
	self.LeanAcceleration = self.LeanAcceleration:Lerp(flatAcceleration, leanBlend)
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
