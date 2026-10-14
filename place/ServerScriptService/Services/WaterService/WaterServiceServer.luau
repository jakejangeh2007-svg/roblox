--!strict
-- ModuleScript: ServerScriptService.Services.WaterService.WaterServiceServer
--
-- Moves every boat on the river. Each frame, for each boat, it works out what the
-- water under the boat is doing (its surface with the waves, its current and how rough
-- it is), asks FartService for the pushes from the crew's farts and ObstacleService for
-- the wind from any fans, and steps the boat's Hull with all of it. Where there's no water under a boat, nothing holds it up and it falls. A
-- boat that falls FALL_DISTANCE below the last water it was over has fallen off the
-- river, and BoatService wipes it.
--
-- Map contract:
--   Workspace.Map.Water   Folder of parts whose TOP face is the water surface. Make them
--                         Anchored and CanCollide off. A part named after an entry in
--                         WaterConfig.WATER_TYPES (like Current or Rapids) flows toward its
--                         front face and acts like that type; any other part is calm water.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local BoatServiceServer = require(ServerScriptService.Services.BoatService.BoatServiceServer)
local FartServiceServer = require(ServerScriptService.Services.FartService.FartServiceServer)
local Hull = require(ServerScriptService.Classes.Hull)
local ObstacleServiceServer = require(ServerScriptService.Services.ObstacleService.ObstacleServiceServer)
local WaterConfig = require(ReplicatedStorage.Shared.Modules.Game.WaterConfig)

-- A wave from WaterConfig.WAVES, ready for the math.
type WaveShape = {
	Height: number,
	Wavenumber: number, -- radians per stud along its direction
	AngularFrequency: number, -- radians per second
	Direction: Vector2,
}

local WAVE_SHAPES: { WaveShape } = {}
for _, wave in WaterConfig.WAVES do
	if wave.Length > 0 and wave.Period > 0 and wave.Direction.Magnitude > 0 then
		table.insert(WAVE_SHAPES, {
			Height = wave.Height,
			Wavenumber = 2 * math.pi / wave.Length,
			AngularFrequency = 2 * math.pi / wave.Period,
			Direction = wave.Direction.Unit,
		})
	end
end

-- Turbulence reads three separate patterns out of one noise field, this far apart.
local NOISE_CHANNEL_SPACING = 61.7

local WaterServiceServer = {}

type WaterServiceServerMembers = {
	RaycastParameters: RaycastParams,
}

export type WaterServiceServer = typeof(WaterServiceServer) & WaterServiceServerMembers

-- The waves at `position` at `time`, scaled by `scale`: how far they lift the surface
-- there, and which way is straight up from it.
local function GetWaves(position: Vector3, time: number, scale: number): (number, Vector3)
	local height = 0
	local slopeX = 0
	local slopeZ = 0
	for _, wave in WAVE_SHAPES do
		local amplitude = wave.Height * scale
		local distance = wave.Direction.X * position.X + wave.Direction.Y * position.Z
		local phase = wave.Wavenumber * distance - wave.AngularFrequency * time
		height += amplitude * math.sin(phase)
		local slope = amplitude * wave.Wavenumber * math.cos(phase)
		slopeX += slope * wave.Direction.X
		slopeZ += slope * wave.Direction.Y
	end
	return height, Vector3.new(-slopeX, 1, -slopeZ).Unit
end

-- Smooth random shove (flat, each part roughly -1 to 1) and twist (roughly -1 to 1) at
-- `position` at `time`. They change gradually as the boat moves and time passes.
local function GetTurbulence(position: Vector3, time: number): (Vector3, number)
	local x = position.X / WaterConfig.TURBULENCE_SIZE
	local z = position.Z / WaterConfig.TURBULENCE_SIZE
	local t = time / WaterConfig.TURBULENCE_TIME
	-- math.noise mostly stays within -0.5 to 0.5, so doubling it gives about -1 to 1.
	local shoveX = math.noise(x, z, t) * 2
	local shoveZ = math.noise(x + NOISE_CHANNEL_SPACING, z, t) * 2
	local twist = math.noise(x, z + NOISE_CHANNEL_SPACING, t) * 2
	return Vector3.new(shoveX, 0, shoveZ), twist
end

-- Which way `waterPart` flows: toward its front face, flat on the water.
local function GetFlowDirection(waterPart: BasePart): Vector3
	local flatDirection = waterPart.CFrame.LookVector * Vector3.new(1, 0, 1)
	return if flatDirection.Magnitude > 0 then flatDirection.Unit else Vector3.zero
end

function WaterServiceServer.Init(self: WaterServiceServer)
	self.RaycastParameters = RaycastParams.new()
	self.RaycastParameters.FilterType = Enum.RaycastFilterType.Include

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

-- What the water under `position` is doing at `time`, or nil if there's no water under it.
function WaterServiceServer.GetWater(self: WaterServiceServer, position: Vector3, time: number): Hull.Water?
	local origin = position + Vector3.yAxis * WaterConfig.WATER_CHECK_ABOVE
	local reach = -Vector3.yAxis * (WaterConfig.WATER_CHECK_ABOVE + WaterConfig.WATER_CHECK_BELOW)
	local hit = workspace:Raycast(origin, reach, self.RaycastParameters)
	if not hit then
		return nil
	end

	local waterPart = hit.Instance
	local waterType = WaterConfig.WATER_TYPES[waterPart.Name] or WaterConfig.CALM_WATER
	local waveHeight, surfaceNormal = GetWaves(position, time, waterType.WaveScale)
	local turbulence = Vector3.zero
	local turnTurbulence = 0
	if waterType.Turbulence ~= 0 or waterType.TurnTurbulence ~= 0 then
		local shove, twist = GetTurbulence(position, time)
		turbulence = shove * waterType.Turbulence
		turnTurbulence = twist * waterType.TurnTurbulence
	end
	return {
		SurfaceHeight = hit.Position.Y + waveHeight,
		SurfaceNormal = surfaceNormal,
		FlowVelocity = GetFlowDirection(waterPart) * waterType.Speed,
		Turbulence = turbulence,
		TurnTurbulence = turnTurbulence,
	}
end

function WaterServiceServer.Update(self: WaterServiceServer, deltaTime: number)
	local stepTime = math.min(deltaTime, WaterConfig.MAX_STEP_TIME)
	local now = os.clock()
	for _, boat in BoatServiceServer:GetLaunchedBoats() do
		local hull = boat.Hull
		if not hull or not boat:IsFloating() then
			continue
		end

		local position = hull.PrimaryPart.Position
		local water = self:GetWater(position, now)
		if not water and position.Y < hull.LastWaterHeight - WaterConfig.FALL_DISTANCE then
			BoatServiceServer:WipeBoat(boat, "Fell")
			continue
		end
		local forces = FartServiceServer:GetFartForces(boat)
		for _, obstacleForce in ObstacleServiceServer:GetObstacleForces(boat) do
			table.insert(forces, obstacleForce)
		end
		hull:Step(water, forces, stepTime)
	end
end

return WaterServiceServer :: WaterServiceServer
