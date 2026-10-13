--!strict
-- ModuleScript: ServerScriptService.Services.WaterService.WaterServiceServer
--
-- Keeps boats on the river afloat: holds them at the water surface, slows them down
-- and pushes them along currents. Where there's no water under a boat, nothing holds
-- it up and it falls. A boat that falls FALL_DISTANCE below the last water it was on
-- has fallen off the river, and BoatService wipes it.
--
-- Map contract:
--   Workspace.Map.Water   Folder of parts whose TOP face is the water surface. Make them
--                         Anchored and CanCollide off. Parts named after an entry in
--                         WaterConfig.CURRENT_SPEEDS flow toward their front face.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Boat = require(ServerScriptService.Classes.Boat)
local BoatServiceServer = require(ServerScriptService.Services.BoatService.BoatServiceServer)
local WaterConfig = require(ReplicatedStorage.Shared.Modules.Game.WaterConfig)

local WaterServiceServer = {}

type WaterServiceServerMembers = {
	RaycastParameters: RaycastParams,
	LastWaterHeights: { [Boat.Boat]: number }, -- the surface height each boat last floated on
}

export type WaterServiceServer = typeof(WaterServiceServer) & WaterServiceServerMembers

-- The velocity the water's current gives things floating on `waterPart`.
local function GetCurrent(waterPart: Instance): Vector3
	local speed = WaterConfig.CURRENT_SPEEDS[waterPart.Name]
	if not speed or not waterPart:IsA("BasePart") then
		return Vector3.zero
	end
	local flatDirection = waterPart.CFrame.LookVector * Vector3.new(1, 0, 1)
	if flatDirection.Magnitude == 0 then
		return Vector3.zero
	end
	return flatDirection.Unit * speed
end

function WaterServiceServer.Init(self: WaterServiceServer)
	self.RaycastParameters = RaycastParams.new()
	self.RaycastParameters.FilterType = Enum.RaycastFilterType.Include
	self.LastWaterHeights = setmetatable({}, { __mode = "k" }) :: any

	local map = workspace:FindFirstChild("Map")
	local waterFolder = if map then map:FindFirstChild("Water") else nil
	if waterFolder then
		self.RaycastParameters.FilterDescendantsInstances = { waterFolder }
	else
		warn("Map piece missing: Workspace.Map.Water (a Folder of water surface parts). Boats will sink.")
	end

	RunService.Heartbeat:Connect(function(deltaTime)
		self:Update(deltaTime)
	end)
end

function WaterServiceServer.Update(self: WaterServiceServer, deltaTime: number)
	for _, boat in BoatServiceServer:GetLaunchedBoats() do
		local primaryPart = boat.Model.PrimaryPart
		if not primaryPart or not boat:IsFloating() then
			continue
		end

		local origin = primaryPart.Position + Vector3.new(0, WaterConfig.WATER_CHECK_ABOVE, 0)
		local reach = Vector3.new(0, -(WaterConfig.WATER_CHECK_ABOVE + WaterConfig.WATER_CHECK_BELOW), 0)
		local hit = workspace:Raycast(origin, reach, self.RaycastParameters)
		if hit then
			self.LastWaterHeights[boat] = hit.Position.Y
			self:Float(primaryPart, hit, deltaTime)
		else
			-- Nothing holds it up. Before it has floated anywhere, measure from where it launched.
			local lastWaterHeight = self.LastWaterHeights[boat] or boat.LaunchCFrame.Position.Y
			if primaryPart.Position.Y < lastWaterHeight - WaterConfig.FALL_DISTANCE then
				BoatServiceServer:WipeBoat(boat)
			end
		end
	end
end

function WaterServiceServer.Float(
	self: WaterServiceServer,
	primaryPart: BasePart,
	hit: RaycastResult,
	deltaTime: number
)
	local velocity = primaryPart.AssemblyLinearVelocity
	local depth = (hit.Position.Y + WaterConfig.FLOAT_HEIGHT) - primaryPart.Position.Y

	-- Spring the boat onto the surface, and cancel gravity while it floats.
	local verticalSpeed = velocity.Y
		+ (workspace.Gravity + depth * WaterConfig.FLOAT_STIFFNESS - velocity.Y * WaterConfig.FLOAT_DAMPING)
			* deltaTime

	-- Slow down toward the speed of the water's current.
	local drag = math.exp(-WaterConfig.WATER_DRAG * deltaTime)
	local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z) * drag + GetCurrent(hit.Instance) * (1 - drag)
	primaryPart.AssemblyLinearVelocity = Vector3.new(flatVelocity.X, verticalSpeed, flatVelocity.Z)

	local spin = primaryPart.AssemblyAngularVelocity
	local tiltDrag = math.exp(-WaterConfig.TILT_DRAG * deltaTime)
	local spinDrag = math.exp(-WaterConfig.SPIN_DRAG * deltaTime)
	primaryPart.AssemblyAngularVelocity = Vector3.new(spin.X * tiltDrag, spin.Y * spinDrag, spin.Z * tiltDrag)
end

return WaterServiceServer :: WaterServiceServer
