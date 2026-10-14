--!strict
-- ModuleScript: ServerScriptService.Services.ObstacleService.ObstacleServiceServer
--
-- Runs every obstacle on the river. At startup it:
--   1. swaps each marker in Workspace.Map.Obstacles for a copy of its template from
--      ReplicatedStorage.Assets.Obstacles (so one model can be placed many times, and
--      swapping a template's art updates every copy),
--   2. sets up every obstacle Model there by its Obstacle attribute (the Spinner,
--      Swinger, Slider and WindFan classes in ServerScriptService.Classes.Obstacles),
--   3. watches every part in Workspace.Map marked Hazard, popping any boat on the river
--      that touches one.
-- Every frame it moves the Swingers, Sliders and WindFans along their cycles, all timed
-- from the server clock. WaterService asks GetObstacleForces for the wind on each boat.
--
-- Map contract:
--   Workspace.Map.Obstacles (Folder, can have Folders inside to organize it)
--     <any name> (Model, attribute Obstacle = "Spinner" | "Swinger" | "Slider" | "WindFan")
--       Base, Moving, Wind   the parts each kind needs (see its class); the rest is scenery
--     <any name> (Part or Model marker, attribute ObstacleTemplate = a template's name)
--       Replaced at startup by a copy of ReplicatedStorage.Assets.Obstacles.<that name>,
--       with the template's pivot on the marker's pivot. Every other attribute on the
--       marker (like Speed or StartDelay) is copied onto the copy, so each copy can be tuned.
--   Any part anywhere in Workspace.Map with attribute Hazard = true pops boats that touch
--   it (spikes, blades). It doesn't need to be in an obstacle.

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Boat = require(ServerScriptService.Classes.Boat)
local BoatServiceServer = require(ServerScriptService.Services.BoatService.BoatServiceServer)
local BoatServiceShared = require(ReplicatedStorage.Shared.Services.BoatService.BoatServiceShared)
local Hull = require(ServerScriptService.Classes.Hull)
local ObstacleServiceShared = require(ReplicatedStorage.Shared.Services.ObstacleService.ObstacleServiceShared)
local Slider = require(ServerScriptService.Classes.Obstacles.Slider)
local Spinner = require(ServerScriptService.Classes.Obstacles.Spinner)
local Swinger = require(ServerScriptService.Classes.Obstacles.Swinger)
local WindFan = require(ServerScriptService.Classes.Obstacles.WindFan)

local ObstacleServiceServer = {}

type ObstacleServiceServerMembers = {
	Spinners: { Spinner.Spinner },
	Swingers: { Swinger.Swinger },
	Sliders: { Slider.Slider },
	WindFans: { WindFan.WindFan },
	Hazards: { [BasePart]: RBXScriptConnection }, -- every hazard part being watched
}

export type ObstacleServiceServer = typeof(ObstacleServiceServer) & ObstacleServiceServerMembers

function ObstacleServiceServer.Init(self: ObstacleServiceServer)
	self.Spinners = {}
	self.Swingers = {}
	self.Sliders = {}
	self.WindFans = {}
	self.Hazards = {}

	-- Obstacles hit boats, and pass through the map, riders and each other.
	local obstacleGroup = ObstacleServiceShared.COLLISION_GROUP
	if not PhysicsService:IsCollisionGroupRegistered(obstacleGroup) then
		PhysicsService:RegisterCollisionGroup(obstacleGroup)
	end
	for _, otherGroup in { "Default", obstacleGroup, BoatServiceShared.RIDER_COLLISION_GROUP } do
		PhysicsService:CollisionGroupSetCollidable(obstacleGroup, otherGroup, false)
	end
	PhysicsService:CollisionGroupSetCollidable(obstacleGroup, BoatServiceShared.COLLISION_GROUP, true)

	local map = workspace:FindFirstChild("Map")
	local obstaclesFolder = if map then map:FindFirstChild(ObstacleServiceShared.OBSTACLES_FOLDER_NAME) else nil
	if obstaclesFolder then
		self:PlaceTemplates(obstaclesFolder)
		self:SetUpObstacles(obstaclesFolder)
	end
	if map then
		for _, descendant in map:GetDescendants() do
			self:WatchIfHazard(descendant)
		end
		map.DescendantAdded:Connect(function(descendant)
			self:WatchIfHazard(descendant)
		end)
	end

	RunService.Heartbeat:Connect(function()
		self:Update()
	end)
end

-- Swaps every marker in `folder` for a copy of its template.
function ObstacleServiceServer.PlaceTemplates(self: ObstacleServiceServer, folder: Instance)
	local templatesFolder = ReplicatedStorage.Assets:FindFirstChild(ObstacleServiceShared.TEMPLATES_FOLDER_NAME)
	for _, marker in folder:GetDescendants() do
		local templateName = marker:GetAttribute(ObstacleServiceShared.TEMPLATE_ATTRIBUTE)
		if templateName == nil or not marker:IsA("PVInstance") then
			continue
		end
		local template = if templatesFolder and typeof(templateName) == "string"
			then templatesFolder:FindFirstChild(templateName)
			else nil
		if not template or not template:IsA("Model") then
			warn(
				`Obstacle marker {marker:GetFullName()} wants template "{templateName}", but ReplicatedStorage.Assets.{ObstacleServiceShared.TEMPLATES_FOLDER_NAME} has no Model by that name.`
			)
			continue
		end

		local copy = template:Clone()
		copy:PivotTo(marker:GetPivot())
		for name, value in marker:GetAttributes() do
			if name ~= ObstacleServiceShared.TEMPLATE_ATTRIBUTE then
				copy:SetAttribute(name, value)
			end
		end
		copy.Name = marker.Name
		copy.Parent = marker.Parent
		marker:Destroy()
	end
end

-- Sets up every obstacle Model in `folder` by its Obstacle attribute.
function ObstacleServiceServer.SetUpObstacles(self: ObstacleServiceServer, folder: Instance)
	local serverTime = workspace:GetServerTimeNow()
	for _, model in folder:GetDescendants() do
		local obstacleType = model:GetAttribute(ObstacleServiceShared.TYPE_ATTRIBUTE)
		if obstacleType == nil or not model:IsA("Model") then
			continue
		end
		if not ObstacleServiceShared.IsObstacleType(obstacleType) then
			warn(
				`Obstacle {model:GetFullName()} has {ObstacleServiceShared.TYPE_ATTRIBUTE} = "{obstacleType}", which isn't a kind of obstacle (Spinner, Swinger, Slider or WindFan).`
			)
			continue
		end

		local problem: string? = nil
		if obstacleType == "Spinner" then
			local spinner, spinnerProblem = Spinner.new(model)
			problem = spinnerProblem
			if spinner then
				table.insert(self.Spinners, spinner)
			end
		elseif obstacleType == "Swinger" then
			local swinger, swingerProblem = Swinger.new(model)
			problem = swingerProblem
			if swinger then
				table.insert(self.Swingers, swinger)
			end
		elseif obstacleType == "Slider" then
			local slider, sliderProblem = Slider.new(model)
			problem = sliderProblem
			if slider then
				table.insert(self.Sliders, slider)
			end
		else
			local windFan, windFanProblem = WindFan.new(model, serverTime)
			problem = windFanProblem
			if windFan then
				table.insert(self.WindFans, windFan)
			end
		end
		if problem then
			warn(`Obstacle {model:GetFullName()} ({obstacleType}) {problem}. It won't move.`)
		end
	end
end

-- Starts watching `instance` if it's a hazard part.
function ObstacleServiceServer.WatchIfHazard(self: ObstacleServiceServer, instance: Instance)
	if not instance:IsA("BasePart") or instance:GetAttribute(ObstacleServiceShared.HAZARD_ATTRIBUTE) ~= true then
		return
	end
	if self.Hazards[instance] then
		return
	end
	instance.CanTouch = true
	self.Hazards[instance] = instance.Touched:Connect(function(otherPart: BasePart)
		self:OnHazardTouched(otherPart)
	end)
	instance.Destroying:Connect(function()
		local connection = self.Hazards[instance]
		if connection then
			connection:Disconnect()
			self.Hazards[instance] = nil
		end
	end)
end

-- A hazard touched `otherPart`: if it's part of a boat on the river, the boat pops.
function ObstacleServiceServer.OnHazardTouched(self: ObstacleServiceServer, otherPart: BasePart)
	local boatModel = BoatServiceShared.GetBoatModelFromPart(otherPart)
	local boat = if boatModel then BoatServiceServer:GetBoatByModel(boatModel) else nil
	if boat and boat:IsFloating() then
		BoatServiceServer:WipeBoat(boat, "Popped")
	end
end

function ObstacleServiceServer.Update(self: ObstacleServiceServer)
	local serverTime = workspace:GetServerTimeNow()
	for _, swinger in self.Swingers do
		swinger:Update(serverTime)
	end
	for _, slider in self.Sliders do
		slider:Update(serverTime)
	end
	for _, windFan in self.WindFans do
		windFan:Update(serverTime)
	end
end

-- The pushes obstacles put on `boat` right now (the wind from every WindFan it's in),
-- through its center of mass.
function ObstacleServiceServer.GetObstacleForces(self: ObstacleServiceServer, boat: Boat.Boat): { Hull.AppliedForce }
	local forces: { Hull.AppliedForce } = {}
	local primaryPart = boat.Model.PrimaryPart
	if not primaryPart then
		return forces
	end
	local centerOfMass = primaryPart.AssemblyCenterOfMass
	for _, windFan in self.WindFans do
		local force = windFan:GetForceAt(centerOfMass)
		if force then
			table.insert(forces, { Position = centerOfMass, Force = force })
		end
	end
	return forces
end

return ObstacleServiceServer :: ObstacleServiceServer
