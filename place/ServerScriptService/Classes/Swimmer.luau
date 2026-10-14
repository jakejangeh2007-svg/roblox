--!strict
-- ModuleScript: ServerScriptService.Classes.Swimmer
--
-- How an overboard player's body moves in the water. The server runs its physics while
-- it's overboard (like it runs boats), so where swimmers are is always the server's call.
-- OverboardService makes a Swimmer when a rider is knocked off and steps it every frame
-- with what the water under them is doing.
--   - While they're knocked out their body is limp (the Ragdoll class): every loose part
--     of it floats on its own, so it lies sprawled on the surface, tumbling to a stop.
--   - Once they come round they swim: their body faces where they're heading and floats
--     with its head and shoulders out of the water. Farting pushes them the way they
--     face, and they turn left and right.
--   - Either way the water holds them up like a soft spring and drags them toward its own
--     speed, so currents carry them along, and rapids shove them about. Out of the water
--     only gravity acts on them.
-- Their body goes in the Swimmers collision group: it bumps into the map and obstacles,
-- but passes through boats and other swimmers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local FartConfig = require(ReplicatedStorage.Shared.Modules.Game.FartConfig)
local Hull = require(ServerScriptService.Classes.Hull)
local OverboardConfig = require(ReplicatedStorage.Shared.Modules.Game.OverboardConfig)
local OverboardServiceShared = require(ReplicatedStorage.Shared.Services.OverboardService.OverboardServiceShared)

local FACING_NAME = "SwimFacing"
-- Changes to the way a swimmer faces smaller than this aren't worth sending to the
-- Facing constraint (every change is sent to every player).
local MIN_FACING_CHANGE = math.rad(1)

-- The part of water drag that grows with speed, sized so a swimmer farting at full
-- strength levels off at TOP_SPEED.
local SPEED_DRAG = math.max(
	0,
	(
		FartConfig.MAX_PUSH_ACCELERATION * OverboardConfig.FART_PUSH_SCALE
		- OverboardConfig.GLIDE_DRAG * OverboardConfig.TOP_SPEED
	) / OverboardConfig.TOP_SPEED ^ 2
)

local Swimmer = {}
Swimmer.__index = Swimmer

type SwimmerMembers = {
	RootPart: BasePart, -- their HumanoidRootPart
	Parts: { BasePart }, -- every part of their body
	CollisionGroups: { [BasePart]: string }, -- each part's collision group from before, to put back
	IsSwimming: boolean, -- false while they're knocked out
	Heading: Vector3, -- the way they face and swim, flat on the water
	TurnSpeed: number, -- radians per second, positive turns left (counter-clockwise from above)
	Facing: AlignOrientation?, -- turns their body to face Heading while they swim
	LastWaterHeight: number, -- the surface height they were last in (where they started at first)
}

export type Swimmer = typeof(setmetatable({} :: SwimmerMembers, Swimmer))

local function Flatten(vector: Vector3): Vector3
	local flat = Vector3.new(vector.X, 0, vector.Z)
	return if flat.Magnitude > 1e-6 then flat.Unit else -Vector3.zAxis
end

-- Takes over `character`'s body (with `rootPart` its HumanoidRootPart): the server runs
-- its physics from now on, and it bumps into what swimmers bump into.
function Swimmer.new(character: Model, rootPart: BasePart): Swimmer
	local parts = {}
	local collisionGroups: { [BasePart]: string } = {}
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
			collisionGroups[descendant] = descendant.CollisionGroup
			descendant.CollisionGroup = OverboardServiceShared.COLLISION_GROUP
		end
	end

	local self = setmetatable(
		{
			RootPart = rootPart,
			Parts = parts,
			CollisionGroups = collisionGroups,
			IsSwimming = false,
			Heading = Flatten(rootPart.CFrame.LookVector),
			TurnSpeed = 0,
			Facing = nil,
			LastWaterHeight = rootPart.Position.Y,
		} :: SwimmerMembers,
		Swimmer
	)
	self:ClaimNetworkOwnership()
	return self
end

-- The root part of every separate piece of the body (just one once it's stiff again).
function Swimmer.GetAssemblyRoots(self: Swimmer): { BasePart }
	local roots: { BasePart } = {}
	local found: { [BasePart]: boolean } = {}
	for _, part in self.Parts do
		local root = part.AssemblyRootPart
		if root and not found[root] and not root.Anchored and root:IsDescendantOf(workspace) then
			found[root] = true
			table.insert(roots, root)
		end
	end
	return roots
end

-- Makes sure the server runs the body's physics. Its player can otherwise end up
-- running it, so this is checked every step.
function Swimmer.ClaimNetworkOwnership(self: Swimmer)
	for _, root in self:GetAssemblyRoots() do
		if root:CanSetNetworkOwnership() and (root:GetNetworkOwnershipAuto() or root:GetNetworkOwner() ~= nil) then
			root:SetNetworkOwner(nil)
		end
	end
end

-- Sends the whole body flying at `velocity`, tumbling at `spin` (radians per second about
-- each axis) all in one piece.
function Swimmer.Throw(self: Swimmer, velocity: Vector3, spin: Vector3)
	local center = self.RootPart.AssemblyCenterOfMass
	for _, root in self:GetAssemblyRoots() do
		root.AssemblyLinearVelocity = velocity + spin:Cross(root.AssemblyCenterOfMass - center)
		root.AssemblyAngularVelocity = spin
	end
end

-- They've come round (their body must be stiff again): they face `heading` and start
-- swimming.
function Swimmer.StartSwimming(self: Swimmer, heading: Vector3)
	if self.IsSwimming then
		return
	end
	self.IsSwimming = true
	self.Heading = Flatten(heading)
	self.TurnSpeed = 0

	local attachment = Instance.new("Attachment")
	attachment.Name = FACING_NAME
	attachment.Parent = self.RootPart
	local facing = Instance.new("AlignOrientation")
	facing.Name = FACING_NAME
	facing.Mode = Enum.OrientationAlignmentMode.OneAttachment
	facing.AlignType = Enum.AlignType.AllAxes
	facing.Attachment0 = attachment
	facing.MaxTorque = math.huge
	facing.Responsiveness = OverboardConfig.FACING_RESPONSIVENESS
	facing.CFrame = CFrame.lookAt(Vector3.zero, self.Heading)
	facing.Parent = self.RootPart
	self.Facing = facing
	self.RootPart.AssemblyAngularVelocity = Vector3.zero
end

-- Has the Facing constraint turn the body toward Heading.
function Swimmer.UpdateFacing(self: Swimmer)
	local facing = self.Facing
	if not facing then
		return
	end
	if facing.CFrame.LookVector:Dot(self.Heading) < math.cos(MIN_FACING_CHANGE) then
		facing.CFrame = CFrame.lookAt(Vector3.zero, self.Heading)
	end
end

-- Moves the body on by `deltaTime` seconds. `water` is what the water under them is
-- doing, or nil if there's no water under them. While they swim, `pushAcceleration`
-- (studs/s²) pushes them the way they face, and they turn `turnDirection` (-1 left,
-- 1 right, 0 not at all).
function Swimmer.Step(
	self: Swimmer,
	water: Hull.Water?,
	pushAcceleration: number,
	turnDirection: number,
	deltaTime: number
)
	if deltaTime <= 0 then
		return
	end
	self:ClaimNetworkOwnership()

	if self.IsSwimming then
		local blend = if OverboardConfig.TURN_RESPONSE_TIME > 0
			then 1 - math.exp(-deltaTime / OverboardConfig.TURN_RESPONSE_TIME)
			else 1
		local targetTurnSpeed = -turnDirection * OverboardConfig.TURN_SPEED
		self.TurnSpeed += (targetTurnSpeed - self.TurnSpeed) * blend
		if water then
			self.TurnSpeed += water.TurnTurbulence * deltaTime
		end
		self.Heading = Flatten(CFrame.Angles(0, self.TurnSpeed * deltaTime, 0) * self.Heading)
		self:UpdateFacing()
	end

	if not water then
		return -- out of the water, only gravity acts on them
	end
	self.LastWaterHeight = water.SurfaceHeight
	local swimmingRoot = self.RootPart.AssemblyRootPart
	local floatHeight = if self.IsSwimming then OverboardConfig.FLOAT_HEIGHT else OverboardConfig.LIMP_FLOAT_HEIGHT
	local gravity = workspace.Gravity

	for _, root in self:GetAssemblyRoots() do
		local isSwimmingRoot = self.IsSwimming and root == swimmingRoot
		local height = if isSwimmingRoot then self.RootPart.Position.Y else root.AssemblyCenterOfMass.Y

		-- How much this piece is in the water: 1 at or below the surface, fading to 0 at
		-- AIRBORNE_HEIGHT above it. Everything the water does is scaled by this.
		local depth = water.SurfaceHeight + floatHeight - height
		local wetness = math.clamp(1 + depth / math.max(OverboardConfig.AIRBORNE_HEIGHT, 1e-3), 0, 1)
		if wetness <= 0 then
			continue
		end
		local velocity = root.AssemblyLinearVelocity

		-- Up and down: the water holds up its weight, pushes back up on it when it's
		-- under, and settles the bobbing. Applied implicitly, so it never overshoots.
		local verticalSpeed = velocity.Y
		local submergedDepth = math.clamp(depth, 0, OverboardConfig.MAX_FLOAT_DEPTH)
		local verticalDamping = wetness
			* (OverboardConfig.FLOAT_DAMPING + OverboardConfig.SPLASH_DAMPING * math.abs(verticalSpeed))
		verticalSpeed = (
			verticalSpeed + (gravity * wetness + OverboardConfig.FLOAT_STIFFNESS * submergedDepth) * deltaTime
		) / (1 + verticalDamping * deltaTime)

		-- Across the water: farting (while swimming) and rough water speed it up, and drag
		-- pulls its speed toward the water's.
		local flow = Vector3.new(water.FlowVelocity.X, 0, water.FlowVelocity.Z) * wetness
		local acceleration = Vector3.new(water.Turbulence.X, 0, water.Turbulence.Z)
			* (OverboardConfig.TURBULENCE_SCALE * wetness)
		if isSwimmingRoot then
			acceleration += self.Heading * pushAcceleration * wetness
		end
		local relativeVelocity = Vector3.new(velocity.X, 0, velocity.Z) - flow
		local glideDrag = if self.IsSwimming then OverboardConfig.GLIDE_DRAG else OverboardConfig.LIMP_DRAG
		local drag = wetness * (glideDrag + SPEED_DRAG * relativeVelocity.Magnitude)
		relativeVelocity = (relativeVelocity + acceleration * deltaTime) / (1 + drag * deltaTime)
		local flatVelocity = relativeVelocity + flow
		root.AssemblyLinearVelocity = Vector3.new(flatVelocity.X, verticalSpeed, flatVelocity.Z)

		-- A limp body stops tumbling in the water.
		if not self.IsSwimming then
			local spinDamping = math.exp(-OverboardConfig.LIMP_SPIN_DAMPING * wetness * deltaTime)
			root.AssemblyAngularVelocity *= spinDamping
		end
	end
end

-- Hands the body back, stopped still: puts back its collision groups and stops running
-- its physics. `owner` (its player) gets to run its physics again straight away; without
-- one, Roblox decides who does.
function Swimmer.Destroy(self: Swimmer, owner: Player?)
	local facing = self.Facing
	if facing then
		local attachment = facing.Attachment0
		facing:Destroy()
		if attachment then
			attachment:Destroy()
		end
		self.Facing = nil
	end
	self.IsSwimming = false
	for part, collisionGroup in self.CollisionGroups do
		if part.Parent then
			part.CollisionGroup = collisionGroup
		end
	end
	for _, root in self:GetAssemblyRoots() do
		-- Whatever happens to them next starts from a standstill.
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		if root:CanSetNetworkOwnership() then
			if owner and owner.Parent then
				root:SetNetworkOwner(owner)
			else
				root:SetNetworkOwnershipAuto()
			end
		end
	end
end

return Swimmer
