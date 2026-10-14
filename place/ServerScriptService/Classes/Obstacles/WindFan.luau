--!strict
-- ModuleScript: ServerScriptService.Classes.Obstacles.WindFan
--
-- A big fan that blows boats sideways: while it's on, every boat whose middle is inside
-- its Wind zone is pushed toward the zone's front face. It blows for OnTime, rests for
-- OffTime, and so on. While it blows, the Model's Blowing attribute is true, its fan
-- (if it has one) spins up, and any ParticleEmitters, Beams and Sounds inside it are on.
-- The push is a force, so heavier boats are pushed less, and the crew can fart against it.
--
-- Parts:
--   Wind     Part   the zone that blows (boats are pushed toward its front face). Make it
--                   CanCollide off and see-through or invisible.
--   Base     Part   optional: the fan's fixed axle. Its fan turns around the line through
--                   Base's middle along its front face.
--   Moving   Part   optional: the fan, with its blades welded to it.
--
-- Settings (attributes on the Model, defaults in ObstacleConfig.WIND_FAN):
--   Strength     studs/s² of push on a boat of FartConfig.REFERENCE_MASS
--   OnTime, OffTime, StartDelay   seconds
--   Speed        turns a minute its fan spins at while it blows

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Attributes = require(ReplicatedStorage.Shared.Modules.Core.Attributes)
local Cycle = require(ReplicatedStorage.Shared.Modules.Math.Cycle)
local FartConfig = require(ReplicatedStorage.Shared.Modules.Game.FartConfig)
local Geometry = require(ReplicatedStorage.Shared.Modules.Math.Geometry)
local ObstacleConfig = require(ReplicatedStorage.Shared.Modules.Game.ObstacleConfig)
local ObstacleRig = require(ServerScriptService.Classes.Obstacles.ObstacleRig)
local ObstacleServiceShared = require(ReplicatedStorage.Shared.Services.ObstacleService.ObstacleServiceShared)

local WindFan = {}
WindFan.__index = WindFan

type WindFanMembers = {
	Model: Model,
	Wind: BasePart,
	Hinge: HingeConstraint?, -- spins its fan, if it has one
	Effects: { Instance }, -- ParticleEmitters, Beams and Sounds to switch on while it blows
	Force: number, -- Roblox force units it pushes with
	SpinSpeed: number, -- rad/s its fan spins at while it blows
	OnTime: number,
	OffTime: number,
	StartDelay: number,
	IsBlowing: boolean,
}

export type WindFan = typeof(setmetatable({} :: WindFanMembers, WindFan))

-- Sets up `model`, or returns a description of what's wrong with it.
function WindFan.new(model: Model, serverTime: number): (WindFan?, string?)
	local wind = model:FindFirstChild(ObstacleServiceShared.WIND_NAME)
	if not wind or not wind:IsA("BasePart") then
		return nil, `has no part named {ObstacleServiceShared.WIND_NAME}`
	end
	wind.Anchored = true
	wind.CanCollide = false
	wind.CanTouch = false
	wind.CanQuery = false

	local defaults = ObstacleConfig.WIND_FAN
	local hinge: HingeConstraint? = nil
	local hasFan = model:FindFirstChild(ObstacleServiceShared.BASE_NAME) ~= nil
		or model:FindFirstChild(ObstacleServiceShared.MOVING_NAME) ~= nil
	if hasFan then
		local rig, problem = ObstacleRig.new(model)
		if not rig then
			return nil, problem
		end
		local fanHinge = rig:AddHinge()
		fanHinge.ActuatorType = Enum.ActuatorType.Motor
		fanHinge.MotorMaxTorque = math.huge
		fanHinge.MotorMaxAcceleration = ObstacleConfig.FAN_SPIN_ACCELERATION
		fanHinge.AngularVelocity = 0
		rig:Release()
		hinge = fanHinge
	end

	local effects: { Instance } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("ParticleEmitter") or descendant:IsA("Beam") or descendant:IsA("Sound") then
			table.insert(effects, descendant)
		end
	end

	local self = setmetatable(
		{
			Model = model,
			Wind = wind,
			Hinge = hinge,
			Effects = effects,
			Force = Attributes.GetNumber(model, "Strength", defaults.Strength) * FartConfig.REFERENCE_MASS,
			SpinSpeed = Attributes.GetNumber(model, "Speed", defaults.Speed) * 2 * math.pi / 60,
			OnTime = math.max(Attributes.GetNumber(model, "OnTime", defaults.OnTime), 0),
			OffTime = math.max(Attributes.GetNumber(model, "OffTime", defaults.OffTime), 0),
			StartDelay = Attributes.GetNumber(model, "StartDelay", defaults.StartDelay),
			IsBlowing = false,
		} :: WindFanMembers,
		WindFan
	)
	self:SetBlowing(self:ShouldBlow(serverTime))
	return self, nil
end

function WindFan.ShouldBlow(self: WindFan, serverTime: number): boolean
	return Cycle.IsOn(serverTime, self.OnTime, self.OffTime, self.StartDelay)
end

-- Turns it on or off for server time `serverTime`.
function WindFan.Update(self: WindFan, serverTime: number)
	local shouldBlow = self:ShouldBlow(serverTime)
	if shouldBlow ~= self.IsBlowing then
		self:SetBlowing(shouldBlow)
	end
end

function WindFan.SetBlowing(self: WindFan, isBlowing: boolean)
	self.IsBlowing = isBlowing
	self.Model:SetAttribute(ObstacleServiceShared.BLOWING_ATTRIBUTE, isBlowing)
	local hinge = self.Hinge
	if hinge then
		hinge.AngularVelocity = if isBlowing then self.SpinSpeed else 0
	end
	for _, effect in self.Effects do
		if effect:IsA("ParticleEmitter") then
			effect.Enabled = isBlowing
		elseif effect:IsA("Beam") then
			effect.Enabled = isBlowing
		elseif effect:IsA("Sound") then
			if isBlowing then
				effect:Play()
			else
				effect:Stop()
			end
		end
	end
end

-- The push on something with its middle at `position` (Roblox force units, flat), or
-- nil if it's not in the wind.
function WindFan.GetForceAt(self: WindFan, position: Vector3): Vector3?
	if not self.IsBlowing or not Geometry.IsPointInPart(position, self.Wind) then
		return nil
	end
	local direction = self.Wind.CFrame.LookVector * Vector3.new(1, 0, 1)
	if direction.Magnitude < 1e-3 then
		return nil
	end
	return direction.Unit * self.Force
end

return WindFan
