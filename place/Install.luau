--[[
	INSTALL: paste this into Roblox Studio's Command Bar to install or update the game's code.

	1. Open your place in Studio. Close any open script tabs.
	2. View tab -> Command Bar.
	3. Paste this whole script into the Command Bar and press Enter.
	4. Check the Output window: it lists what was created and updated.

	It creates any missing folders, creates any missing scripts, and replaces the code
	in existing scripts with the versions below. It never deletes anything, and it
	never touches models or parts. Running it again is safe. Ctrl+Z undoes it.

	Generated from the .luau files in the repo's place/ folder.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local FOLDERS: { { string } } = {
	{ "ReplicatedStorage", "Shared", "Classes" },
	{ "ReplicatedStorage", "Shared", "Modules", "Platform" },
	{ "ReplicatedStorage", "Assets", "Boats" },
	{ "ReplicatedStorage", "Assets", "VFX" },
	{ "ReplicatedStorage", "Assets", "Sounds", "Farts" },
	{ "ReplicatedStorage", "UI", "HUD" },
	{ "ReplicatedStorage", "UI", "Menus" },
	{ "ServerScriptService", "Services" },
	{ "ServerScriptService", "Classes" },
	{ "Workspace", "Map", "Lobby", "Docks" },
	{ "Workspace", "Map", "Checkpoints" },
	{ "Workspace", "Map", "Water" },
	{ "Workspace", "Boats" },
}

local SCRIPTS: { { ParentPath: { string }, Name: string, ClassName: string, Source: string } } = {
	{
		ParentPath = { "ReplicatedStorage" },
		Name = "UI",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ReplicatedStorage.UI
--
-- Top-level UI initializer. The Client startup script calls UI.Init after every
-- client service has started. UI.Init requires each feature module inside the
-- interface folders under this module (HUD, Menus, ...) and calls its Init if it
-- has one.
--
-- All UI is built by hand in Studio. Feature modules only wire up what's already there.

local UI = {}

-- Member variables go here.
type UIMembers = {}

export type UI = typeof(UI) & UIMembers

local function SortedChildren(parent: Instance): { Instance }
	local children = parent:GetChildren()
	table.sort(children, function(first, second)
		return first.Name < second.Name
	end)
	return children
end

local function StartFeature(featureModule: ModuleScript)
	local feature = require(featureModule) :: any
	if type(feature) == "table" and type(feature.Init) == "function" then
		feature.Init(feature)
	end
end

function UI.Init(self: UI)
	for _, interfaceFolder in SortedChildren(script) do
		for _, featureModule in SortedChildren(interfaceFolder) do
			if featureModule:IsA("ModuleScript") then
				StartFeature(featureModule)
			end
		end
	end
end

return UI :: UI
]==],
	},
	{
		ParentPath = { "ServerScriptService" },
		Name = "Server",
		ClassName = "Script",
		Source = [==[
--!strict
-- Script: ServerScriptService.Server
--
-- Server startup. Requires the server half of every service and calls its Init.
-- A service is a folder in ServerScriptService.Services named <X>Service, and its
-- server half is the ModuleScript <X>ServiceServer inside that folder. Services
-- with no server half are skipped.
--
-- Services start in alphabetical order. To start one before the rest, add its
-- folder name to START_FIRST. If its Init takes parameters, add its folder name
-- to START_MANUALLY and call its Init by hand at the bottom of this script.

local ServerScriptService = game:GetService("ServerScriptService")

-- BoatService before CheckpointService (which listens to its CrewMemberLeft signal),
-- and CheckpointService before DockService (which reads its docks from the map).
local START_FIRST: { string } = { "BoatService", "CheckpointService" }
local START_MANUALLY: { string } = {}

local servicesFolder = ServerScriptService.Services

local function StartService(serviceFolder: Instance)
	local serverModule = serviceFolder:FindFirstChild(serviceFolder.Name .. "Server")
	if not serverModule or not serverModule:IsA("ModuleScript") then
		return
	end
	local service = require(serverModule) :: any
	if type(service) == "table" and type(service.Init) == "function" then
		service.Init(service)
	end
end

local function StartServices()
	for _, serviceName in START_FIRST do
		local serviceFolder = servicesFolder:FindFirstChild(serviceName)
		assert(
			serviceFolder,
			`START_FIRST has "{serviceName}", but ServerScriptService.Services has no folder by that name`
		)
		StartService(serviceFolder)
	end

	local serviceFolders = servicesFolder:GetChildren()
	table.sort(serviceFolders, function(first, second)
		return first.Name < second.Name
	end)
	for _, serviceFolder in serviceFolders do
		local serviceName = serviceFolder.Name
		if not table.find(START_FIRST, serviceName) and not table.find(START_MANUALLY, serviceName) then
			StartService(serviceFolder)
		end
	end
end

-- TEST ONLY: if a TestKit ModuleScript is here, it builds a grey-box test world before
-- the services start. Deleting the TestKit module turns this off.
local testKit = ServerScriptService:FindFirstChild("TestKit")
if testKit and testKit:IsA("ModuleScript") then
	local TestKit = require(testKit) :: any
	TestKit.Build()
end

StartServices()

-- Services listed in START_MANUALLY start here, in order. For example:
-- local ExampleServiceServer = require(servicesFolder.ExampleService.ExampleServiceServer)
-- ExampleServiceServer.Init(ExampleServiceServer, someParameter)
]==],
	},
	{
		ParentPath = { "ReplicatedStorage", "Packages" },
		Name = "Signal",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ReplicatedStorage.Packages.Signal
--
-- A small event object for plain Luau code. Unlike a BindableEvent, it passes
-- tables through as-is (BindableEvents copy them).
--
--   local changed = Signal.new()
--   local connection = changed:Connect(function(value) print(value) end)
--   changed:Fire(5)
--   connection:Disconnect()

local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

type SignalMembers = {
	Connections: { Connection },
}

type ConnectionMembers = {
	Connected: boolean,
	Signal: Signal,
	Callback: (...any) -> (),
}

export type Signal = typeof(setmetatable({} :: SignalMembers, Signal))
export type Connection = typeof(setmetatable({} :: ConnectionMembers, Connection))

function Signal.new(): Signal
	return setmetatable({ Connections = {} } :: SignalMembers, Signal)
end

function Signal.Connect(self: Signal, callback: (...any) -> ()): Connection
	local connection = setmetatable(
		{
			Connected = true,
			Signal = self,
			Callback = callback,
		} :: ConnectionMembers,
		Connection
	)
	table.insert(self.Connections, connection)
	return connection
end

-- Calls every connected callback, each in its own thread.
function Signal.Fire(self: Signal, ...: any)
	for _, connection in table.clone(self.Connections) do
		if connection.Connected then
			task.spawn(connection.Callback, ...)
		end
	end
end

function Connection.Disconnect(self: Connection)
	if not self.Connected then
		return
	end
	self.Connected = false
	local index = table.find(self.Signal.Connections, self)
	if index then
		table.remove(self.Signal.Connections, index)
	end
end

return Signal
]==],
	},
	{
		ParentPath = { "ReplicatedStorage", "Packages" },
		Name = "TableUtil",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ReplicatedStorage.Packages.TableUtil
--
-- Small table helpers.

local TableUtil = {}

-- A full copy of a value. Tables inside it are copied too.
function TableUtil.DeepCopy<T>(original: T): T
	if type(original) ~= "table" then
		return original
	end
	local copy = {}
	for key, value in original :: any do
		copy[TableUtil.DeepCopy(key)] = TableUtil.DeepCopy(value)
	end
	return copy :: any
end

-- Gives `target` a copy of every key from `template` that it's missing, so older
-- saved data picks up fields added later. Keys `target` already has stay as they are.
function TableUtil.Reconcile(target: { [any]: any }, template: { [any]: any })
	for key, value in template do
		local current = target[key]
		if current == nil then
			target[key] = TableUtil.DeepCopy(value)
		elseif type(current) == "table" and type(value) == "table" then
			TableUtil.Reconcile(current, value)
		end
	end
end

return TableUtil
]==],
	},
	{
		ParentPath = { "ServerScriptService", "Classes" },
		Name = "Boat",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ServerScriptService.Classes.Boat
--
-- A boat cloned from a template in ReplicatedStorage.Assets.Boats. The player who
-- spawns it is its party leader. It waits at its dock while players get in, then moves
-- into the river and floats. It leaves at the earliest of:
--   - the join timer running out (JOIN_TIME after it spawned), with whoever is aboard
--   - LAUNCH_DELAY after every seat is taken (cancelled if someone gets up)
--   - LAUNCH_DELAY after the leader starts the run early
-- If nobody is aboard when it's time to leave, it's removed instead.
-- On the river it moves under physics that the server runs: its Hull (the Hull class)
-- is stepped by WaterService every frame. While it's out there its riders don't bump
-- into anything and weigh nothing, so only the hull touches the world and every boat of
-- a size handles the same however its crew is spread around it.
--
-- Template contract (a Model built by hand, with no scripts inside):
--   PrimaryPart   must be set: a flat part in the middle of the boat, at the height the
--                 water should come up to, with its top face pointing up. It can be invisible.
--   Welds         every other part, Seats included, welded to the PrimaryPart with
--                 WeldConstraints (directly or through other welded parts).
--   Physics       every part gets BoatConfig's slippery, slightly bouncy HULL_ settings,
--                 keeping its own density.
--   Seats         one Seat per player. The number of Seats must match the size the
--                 template is listed under in BoatConfig.TEMPLATE_NAMES. Put them around
--                 the edge facing the middle. A one-seat boat can have its seat in the
--                 middle, facing forward.
--
-- States: Docked -> Launched -> Destroyed. The model's State, LeaderUserId and
-- DepartureTime attributes (see BoatServiceShared) mirror this for clients.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BoatConfig = require(ReplicatedStorage.Shared.Modules.Game.BoatConfig)
local BoatServiceShared = require(ReplicatedStorage.Shared.Services.BoatService.BoatServiceShared)
local Hull = require(ServerScriptService.Classes.Hull)
local Signal = require(ReplicatedStorage.Packages.Signal)

local Boat = {}
Boat.__index = Boat

-- What a rider's body part was like before they launched, to put back when they leave.
type RiderPartSettings = {
	CollisionGroup: string,
	Massless: boolean,
}

type BoatMembers = {
	Model: Model,
	Leader: Player, -- the party leader: who spawned it, or who took over after they left
	Seats: { Seat },
	State: BoatServiceShared.BoatState,
	Frozen: boolean, -- held still in mid-air after falling off the river, until it's removed
	Crew: { Player }, -- who was aboard at launch, minus anyone who has left since
	Hull: Hull.Hull?, -- how it moves on the river; made when it launches
	RiderParts: { [Player]: { [BasePart]: RiderPartSettings } }, -- each rider's body parts, changed for the ride
	LaunchCFrame: CFrame,
	LastCheckpointIndex: number, -- the location it launched from, then each checkpoint it reaches
	JoinDeadline: number, -- server time the join timer runs out
	FullDeadline: number?, -- server time it leaves because every seat is taken (nil while any seat is free)
	StartDeadline: number?, -- server time it leaves because the leader started the run early
	Connections: { RBXScriptConnection },
	CrewMemberLeft: Signal.Signal, -- fires (player: Player) when a crew member leaves after launch, for any reason
}

export type Boat = typeof(setmetatable({} :: BoatMembers, Boat))

local function GetSeats(model: Instance): { Seat }
	local seats = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Seat") then
			table.insert(seats, descendant)
		end
	end
	return seats
end

local function EjectFromSeat(seat: Seat)
	local seatWeld = seat:FindFirstChild("SeatWeld")
	if seatWeld then
		seatWeld:Destroy()
	end
end

local function GetPlayerInSeat(seat: Seat): Player?
	local humanoid = seat.Occupant
	return if humanoid then Players:GetPlayerFromCharacter(humanoid.Parent) else nil
end

-- The first part in `template` that isn't welded to its PrimaryPart, directly or
-- through other welded parts. Nil if every part is.
local function FindUnweldedPart(template: Model, primaryPart: BasePart): BasePart?
	local neighbors: { [BasePart]: { BasePart } } = {}
	local function Link(first: BasePart, second: BasePart)
		local list = neighbors[first] or {}
		neighbors[first] = list
		table.insert(list, second)
	end
	for _, descendant in template:GetDescendants() do
		local part0: BasePart?, part1: BasePart? = nil, nil
		if descendant:IsA("WeldConstraint") or descendant:IsA("JointInstance") then
			part0, part1 = descendant.Part0, descendant.Part1
		end
		if part0 and part1 then
			Link(part0, part1)
			Link(part1, part0)
		end
	end

	local reached: { [BasePart]: boolean } = { [primaryPart] = true }
	local toVisit = { primaryPart }
	while #toVisit > 0 do
		local part = table.remove(toVisit) :: BasePart
		local partNeighbors: { BasePart } = neighbors[part] or {}
		for _, neighbor in partNeighbors do
			if not reached[neighbor] then
				reached[neighbor] = true
				table.insert(toVisit, neighbor)
			end
		end
	end

	for _, descendant in template:GetDescendants() do
		if descendant:IsA("BasePart") and not reached[descendant] then
			return descendant
		end
	end
	return nil
end

-- Checks a template follows the contract above. Returns a problem description if not.
function Boat.CheckTemplate(template: Instance?, seatCount: number): string?
	if not template or not template:IsA("Model") then
		return "is missing (it should be a Model)"
	end
	local primaryPart = template.PrimaryPart
	if not primaryPart then
		return "has no PrimaryPart set"
	end
	local foundSeats = #GetSeats(template)
	if foundSeats ~= seatCount then
		return `has {foundSeats} Seats but should have {seatCount}`
	end
	local unweldedPart = FindUnweldedPart(template, primaryPart)
	if unweldedPart then
		return `has a part named {unweldedPart.Name} that isn't welded to the PrimaryPart`
	end
	return nil
end

-- Clones `template` to `dockCFrame` and puts it in `parent`. The template must have
-- passed CheckTemplate.
function Boat.new(
	template: Model,
	leader: Player,
	dockCFrame: CFrame,
	launchCFrame: CFrame,
	startIndex: number,
	parent: Instance
): Boat
	local model = template:Clone()
	local self = setmetatable(
		{
			Model = model,
			Leader = leader,
			Seats = GetSeats(model),
			State = "Docked",
			Frozen = false,
			Crew = {},
			Hull = nil,
			RiderParts = {},
			LaunchCFrame = launchCFrame,
			LastCheckpointIndex = startIndex,
			JoinDeadline = workspace:GetServerTimeNow() + BoatConfig.JOIN_TIME,
			FullDeadline = nil,
			StartDeadline = nil,
			Connections = {},
			CrewMemberLeft = Signal.new(),
		} :: BoatMembers,
		Boat
	)

	-- Only the PrimaryPart is anchored, so the whole boat is held in place by it now and
	-- floats freely once it's unanchored at launch.
	local primaryPart = model.PrimaryPart
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = descendant == primaryPart
			descendant.CollisionGroup = BoatServiceShared.COLLISION_GROUP
			descendant.CustomPhysicalProperties = PhysicalProperties.new(
				descendant.CurrentPhysicalProperties.Density,
				BoatConfig.HULL_FRICTION,
				BoatConfig.HULL_ELASTICITY,
				BoatConfig.HULL_FRICTION_WEIGHT,
				BoatConfig.HULL_ELASTICITY_WEIGHT
			)
		end
	end
	self:MoveTo(dockCFrame)

	for _, seat in self.Seats do
		table.insert(
			self.Connections,
			seat:GetPropertyChangedSignal("Occupant"):Connect(function()
				self:OnSeatChanged(seat)
			end)
		)
	end

	model:SetAttribute(BoatServiceShared.STATE_ATTRIBUTE, self.State)
	self:SetLeader(leader)
	self:UpdateDepartureTime()
	model.Parent = parent
	return self
end

-- Moves the whole boat so its pivot lands on `target`. Seated players are welded
-- to their seats, so they come along.
function Boat.MoveTo(self: Boat, target: CFrame)
	self.Model:PivotTo(target)
end

function Boat.GetPosition(self: Boat): Vector3
	return self.Model:GetPivot().Position
end

-- True while the boat is still waiting at its dock.
function Boat.IsAtDock(self: Boat): boolean
	return self.State == "Docked"
end

-- True while the boat is on the river and moving under physics.
function Boat.IsFloating(self: Boat): boolean
	return self.State == "Launched" and not self.Frozen
end

function Boat.GetSeatedPlayers(self: Boat): { Player }
	local seatedPlayers = {}
	for _, seat in self.Seats do
		local player = GetPlayerInSeat(seat)
		if player then
			table.insert(seatedPlayers, player)
		end
	end
	return seatedPlayers
end

-- The seat `player` is sitting in on this boat, if any.
function Boat.GetSeatOf(self: Boat, player: Player): Seat?
	for _, seat in self.Seats do
		if GetPlayerInSeat(seat) == player then
			return seat
		end
	end
	return nil
end

-- Takes `player` out of their seat in this boat, if they're in one.
function Boat.Eject(self: Boat, player: Player)
	local seat = self:GetSeatOf(player)
	if seat then
		EjectFromSeat(seat)
	end
end

function Boat.SetState(self: Boat, state: BoatServiceShared.BoatState)
	self.State = state
	self.Model:SetAttribute(BoatServiceShared.STATE_ATTRIBUTE, state)
end

function Boat.OnSeatChanged(self: Boat, seat: Seat)
	if self.State == "Destroyed" then
		return
	end
	local isLaunched = self.State == "Launched"
	local humanoid = seat.Occupant
	if humanoid and (isLaunched or not GetPlayerInSeat(seat)) then
		-- Only players ride, and nobody climbs aboard after launch.
		EjectFromSeat(seat)
		return
	end

	if isLaunched then
		self:RemoveMissingCrew()
		return
	end

	local isFull = #self:GetSeatedPlayers() == #self.Seats
	if isFull and not self.FullDeadline then
		self.FullDeadline = workspace:GetServerTimeNow() + BoatConfig.LAUNCH_DELAY
	elseif not isFull then
		self.FullDeadline = nil
	end
	self:UpdateDepartureTime()
end

function Boat.SetLeader(self: Boat, player: Player)
	self.Leader = player
	self.Model:SetAttribute(BoatServiceShared.LEADER_ATTRIBUTE, player.UserId)
end

-- The server time this docked boat leaves: the earliest of its deadlines.
function Boat.GetDepartureTime(self: Boat): number
	local departureTime = self.JoinDeadline
	local fullDeadline = self.FullDeadline
	if fullDeadline then
		departureTime = math.min(departureTime, fullDeadline)
	end
	local startDeadline = self.StartDeadline
	if startDeadline then
		departureTime = math.min(departureTime, startDeadline)
	end
	return departureTime
end

function Boat.UpdateDepartureTime(self: Boat)
	self.Model:SetAttribute(BoatServiceShared.DEPARTURE_TIME_ATTRIBUTE, self:GetDepartureTime())
end

-- The leader started the run early: leave after LAUNCH_DELAY, whoever is aboard.
function Boat.StartEarly(self: Boat)
	if self.State ~= "Docked" or self.StartDeadline then
		return
	end
	self.StartDeadline = workspace:GetServerTimeNow() + BoatConfig.LAUNCH_DELAY
	self:UpdateDepartureTime()
end

function Boat.HasFreeSeat(self: Boat): boolean
	for _, seat in self.Seats do
		if not seat.Occupant then
			return true
		end
	end
	return false
end

-- Sits `player` in a free seat of this docked boat. They must not be sitting anywhere
-- else. Returns false if there's no free seat or they can't sit right now.
function Boat.SeatPlayer(self: Boat, player: Player): boolean
	if self.State ~= "Docked" then
		return false
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoid.Health <= 0 or humanoid.SeatPart then
		return false
	end
	for _, seat in self.Seats do
		if not seat.Occupant then
			seat:Sit(humanoid)
			return true
		end
	end
	return false
end

-- Called once the departure time arrives: into the river with whoever is aboard, or
-- removed if nobody is.
function Boat.Depart(self: Boat)
	if self.State ~= "Docked" then
		return
	end
	if #self:GetSeatedPlayers() == 0 then
		self:Destroy()
	else
		self:Launch()
	end
end

function Boat.Launch(self: Boat)
	self.Crew = self:GetSeatedPlayers()
	self:SetState("Launched")
	self.Model:SetAttribute(BoatServiceShared.DEPARTURE_TIME_ATTRIBUTE, nil)
	self:MoveTo(self.LaunchCFrame)
	for _, player in self.Crew do
		self:PrepareRider(player)
	end
	local primaryPart = self.Model.PrimaryPart
	if primaryPart then
		self.Hull = Hull.new(primaryPart, #self.Seats)
	end
end

-- For the ride, `player`'s body doesn't bump into anything (only the hull does) and
-- weighs nothing, so the boat turns around its own middle wherever they sit.
function Boat.PrepareRider(self: Boat, player: Player)
	local character = player.Character
	if not character or self.RiderParts[player] then
		return
	end
	local riderParts: { [BasePart]: RiderPartSettings } = {}
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			riderParts[descendant] = { CollisionGroup = descendant.CollisionGroup, Massless = descendant.Massless }
			descendant.CollisionGroup = BoatServiceShared.RIDER_COLLISION_GROUP
			descendant.Massless = true
		end
	end
	self.RiderParts[player] = riderParts
end

-- Puts back what PrepareRider changed on `player`'s body, if it's still around.
function Boat.ReleaseRider(self: Boat, player: Player)
	local riderParts = self.RiderParts[player]
	if not riderParts then
		return
	end
	self.RiderParts[player] = nil
	for part, settings in riderParts do
		if part.Parent then
			part.CollisionGroup = settings.CollisionGroup
			part.Massless = settings.Massless
		end
	end
end

-- Holds the boat still in mid-air (after falling off the river) until it's removed.
function Boat.Freeze(self: Boat)
	self.Frozen = true
	local primaryPart = self.Model.PrimaryPart
	if primaryPart then
		primaryPart.Anchored = true
	end
end

-- After launch: anyone in the crew who is no longer seated has left the boat.
function Boat.RemoveMissingCrew(self: Boat)
	local seatedPlayers = self:GetSeatedPlayers()
	for index = #self.Crew, 1, -1 do
		local player = self.Crew[index]
		if not table.find(seatedPlayers, player) then
			table.remove(self.Crew, index)
			self:ReleaseRider(player)
			self.CrewMemberLeft:Fire(player)
		end
	end
	if #self.Crew == 0 then
		self:Destroy()
	end
end

function Boat.Destroy(self: Boat)
	if self.State == "Destroyed" then
		return
	end
	local wasLaunched = self.State == "Launched"
	self:SetState("Destroyed")
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	for _, seat in self.Seats do
		EjectFromSeat(seat)
	end
	for player in self.RiderParts do
		self:ReleaseRider(player)
	end
	if wasLaunched then
		for _, player in self.Crew do
			self.CrewMemberLeft:Fire(player)
		end
	end
	self.Crew = {}
	self.Model:Destroy()
end

return Boat
]==],
	},
	{
		ParentPath = { "ServerScriptService", "Classes" },
		Name = "Dock",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ServerScriptService.Classes.Dock
--
-- One dock that players spawn boats from. It belongs to a Location (the lobby or a checkpoint).
--
-- Map contract (a Model inside a location's Docks folder):
--   BoatSpawn         BasePart          where a spawned boat waits while players get in.
--                                       The boat takes this part's position and rotation.
--   SpawnBoatPrompt   ProximityPrompt   anywhere inside the dock model; players use it to
--                                       open the boat menu

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Boat = require(ServerScriptService.Classes.Boat)
local DockServiceShared = require(ReplicatedStorage.Shared.Services.DockService.DockServiceShared)
local Location = require(ServerScriptService.Classes.Location)

local Dock = {}
Dock.__index = Dock

type DockMembers = {
	Model: Model,
	Location: Location.Location,
	BoatSpawn: BasePart?,
	Boat: Boat.Boat?, -- the boat that most recently spawned here
}

export type Dock = typeof(setmetatable({} :: DockMembers, Dock))

function Dock.new(model: Model, location: Location.Location): Dock
	local path = model:GetFullName()
	local boatSpawn = model:FindFirstChild("BoatSpawn")
	if not boatSpawn or not boatSpawn:IsA("BasePart") then
		warn(`Map piece missing: {path}.BoatSpawn (a Part)`)
		boatSpawn = nil
	end
	local prompt = model:FindFirstChild(DockServiceShared.SPAWN_BOAT_PROMPT_NAME, true)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		warn(`Map piece missing: a ProximityPrompt named {DockServiceShared.SPAWN_BOAT_PROMPT_NAME} inside {path}`)
	end

	return setmetatable(
		{
			Model = model,
			Location = location,
			BoatSpawn = boatSpawn,
			Boat = nil,
		} :: DockMembers,
		Dock
	)
end

-- A dock is free when no boat is waiting at it.
function Dock.IsFree(self: Dock): boolean
	local boat = self.Boat
	return boat == nil or not boat:IsAtDock()
end

return Dock
]==],
	},
	{
		ParentPath = { "ServerScriptService", "Classes" },
		Name = "Hull",
		ClassName = "ModuleScript",
		Source = [==[
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
]==],
	},
	{
		ParentPath = { "ServerScriptService", "Classes" },
		Name = "Location",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ServerScriptService.Classes.Location
--
-- A place players can be: the lobby, or one of the checkpoints. It reads its
-- pieces from the map. Pieces that aren't built yet are nil, and a warning in
-- Output says what's missing.
--
-- Map contract (a Folder or Model: Workspace.Map.Lobby, or Workspace.Map.Checkpoints.<Id>):
--   Spawn   BasePart   where players appear when they teleport here or respawn
--   Launch  BasePart   where boats from these docks appear in the river (they take its position and rotation)
--   Docks   Folder     one Model per dock (see the Dock class)
--   Zone    BasePart   checkpoints only: a launched boat whose middle is inside it has reached the checkpoint

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CheckpointConfig = require(ReplicatedStorage.Shared.Modules.Game.CheckpointConfig)
local DockServiceShared = require(ReplicatedStorage.Shared.Services.DockService.DockServiceShared)
local Geometry = require(ReplicatedStorage.Shared.Modules.Math.Geometry)

local Location = {}
Location.__index = Location

type LocationMembers = {
	Id: string,
	DisplayName: string,
	Index: number, -- 0 for the lobby, then 1, 2, 3... in the order the river reaches them
	Spawn: BasePart?,
	Launch: BasePart?,
	Zone: BasePart?,
	DockModels: { Model },
}

export type Location = typeof(setmetatable({} :: LocationMembers, Location))

local function FindPart(folder: Instance, name: string, path: string): BasePart?
	local part = folder:FindFirstChild(name)
	if part and part:IsA("BasePart") then
		return part
	end
	warn(`Map piece missing: {path}.{name} (a Part)`)
	return nil
end

local function FindDockModels(folder: Instance, path: string): { Model }
	local dockModels = {}
	local docksFolder = folder:FindFirstChild(DockServiceShared.DOCKS_FOLDER_NAME)
	if not docksFolder then
		warn(`Map piece missing: {path}.{DockServiceShared.DOCKS_FOLDER_NAME} (a Folder of dock Models)`)
		return dockModels
	end
	for _, child in docksFolder:GetChildren() do
		if child:IsA("Model") then
			table.insert(dockModels, child)
		end
	end
	return dockModels
end

-- `folder` is the location's folder in the map, or nil if it hasn't been built yet.
-- `path` is where it should be, for warning messages.
function Location.new(id: string, displayName: string, index: number, folder: Instance?, path: string): Location
	local spawnPart, launchPart, zonePart = nil, nil, nil
	local dockModels = {}
	if folder then
		spawnPart = FindPart(folder, "Spawn", path)
		launchPart = FindPart(folder, "Launch", path)
		zonePart = if index > 0 then FindPart(folder, "Zone", path) else nil
		dockModels = FindDockModels(folder, path)
	else
		warn(`Map piece missing: {path} (a Folder)`)
	end

	return setmetatable(
		{
			Id = id,
			DisplayName = displayName,
			Index = index,
			Spawn = spawnPart,
			Launch = launchPart,
			Zone = zonePart,
			DockModels = dockModels,
		} :: LocationMembers,
		Location
	)
end

-- Where a player should stand when they arrive here, or nil if Spawn isn't built.
function Location.GetSpawnCFrame(self: Location): CFrame?
	local spawnPart = self.Spawn
	if not spawnPart then
		return nil
	end
	return spawnPart.CFrame + Vector3.new(0, CheckpointConfig.SPAWN_HEIGHT, 0)
end

-- Whether a point is inside this checkpoint's Zone. Always false for the lobby.
function Location.IsInZone(self: Location, point: Vector3): boolean
	local zonePart = self.Zone
	return zonePart ~= nil and Geometry.IsPointInPart(point, zonePart)
end

return Location
]==],
	},
	{
		ParentPath = { "StarterPlayer", "StarterPlayerScripts" },
		Name = "Client",
		ClassName = "LocalScript",
		Source = [==[
--!strict
-- LocalScript: StarterPlayer.StarterPlayerScripts.Client
--
-- Client startup. Waits for the game to finish loading, requires the client half
-- of every service and calls its Init, then starts the UI. A service is a folder in
-- ReplicatedStorage.Shared.Services named <X>Service, and its client half is the
-- ModuleScript <X>ServiceClient inside that folder. Services with no client half
-- are skipped.
--
-- Services start in alphabetical order. To start one before the rest, add its
-- folder name to START_FIRST. If its Init takes parameters, add its folder name
-- to START_MANUALLY and call its Init by hand near the bottom of this script.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local START_FIRST: { string } = {}
local START_MANUALLY: { string } = {}

local servicesFolder = ReplicatedStorage.Shared.Services

local function StartService(serviceFolder: Instance)
	local clientModule = serviceFolder:FindFirstChild(serviceFolder.Name .. "Client")
	if not clientModule or not clientModule:IsA("ModuleScript") then
		return
	end
	local service = require(clientModule) :: any
	if type(service) == "table" and type(service.Init) == "function" then
		service.Init(service)
	end
end

local function StartServices()
	for _, serviceName in START_FIRST do
		local serviceFolder = servicesFolder:FindFirstChild(serviceName)
		assert(
			serviceFolder,
			`START_FIRST has "{serviceName}", but ReplicatedStorage.Shared.Services has no folder by that name`
		)
		StartService(serviceFolder)
	end

	local serviceFolders = servicesFolder:GetChildren()
	table.sort(serviceFolders, function(first, second)
		return first.Name < second.Name
	end)
	for _, serviceFolder in serviceFolders do
		local serviceName = serviceFolder.Name
		if not table.find(START_FIRST, serviceName) and not table.find(START_MANUALLY, serviceName) then
			StartService(serviceFolder)
		end
	end
end

StartServices()

-- Services listed in START_MANUALLY start here, in order. For example:
-- local ExampleServiceClient = require(servicesFolder.ExampleService.ExampleServiceClient)
-- ExampleServiceClient.Init(ExampleServiceClient, someParameter)

-- The UI starts last, once every client service is ready.
local UI = require(ReplicatedStorage.UI)
UI.Init(UI)
]==],
	},
	{
		ParentPath = { "ReplicatedStorage", "UI", "HUD" },
		Name = "GasMeter",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ReplicatedStorage.UI.HUD.GasMeter
--
-- Fills the gas meter from the local player's Gas attribute (see FartService). The
-- fill glides to each new value instead of jumping. It only changes the fill's width;
-- the meter itself is built by hand in Studio.
--
-- UI contract (built by hand in StarterGui, sized with Scale only):
--   HUD        ScreenGui
--     GasMeter   Frame   the meter's background
--       Fill       Frame   the part that shrinks as gas runs out. Its width (Size X Scale)
--                          is set to the gas left: 1 when full, 0 when empty.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FartConfig = require(ReplicatedStorage.Shared.Modules.Game.FartConfig)
local FartServiceShared = require(ReplicatedStorage.Shared.Services.FartService.FartServiceShared)

local GasMeter = {
	HUD_NAME = "HUD",
	GAS_METER_NAME = "GasMeter",
	FILL_NAME = "Fill",
	FILL_SMOOTHING = 12, -- how quickly the fill catches up to the gas left (higher = snappier)
}

type GasMeterMembers = {
	ShownFraction: number?, -- how full the meter is showing right now
}

export type GasMeter = typeof(GasMeter) & GasMeterMembers

-- The Fill frame in the local player's HUD, if it's there.
local function FindFill(): GuiObject?
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local hud = if playerGui then playerGui:FindFirstChild(GasMeter.HUD_NAME) else nil
	local gasMeter = if hud then hud:FindFirstChild(GasMeter.GAS_METER_NAME) else nil
	local fill = if gasMeter then gasMeter:FindFirstChild(GasMeter.FILL_NAME) else nil
	return if fill and fill:IsA("GuiObject") then fill else nil
end

local function GetGasFraction(): number
	local gas = Players.LocalPlayer:GetAttribute(FartServiceShared.GAS_ATTRIBUTE)
	return if typeof(gas) == "number" then math.clamp(gas / FartConfig.GAS_MAX, 0, 1) else 0
end

function GasMeter.Init(self: GasMeter)
	self.ShownFraction = nil
	RunService.RenderStepped:Connect(function(deltaTime)
		self:Update(deltaTime)
	end)
end

function GasMeter.Update(self: GasMeter, deltaTime: number)
	local fill = FindFill()
	if not fill then
		self.ShownFraction = nil
		return
	end
	local targetFraction = GetGasFraction()
	local shownFraction = self.ShownFraction or targetFraction
	shownFraction += (targetFraction - shownFraction) * (1 - math.exp(-GasMeter.FILL_SMOOTHING * deltaTime))
	if math.abs(targetFraction - shownFraction) < 0.001 then
		shownFraction = targetFraction
	end
	self.ShownFraction = shownFraction
	if fill.Size.X.Scale ~= shownFraction then
		fill.Size = UDim2.fromScale(shownFraction, fill.Size.Y.Scale)
	end
end

return GasMeter :: GasMeter
]==],
	},
	{
		ParentPath = { "ServerScriptService", "Services", "BoatService" },
		Name = "BoatServiceServer",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ServerScriptService.Services.BoatService.BoatServiceServer
--
-- Owns every boat: spawning them from templates, filling them with players,
-- launching them into the river and removing them. Boats are Boat objects
-- (ServerScriptService.Classes.Boat). DockService asks it for new boats,
-- CheckpointService and WaterService ask it which boats are on the river, and
-- FartService asks which boat a player is riding.
--
-- Joining: the player who spawns a boat is its party leader. Anyone can get in by
-- sitting in a free seat, or by asking to join (RequestJoinBoat). The boat leaves when
-- its join timer runs out, when it's full, or when the leader starts the run early
-- (RequestStartRun); see the Boat class. If the leader leaves the game, someone aboard
-- takes over; if nobody is aboard, the boat is removed.

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Boat = require(ServerScriptService.Classes.Boat)
local BoatConfig = require(ReplicatedStorage.Shared.Modules.Game.BoatConfig)
local BoatServiceShared = require(ReplicatedStorage.Shared.Services.BoatService.BoatServiceShared)
local Remotes = require(ReplicatedStorage.Shared.Modules.Core.Remotes)
local Signal = require(ReplicatedStorage.Packages.Signal)

local BoatServiceServer = {}

type BoatServiceServerMembers = {
	Boats: { Boat.Boat },
	BoatsFolder: Instance,
	TemplatesFolder: Instance?,
	CrewMemberLeft: Signal.Signal, -- fires (player: Player, boat: Boat) when anyone leaves a launched boat, for any reason
	NotifyBoatWipedRemote: RemoteEvent,
	LastRequestTimes: { [Player]: number },
}

export type BoatServiceServer = typeof(BoatServiceServer) & BoatServiceServerMembers

function BoatServiceServer.Init(self: BoatServiceServer)
	self.Boats = {}
	self.CrewMemberLeft = Signal.new()
	self.LastRequestTimes = {}
	self.NotifyBoatWipedRemote =
		Remotes.CreateEvent(BoatServiceShared.SERVICE_NAME, BoatServiceShared.NOTIFY_BOAT_WIPED)
	Remotes.CreateFunction(BoatServiceShared.SERVICE_NAME, BoatServiceShared.REQUEST_JOIN_BOAT).OnServerInvoke = function(
		player: Player,
		boatModel: unknown
	)
		return self:HandleJoinRequest(player, boatModel)
	end
	Remotes.CreateFunction(BoatServiceShared.SERVICE_NAME, BoatServiceShared.REQUEST_START_RUN).OnServerInvoke = function(
		player: Player
	)
		return self:HandleStartRequest(player)
	end

	-- Boats pass through each other, and riders on the river pass through everything.
	local boatGroup = BoatServiceShared.COLLISION_GROUP
	local riderGroup = BoatServiceShared.RIDER_COLLISION_GROUP
	for _, collisionGroup in { boatGroup, riderGroup } do
		if not PhysicsService:IsCollisionGroupRegistered(collisionGroup) then
			PhysicsService:RegisterCollisionGroup(collisionGroup)
		end
	end
	PhysicsService:CollisionGroupSetCollidable(boatGroup, boatGroup, false)
	for _, otherGroup in { "Default", boatGroup, riderGroup } do
		PhysicsService:CollisionGroupSetCollidable(riderGroup, otherGroup, false)
	end

	local boatsFolder = workspace:FindFirstChild(BoatServiceShared.BOATS_FOLDER_NAME)
	if not boatsFolder then
		warn(
			`Missing: Workspace.{BoatServiceShared.BOATS_FOLDER_NAME} (an empty Folder). Boats go straight into Workspace until it exists.`
		)
	end
	self.BoatsFolder = boatsFolder or workspace
	self.TemplatesFolder = ReplicatedStorage.Assets:FindFirstChild(BoatServiceShared.TEMPLATES_FOLDER_NAME)
	self:CheckTemplates()

	Players.PlayerRemoving:Connect(function(player)
		self:OnPlayerRemoving(player)
	end)

	RunService.Heartbeat:Connect(function()
		self:UpdateDepartures()
	end)
	task.spawn(function()
		while true do
			task.wait(BoatConfig.CLEANUP_INTERVAL)
			self:CleanUp()
		end
	end)
end

-- Warns about any boat size whose template is missing or doesn't follow the Boat contract.
function BoatServiceServer.CheckTemplates(self: BoatServiceServer)
	for seatCount = BoatConfig.MIN_SEATS, BoatConfig.MAX_SEATS do
		local templateName = BoatConfig.TEMPLATE_NAMES[seatCount]
		local template = if self.TemplatesFolder then self.TemplatesFolder:FindFirstChild(templateName) else nil
		local problem = Boat.CheckTemplate(template, seatCount)
		if problem then
			warn(
				`Boat template ReplicatedStorage.Assets.{BoatServiceShared.TEMPLATES_FOLDER_NAME}.{templateName} {problem}`
			)
		end
	end
end

-- Spawns a boat for `seatCount` players at a dock, led by `leader`. Returns the boat,
-- or nil and a message for the player. DockService has already checked the request is allowed.
function BoatServiceServer.SpawnBoat(
	self: BoatServiceServer,
	leader: Player,
	seatCount: number,
	dockCFrame: CFrame,
	launchCFrame: CFrame,
	startIndex: number
): (Boat.Boat?, string?)
	local templateName = BoatConfig.TEMPLATE_NAMES[seatCount]
	local template = if self.TemplatesFolder and templateName
		then self.TemplatesFolder:FindFirstChild(templateName)
		else nil
	if Boat.CheckTemplate(template, seatCount) or not template or not template:IsA("Model") then
		return nil, "That boat size isn't built yet"
	end

	local boat = Boat.new(template, leader, dockCFrame, launchCFrame, startIndex, self.BoatsFolder)
	boat.CrewMemberLeft:Connect(function(player: Player)
		self.CrewMemberLeft:Fire(player, boat)
	end)
	table.insert(self.Boats, boat)
	return boat, nil
end

function BoatServiceServer.DestroyBoat(self: BoatServiceServer, boat: Boat.Boat)
	boat:Destroy()
	local index = table.find(self.Boats, boat)
	if index then
		table.remove(self.Boats, index)
	end
end

-- Every boat that has left its dock and is on the river.
function BoatServiceServer.GetLaunchedBoats(self: BoatServiceServer): { Boat.Boat }
	local launchedBoats = {}
	for _, boat in self.Boats do
		if boat.State == "Launched" then
			table.insert(launchedBoats, boat)
		end
	end
	return launchedBoats
end

-- The boat waiting at a dock that `player` leads, if any.
function BoatServiceServer.GetDockedBoatLedBy(self: BoatServiceServer, player: Player): Boat.Boat?
	for _, boat in self.Boats do
		if boat.Leader == player and boat:IsAtDock() then
			return boat
		end
	end
	return nil
end

function BoatServiceServer.GetBoatByModel(self: BoatServiceServer, model: Instance): Boat.Boat?
	for _, boat in self.Boats do
		if boat.Model == model then
			return boat
		end
	end
	return nil
end

-- Sends every docked boat whose departure time has come.
function BoatServiceServer.UpdateDepartures(self: BoatServiceServer)
	local now = workspace:GetServerTimeNow()
	for _, boat in table.clone(self.Boats) do
		if boat:IsAtDock() and now >= boat:GetDepartureTime() then
			boat:Depart()
		end
	end
end

-- Returns false if `player` made a join or start request less than REQUEST_COOLDOWN ago.
function BoatServiceServer.PassesRequestCooldown(self: BoatServiceServer, player: Player): boolean
	local now = os.clock()
	local lastRequestTime = self.LastRequestTimes[player]
	if lastRequestTime and now - lastRequestTime < BoatConfig.REQUEST_COOLDOWN then
		return false
	end
	self.LastRequestTimes[player] = now
	return true
end

-- Client request: sit in a free seat of a boat waiting at a dock.
function BoatServiceServer.HandleJoinRequest(
	self: BoatServiceServer,
	player: Player,
	boatModel: unknown
): (boolean, string?)
	if typeof(boatModel) ~= "Instance" then
		return false, "Invalid request"
	end
	if not self:PassesRequestCooldown(player) then
		return false, "Wait a moment"
	end
	local boat = self:GetBoatByModel(boatModel)
	if not boat or not boat:IsAtDock() then
		return false, "That boat has already left"
	end
	if boat:GetSeatOf(player) then
		return true, nil
	end
	if self:GetLaunchedBoatOf(player) then
		return false, "You're already on the river"
	end
	if not boat:HasFreeSeat() then
		return false, "That boat is full"
	end

	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local rootPart = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not humanoid or humanoid.Health <= 0 or not rootPart or not rootPart:IsA("BasePart") then
		return false, "Wait until you've respawned"
	end
	if (rootPart.Position - boat:GetPosition()).Magnitude > BoatConfig.JOIN_DISTANCE then
		return false, "Get closer to the boat"
	end

	-- Get up from any other seat first, and give the character a moment to stand.
	local currentSeat = humanoid.SeatPart
	if currentSeat then
		local seatWeld = currentSeat:FindFirstChild("SeatWeld")
		if seatWeld then
			seatWeld:Destroy()
		end
		RunService.Heartbeat:Wait()
	end
	if not boat:SeatPlayer(player) then
		return false, "Couldn't get you a seat, try again"
	end
	return true, nil
end

-- Client request from a party leader: start the run now instead of waiting for the timer.
function BoatServiceServer.HandleStartRequest(self: BoatServiceServer, player: Player): (boolean, string?)
	if not self:PassesRequestCooldown(player) then
		return false, "Wait a moment"
	end
	local boat = self:GetDockedBoatLedBy(player)
	if not boat then
		return false, "You're not leading a boat"
	end
	if not boat:GetSeatOf(player) then
		return false, "Get in your boat first"
	end
	boat:StartEarly()
	return true, nil
end

-- Takes `player` out of whatever boat seat they're in.
function BoatServiceServer.EjectPlayer(self: BoatServiceServer, player: Player)
	for _, boat in self.Boats do
		boat:Eject(player)
	end
end

-- Forgets boats that were destroyed.
function BoatServiceServer.CleanUp(self: BoatServiceServer)
	for index = #self.Boats, 1, -1 do
		if self.Boats[index].State == "Destroyed" then
			table.remove(self.Boats, index)
		end
	end
end

-- The boat on the river that `player` is part of the crew of, if any.
function BoatServiceServer.GetLaunchedBoatOf(self: BoatServiceServer, player: Player): Boat.Boat?
	for _, boat in self.Boats do
		if boat.State == "Launched" and table.find(boat.Crew, player) then
			return boat
		end
	end
	return nil
end

-- A boat fell off the river: freeze it, tell its crew, then remove it. Removing it
-- sends the crew back to their checkpoint (CheckpointService listens to CrewMemberLeft).
function BoatServiceServer.WipeBoat(self: BoatServiceServer, boat: Boat.Boat)
	if not boat:IsFloating() then
		return
	end
	boat:Freeze()
	for _, player in boat.Crew do
		self.NotifyBoatWipedRemote:FireClient(player)
	end
	task.delay(BoatConfig.WIPE_DELAY, function()
		self:DestroyBoat(boat)
	end)
end

-- A leader who leaves the game hands their waiting boat to someone aboard. If nobody
-- else is aboard, the boat goes with them.
function BoatServiceServer.OnPlayerRemoving(self: BoatServiceServer, player: Player)
	self.LastRequestTimes[player] = nil
	local boat = self:GetDockedBoatLedBy(player)
	if not boat then
		return
	end
	for _, seatedPlayer in boat:GetSeatedPlayers() do
		if seatedPlayer ~= player and not self:GetDockedBoatLedBy(seatedPlayer) then
			boat:SetLeader(seatedPlayer)
			return
		end
	end
	self:DestroyBoat(boat)
end

return BoatServiceServer :: BoatServiceServer
]==],
	},
	{
		ParentPath = { "ServerScriptService", "Services", "CheckpointService" },
		Name = "CheckpointServiceServer",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ServerScriptService.Services.CheckpointService.CheckpointServiceServer
--
-- Owns where players are along the river: the lobby, the checkpoints and the end.
--   - Players join in the lobby and respawn at the last location they were at.
--   - A launched boat entering a checkpoint's Zone unlocks that checkpoint (and every
--     one before it) for its crew, and saves it.
--   - Players can ask to teleport to the lobby or any checkpoint they've unlocked.
--   - A boat reaching Workspace.Map.Finish beats the game. Its crew is sent back to
--     the lobby after FINISH_RETURN_DELAY.
--
-- Map contract:
--   Workspace.Map.Lobby                 a Location (see the Location class)
--   Workspace.Map.Checkpoints.<Id>      a Location for each entry in CheckpointConfig.CHECKPOINTS
--   Workspace.Map.Finish                BasePart; a launched boat whose middle is inside it has finished

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Boat = require(ServerScriptService.Classes.Boat)
local BoatServiceServer = require(ServerScriptService.Services.BoatService.BoatServiceServer)
local CheckpointConfig = require(ReplicatedStorage.Shared.Modules.Game.CheckpointConfig)
local CheckpointServiceShared = require(ReplicatedStorage.Shared.Services.CheckpointService.CheckpointServiceShared)
local DataServiceServer = require(ServerScriptService.Services.DataService.DataServiceServer)
local Geometry = require(ReplicatedStorage.Shared.Modules.Math.Geometry)
local Location = require(ServerScriptService.Classes.Location)
local Remotes = require(ReplicatedStorage.Shared.Modules.Core.Remotes)

local SERVICE_NAME = CheckpointServiceShared.SERVICE_NAME
local LOBBY_INDEX = 0 -- checkpoints are numbered from 1

local CheckpointServiceServer = {}

type CheckpointServiceServerMembers = {
	Lobby: Location.Location,
	Checkpoints: { Location.Location }, -- in river order; a checkpoint's Index is its position here
	LocationsById: { [string]: Location.Location },
	Finish: BasePart?,
	CurrentLocations: { [Player]: Location.Location }, -- where each player respawns
	LastTeleportTimes: { [Player]: number },
	FinishedBoats: { [Boat.Boat]: boolean },
	CheckpointReachedRemote: RemoteEvent,
	GameCompletedRemote: RemoteEvent,
}

export type CheckpointServiceServer = typeof(CheckpointServiceServer) & CheckpointServiceServerMembers

function CheckpointServiceServer.Init(self: CheckpointServiceServer)
	self:LoadMap()
	self.CurrentLocations = {}
	self.LastTeleportTimes = {}
	self.FinishedBoats = {}

	self.CheckpointReachedRemote = Remotes.CreateEvent(SERVICE_NAME, CheckpointServiceShared.CHECKPOINT_REACHED)
	self.GameCompletedRemote = Remotes.CreateEvent(SERVICE_NAME, CheckpointServiceShared.GAME_COMPLETED)
	Remotes.CreateFunction(SERVICE_NAME, CheckpointServiceShared.REQUEST_TELEPORT).OnServerInvoke = function(
		player: Player,
		locationId: unknown
	)
		return self:HandleTeleportRequest(player, locationId)
	end
	Remotes.CreateFunction(SERVICE_NAME, CheckpointServiceShared.REQUEST_UNLOCKED_CHECKPOINTS).OnServerInvoke = function(
		player: Player
	)
		return self:GetUnlockedIdsAsync(player)
	end

	Players.PlayerAdded:Connect(function(player)
		self:OnPlayerAdded(player)
	end)
	for _, player in Players:GetPlayers() do
		self:OnPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		self.CurrentLocations[player] = nil
		self.LastTeleportTimes[player] = nil
	end)

	-- Anyone who leaves a boat on the river goes back to their current location.
	BoatServiceServer.CrewMemberLeft:Connect(function(player: Player)
		self:MoveToCurrentLocation(player)
	end)

	task.spawn(function()
		while true do
			task.wait(CheckpointConfig.CHECK_INTERVAL)
			self:CheckBoats()
		end
	end)
end

-- Reads the lobby, checkpoints and finish from Workspace.Map.
function CheckpointServiceServer.LoadMap(self: CheckpointServiceServer)
	local map = workspace:FindFirstChild("Map")
	if not map then
		warn("Map piece missing: Workspace.Map (a Folder)")
	end
	local checkpointsFolder = if map then map:FindFirstChild("Checkpoints") else nil
	if map and not checkpointsFolder then
		warn("Map piece missing: Workspace.Map.Checkpoints (a Folder)")
	end

	self.Lobby = Location.new(
		CheckpointConfig.LOBBY_ID,
		CheckpointConfig.LOBBY_DISPLAY_NAME,
		LOBBY_INDEX,
		if map then map:FindFirstChild("Lobby") else nil,
		"Workspace.Map.Lobby"
	)
	self.LocationsById = { [self.Lobby.Id] = self.Lobby }
	self.Checkpoints = {}
	for index, info in CheckpointConfig.CHECKPOINTS do
		local folder = if checkpointsFolder then checkpointsFolder:FindFirstChild(info.Id) else nil
		local checkpoint = Location.new(info.Id, info.DisplayName, index, folder, `Workspace.Map.Checkpoints.{info.Id}`)
		self.Checkpoints[index] = checkpoint
		self.LocationsById[info.Id] = checkpoint
	end

	local finish = if map then map:FindFirstChild("Finish") else nil
	if finish and finish:IsA("BasePart") then
		self.Finish = finish
	else
		self.Finish = nil
		warn("Map piece missing: Workspace.Map.Finish (a Part)")
	end
end

-- The lobby followed by every checkpoint, in river order.
function CheckpointServiceServer.GetLocations(self: CheckpointServiceServer): { Location.Location }
	local locations = { self.Lobby }
	for _, checkpoint in self.Checkpoints do
		table.insert(locations, checkpoint)
	end
	return locations
end

function CheckpointServiceServer.OnPlayerAdded(self: CheckpointServiceServer, player: Player)
	self.CurrentLocations[player] = self.Lobby
	player.CharacterAdded:Connect(function(character)
		self:OnCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(self.OnCharacterAdded, self, player, player.Character)
	end
end

function CheckpointServiceServer.OnCharacterAdded(self: CheckpointServiceServer, player: Player, character: Model)
	character:WaitForChild("HumanoidRootPart")
	-- Let Roblox finish placing the character before moving it.
	RunService.Heartbeat:Wait()
	if player.Character == character then
		self:MoveToCurrentLocation(player)
	end
end

function CheckpointServiceServer.MoveToCurrentLocation(self: CheckpointServiceServer, player: Player)
	local location = self.CurrentLocations[player]
	local spawnCFrame = if location then location:GetSpawnCFrame() else nil
	local character = player.Character
	if character and spawnCFrame then
		character:PivotTo(spawnCFrame)
	end
end

-- The lobby is always unlocked. Checkpoints are unlocked once reached. Waits for data to load.
function CheckpointServiceServer.IsUnlockedAsync(
	self: CheckpointServiceServer,
	player: Player,
	location: Location.Location
): boolean
	if location == self.Lobby then
		return true
	end
	local data = DataServiceServer:WaitForDataAsync(player)
	return data ~= nil and data.UnlockedCheckpoints[location.Id] == true
end

-- Ids of every checkpoint `player` has unlocked, in river order. Waits for data to load.
function CheckpointServiceServer.GetUnlockedIdsAsync(self: CheckpointServiceServer, player: Player): { string }
	local unlockedIds = {}
	local data = DataServiceServer:WaitForDataAsync(player)
	if data then
		for _, checkpoint in self.Checkpoints do
			if data.UnlockedCheckpoints[checkpoint.Id] then
				table.insert(unlockedIds, checkpoint.Id)
			end
		end
	end
	return unlockedIds
end

-- Client request: teleport to the lobby or an unlocked checkpoint.
function CheckpointServiceServer.HandleTeleportRequest(
	self: CheckpointServiceServer,
	player: Player,
	locationId: unknown
): (boolean, string?)
	if typeof(locationId) ~= "string" then
		return false, "Invalid request"
	end
	local location = self.LocationsById[locationId]
	if not location then
		return false, "That place doesn't exist"
	end
	local now = os.clock()
	local lastTeleportTime = self.LastTeleportTimes[player]
	if lastTeleportTime and now - lastTeleportTime < CheckpointConfig.TELEPORT_COOLDOWN then
		return false, "Wait a moment before teleporting again"
	end
	if not self:IsUnlockedAsync(player, location) then
		return false, "You haven't reached that checkpoint yet"
	end
	if not location.Spawn then
		return false, "That checkpoint isn't built yet"
	end
	if not player.Character then
		return false, "Wait until you've respawned"
	end

	self.LastTeleportTimes[player] = now
	self.CurrentLocations[player] = location
	-- Leaving a boat on the river also moves them here, through CrewMemberLeft.
	BoatServiceServer:EjectPlayer(player)
	self:MoveToCurrentLocation(player)
	return true, nil
end

-- Checks every boat on the river against the checkpoint zones and the finish.
function CheckpointServiceServer.CheckBoats(self: CheckpointServiceServer)
	for _, boat in BoatServiceServer:GetLaunchedBoats() do
		if self.FinishedBoats[boat] then
			continue
		end
		local position = boat:GetPosition()

		local reachedIndex = 0
		for index = boat.LastCheckpointIndex + 1, #self.Checkpoints do
			if self.Checkpoints[index]:IsInZone(position) then
				reachedIndex = index
			end
		end
		if reachedIndex > 0 then
			self:OnCheckpointReached(boat, reachedIndex)
		end

		local finish = self.Finish
		if finish and Geometry.IsPointInPart(position, finish) then
			self:OnFinished(boat)
		end
	end
end

-- Unlocks every checkpoint up to and including `index`. Returns true if any were new.
function CheckpointServiceServer.UnlockUpTo(self: CheckpointServiceServer, player: Player, index: number): boolean
	local data = DataServiceServer:GetData(player)
	if not data then
		return false
	end
	local unlockedAny = false
	for checkpointIndex = 1, index do
		local checkpointId = self.Checkpoints[checkpointIndex].Id
		if not data.UnlockedCheckpoints[checkpointId] then
			data.UnlockedCheckpoints[checkpointId] = true
			unlockedAny = true
		end
	end
	return unlockedAny
end

function CheckpointServiceServer.OnCheckpointReached(self: CheckpointServiceServer, boat: Boat.Boat, index: number)
	boat.LastCheckpointIndex = index
	local checkpoint = self.Checkpoints[index]
	for _, player in boat.Crew do
		self:UnlockUpTo(player, index)
		self.CurrentLocations[player] = checkpoint
		task.spawn(function()
			self.CheckpointReachedRemote:FireClient(player, checkpoint.Id, self:GetUnlockedIdsAsync(player))
		end)
	end
end

function CheckpointServiceServer.OnFinished(self: CheckpointServiceServer, boat: Boat.Boat)
	self.FinishedBoats[boat] = true
	for _, player in boat.Crew do
		self:UnlockUpTo(player, #self.Checkpoints)
		local data = DataServiceServer:GetData(player)
		if data then
			data.Completed = true
		end
		self.CurrentLocations[player] = self.Lobby
		self.GameCompletedRemote:FireClient(player)
	end
	task.delay(CheckpointConfig.FINISH_RETURN_DELAY, function()
		-- Destroying the boat makes its crew leave it, which sends them to the lobby.
		BoatServiceServer:DestroyBoat(boat)
		self.FinishedBoats[boat] = nil
	end)
end

return CheckpointServiceServer :: CheckpointServiceServer
]==],
	},
	{
		ParentPath = { "ServerScriptService", "Services", "DataService" },
		Name = "DataServiceServer",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ServerScriptService.Services.DataService.DataServiceServer
--
-- Loads and saves each player's data (see DataConfig.PlayerData) with DataStores.
-- Other services read and change a player's data through GetData. Changes are
-- saved every AUTOSAVE_INTERVAL, when the player leaves, and when the server shuts down.
--
-- Session lock: while a player is in this server, their saved record is marked as
-- in use. If they rejoin quickly and land in another server, that server waits for
-- this one to finish saving instead of loading old data and overwriting newer data.
--
-- If data can't load (for example in Studio without API access), the player plays
-- with default data and nothing is saved, so their real data is never overwritten.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataConfig = require(ReplicatedStorage.Shared.Modules.Game.DataConfig)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)

type Session = {
	Data: DataConfig.PlayerData,
	Loaded: boolean, -- true once loading has finished, whether it worked or not
	CanSave: boolean, -- false when loading failed
}

type SessionLock = {
	JobId: string,
	Time: number,
}

type SavedRecord = {
	Data: DataConfig.PlayerData?,
	SessionLock: SessionLock?,
}

local DataServiceServer = {}

type DataServiceServerMembers = {
	Store: DataStore?, -- nil when DataStores aren't available
	Sessions: { [Player]: Session },
}

export type DataServiceServer = typeof(DataServiceServer) & DataServiceServerMembers

local function GetKey(player: Player): string
	return DataConfig.KEY_PREFIX .. player.UserId
end

local function IsLockedByAnotherServer(record: SavedRecord): boolean
	local lock = record.SessionLock
	return lock ~= nil and lock.JobId ~= game.JobId and os.time() - lock.Time < DataConfig.SESSION_LOCK_EXPIRY
end

-- Marks the saved record as in use by this server and returns it. Returns nil, and
-- changes nothing, while another server still holds it (unless `force` is true).
local function ClaimRecord(store: DataStore, key: string, force: boolean): SavedRecord?
	local claimedRecord: SavedRecord? = nil
	store:UpdateAsync(key, function(saved: SavedRecord?): SavedRecord?
		local record: SavedRecord = saved or {}
		if IsLockedByAnotherServer(record) and not force then
			claimedRecord = nil
			return nil
		end
		record.SessionLock = { JobId = game.JobId, Time = os.time() }
		claimedRecord = record
		return record
	end)
	return claimedRecord
end

function DataServiceServer.Init(self: DataServiceServer)
	self.Sessions = {}

	local success, result = pcall(function()
		return DataStoreService:GetDataStore(DataConfig.DATASTORE_NAME)
	end)
	if success then
		self.Store = result
	else
		self.Store = nil
		warn(`DataStores aren't available, so progress won't be saved: {result}`)
	end

	Players.PlayerAdded:Connect(function(player)
		self:LoadAsync(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(self.LoadAsync, self, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		self:OnPlayerRemoving(player)
	end)
	game:BindToClose(function()
		self:SaveAllAsync(true)
	end)

	task.spawn(function()
		while true do
			task.wait(DataConfig.AUTOSAVE_INTERVAL)
			self:SaveAllAsync(false)
		end
	end)
end

function DataServiceServer.LoadAsync(self: DataServiceServer, player: Player)
	local session: Session = {
		Data = TableUtil.DeepCopy(DataConfig.DEFAULT_DATA),
		Loaded = false,
		CanSave = false,
	}
	self.Sessions[player] = session

	local store = self.Store
	if store then
		local key = GetKey(player)
		for attempt = 1, DataConfig.MAX_LOAD_ATTEMPTS do
			local isLastAttempt = attempt == DataConfig.MAX_LOAD_ATTEMPTS
			-- On the last attempt, take the lock anyway: the other server has had plenty of time.
			local success, result = pcall(ClaimRecord, store, key, isLastAttempt)
			if success and result then
				local data = result.Data or TableUtil.DeepCopy(DataConfig.DEFAULT_DATA)
				TableUtil.Reconcile(data, DataConfig.DEFAULT_DATA)
				session.Data = data
				session.CanSave = true
				break
			elseif not success then
				warn(`Couldn't load data for {player.Name} (attempt {attempt}): {result}`)
				if RunService:IsStudio() then
					warn(
						"To test saving in Studio: publish the place, then turn on Game Settings > Security > Enable Studio Access to API Services."
					)
					break
				end
			end
			if isLastAttempt or not player.Parent then
				break
			end
			task.wait(DataConfig.LOAD_RETRY_DELAY)
		end
		if not session.CanSave then
			warn(`{player.Name} is playing without saving because their data didn't load.`)
		end
	end

	session.Loaded = true
	if not player.Parent then
		-- They left while loading: give the lock back and forget them.
		self:SaveAsync(player, true)
		self.Sessions[player] = nil
	end
end

-- Saves `player`'s data. With `releaseLock`, also marks the record as free for other servers.
function DataServiceServer.SaveAsync(self: DataServiceServer, player: Player, releaseLock: boolean)
	local session = self.Sessions[player]
	local store = self.Store
	if not session or not session.CanSave or not store then
		return
	end
	local data = session.Data
	local success, problem = pcall(function()
		store:UpdateAsync(GetKey(player), function(saved: SavedRecord?): SavedRecord?
			local record: SavedRecord = saved or {}
			local lock = record.SessionLock
			if lock and lock.JobId ~= game.JobId then
				return nil -- another server has taken over this player; never overwrite its data
			end
			record.Data = data
			record.SessionLock = if releaseLock then nil else { JobId = game.JobId, Time = os.time() }
			return record
		end)
	end)
	if not success then
		warn(`Couldn't save data for {player.Name}: {problem}`)
	end
end

-- Saves every player at once and returns when all saves have finished.
function DataServiceServer.SaveAllAsync(self: DataServiceServer, releaseLocks: boolean)
	local pendingSaves = 0
	for player in self.Sessions do
		pendingSaves += 1
		task.spawn(function()
			self:SaveAsync(player, releaseLocks)
			pendingSaves -= 1
		end)
	end
	while pendingSaves > 0 do
		task.wait()
	end
end

function DataServiceServer.OnPlayerRemoving(self: DataServiceServer, player: Player)
	local session = self.Sessions[player]
	if not session or not session.Loaded then
		return -- LoadAsync cleans up once it finishes
	end
	self:SaveAsync(player, true)
	self.Sessions[player] = nil
end

-- The player's data, or nil if it hasn't finished loading. Changes to the returned
-- table are saved automatically.
function DataServiceServer.GetData(self: DataServiceServer, player: Player): DataConfig.PlayerData?
	local session = self.Sessions[player]
	return if session and session.Loaded then session.Data else nil
end

-- Like GetData, but waits up to WAIT_FOR_DATA_TIMEOUT seconds for the data to load.
function DataServiceServer.WaitForDataAsync(self: DataServiceServer, player: Player): DataConfig.PlayerData?
	local deadline = os.clock() + DataConfig.WAIT_FOR_DATA_TIMEOUT
	while player.Parent and os.clock() < deadline do
		local data = self:GetData(player)
		if data then
			return data
		end
		task.wait()
	end
	return self:GetData(player)
end

return DataServiceServer :: DataServiceServer
]==],
	},
	{
		ParentPath = { "ServerScriptService", "Services", "DockService" },
		Name = "DockServiceServer",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ServerScriptService.Services.DockService.DockServiceServer
--
-- Owns the docks in the lobby and at every checkpoint. A client asks to spawn a
-- boat for a number of players at a dock; this checks the request is allowed and
-- has BoatService spawn it, with the requester as party leader. Each player can lead
-- one boat waiting at a dock: asking for another one (say, a different size) replaces
-- it, and everyone already aboard moves into the new boat, leader first, as far as
-- the seats go.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local BoatConfig = require(ReplicatedStorage.Shared.Modules.Game.BoatConfig)
local BoatServiceServer = require(ServerScriptService.Services.BoatService.BoatServiceServer)
local CheckpointServiceServer = require(ServerScriptService.Services.CheckpointService.CheckpointServiceServer)
local Dock = require(ServerScriptService.Classes.Dock)
local DockConfig = require(ReplicatedStorage.Shared.Modules.Game.DockConfig)
local DockServiceShared = require(ReplicatedStorage.Shared.Services.DockService.DockServiceShared)
local Remotes = require(ReplicatedStorage.Shared.Modules.Core.Remotes)

local DockServiceServer = {}

type DockServiceServerMembers = {
	Docks: { [Instance]: Dock.Dock }, -- dock Model -> Dock
	LastSpawnRequestTimes: { [Player]: number },
}

export type DockServiceServer = typeof(DockServiceServer) & DockServiceServerMembers

local function IsPlayerNear(player: Player, position: Vector3, maxDistance: number): boolean
	local character = player.Character
	local rootPart = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return rootPart ~= nil and rootPart:IsA("BasePart") and (rootPart.Position - position).Magnitude <= maxDistance
end

function DockServiceServer.Init(self: DockServiceServer)
	self.Docks = {}
	self.LastSpawnRequestTimes = {}
	for _, location in CheckpointServiceServer:GetLocations() do
		for _, dockModel in location.DockModels do
			self.Docks[dockModel] = Dock.new(dockModel, location)
		end
	end

	Remotes.CreateFunction(DockServiceShared.SERVICE_NAME, DockServiceShared.REQUEST_SPAWN_BOAT).OnServerInvoke = function(
		player: Player,
		dockModel: unknown,
		seatCount: unknown
	)
		return self:HandleSpawnRequest(player, dockModel, seatCount)
	end

	Players.PlayerRemoving:Connect(function(player)
		self.LastSpawnRequestTimes[player] = nil
	end)
end

-- Client request: spawn a boat for `seatCount` players at `dockModel`.
function DockServiceServer.HandleSpawnRequest(
	self: DockServiceServer,
	player: Player,
	dockModel: unknown,
	seatCount: unknown
): (boolean, string?)
	if typeof(dockModel) ~= "Instance" or typeof(seatCount) ~= "number" then
		return false, "Invalid request"
	end
	local dock = self.Docks[dockModel]
	if not dock then
		return false, "That isn't a dock"
	end
	-- Whole numbers in range only (this also rejects NaN and infinity)
	if seatCount ~= math.floor(seatCount) or seatCount < BoatConfig.MIN_SEATS or seatCount > BoatConfig.MAX_SEATS then
		return false, `Boats hold {BoatConfig.MIN_SEATS} to {BoatConfig.MAX_SEATS} players`
	end

	local now = os.clock()
	local lastRequestTime = self.LastSpawnRequestTimes[player]
	if lastRequestTime and now - lastRequestTime < DockConfig.SPAWN_COOLDOWN then
		return false, "Wait a moment before spawning another boat"
	end
	self.LastSpawnRequestTimes[player] = now

	local boatSpawn = dock.BoatSpawn
	local launch = dock.Location.Launch
	if not boatSpawn or not launch then
		return false, "This dock isn't built yet"
	end
	if not IsPlayerNear(player, boatSpawn.Position, DockConfig.MAX_REQUEST_DISTANCE) then
		return false, "Get closer to the dock"
	end
	if not CheckpointServiceServer:IsUnlockedAsync(player, dock.Location) then
		return false, "You haven't reached this checkpoint yet"
	end
	-- One waiting boat per leader: a new one replaces the old one, even at the same dock.
	local previousBoat = BoatServiceServer:GetDockedBoatLedBy(player)
	if not dock:IsFree() and (previousBoat == nil or dock.Boat ~= previousBoat) then
		return false, "This dock already has a boat"
	end
	local passengers: { Player } = {}
	if previousBoat then
		-- The party moves to the new boat, leader first.
		for _, seatedPlayer in previousBoat:GetSeatedPlayers() do
			if seatedPlayer == player then
				table.insert(passengers, 1, seatedPlayer)
			else
				table.insert(passengers, seatedPlayer)
			end
		end
		BoatServiceServer:DestroyBoat(previousBoat)
	end

	local boat, problem =
		BoatServiceServer:SpawnBoat(player, seatCount, boatSpawn.CFrame, launch.CFrame, dock.Location.Index)
	if not boat then
		return false, problem
	end
	dock.Boat = boat

	if #passengers > 0 then
		-- Give everyone a moment to stand up from the old seats before sitting them down.
		RunService.Heartbeat:Wait()
		for _, passenger in passengers do
			if passenger.Parent then
				boat:SeatPlayer(passenger)
			end
		end
	end
	return true, nil
end

return DockServiceServer :: DockServiceServer
]==],
	},
	{
		ParentPath = { "ServerScriptService", "Services", "FartService" },
		Name = "FartServiceServer",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ServerScriptService.Services.FartService.FartServiceServer
--
-- Runs every player's farting. A client asks to start farting in a direction (or to
-- switch direction, or to stop); this checks they're riding a boat on the river and
-- have gas, and keeps them farting until they stop, run out of gas or leave the boat.
-- Their fart builds up strength while they keep it going and fades after they stop
-- (FartPhysics). Gas drains at a flat rate while farting and refills while not. Other
-- players are told when someone starts, switches or stops, so they can show it.
--
-- This service doesn't move boats. WaterService asks GetThrust for how hard each
-- boat's crew is farting and moves the boat with everything else acting on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Boat = require(ServerScriptService.Classes.Boat)
local BoatServiceServer = require(ServerScriptService.Services.BoatService.BoatServiceServer)
local FartConfig = require(ReplicatedStorage.Shared.Modules.Game.FartConfig)
local FartPhysics = require(ReplicatedStorage.Shared.Services.FartService.FartPhysics)
local FartServiceShared = require(ReplicatedStorage.Shared.Services.FartService.FartServiceShared)
local Remotes = require(ReplicatedStorage.Shared.Modules.Core.Remotes)

local SERVICE_NAME = FartServiceShared.SERVICE_NAME

local FartServiceServer = {}

type FartServiceServerMembers = {
	Gas: { [Player]: number },
	Streams: { [Player]: FartPhysics.Direction }, -- everyone farting right now, and which way
	RampTimes: { [Player]: number }, -- how far each player's fart has built up (missing = not at all)
	PendingDirections: { [Player]: FartPhysics.Direction }, -- start or switch requests waiting out the cooldown
	LastStartTimes: { [Player]: number },
	PlayFartRemote: RemoteEvent,
	StopFartRemote: RemoteEvent,
}

export type FartServiceServer = typeof(FartServiceServer) & FartServiceServerMembers

function FartServiceServer.Init(self: FartServiceServer)
	self.Gas = {}
	self.Streams = {}
	self.RampTimes = {}
	self.PendingDirections = {}
	self.LastStartTimes = {}
	self.PlayFartRemote = Remotes.CreateEvent(SERVICE_NAME, FartServiceShared.PLAY_FART)
	self.StopFartRemote = Remotes.CreateEvent(SERVICE_NAME, FartServiceShared.STOP_FART)

	Remotes.CreateEvent(SERVICE_NAME, FartServiceShared.REQUEST_START_FART).OnServerEvent
		:Connect(function(player: Player, direction: unknown)
			self:HandleStartRequest(player, direction)
		end)
	Remotes.CreateEvent(SERVICE_NAME, FartServiceShared.REQUEST_STOP_FART).OnServerEvent
		:Connect(function(player: Player)
			self:StopStream(player, false)
		end)

	Players.PlayerAdded:Connect(function(player)
		self:SetGas(player, FartConfig.GAS_MAX)
	end)
	for _, player in Players:GetPlayers() do
		self:SetGas(player, FartConfig.GAS_MAX)
	end
	Players.PlayerRemoving:Connect(function(player)
		self:StopStream(player, false)
		self.Gas[player] = nil
		self.RampTimes[player] = nil
		self.LastStartTimes[player] = nil
	end)

	RunService.Heartbeat:Connect(function(deltaTime)
		self:Update(deltaTime)
	end)
end

function FartServiceServer.SetGas(self: FartServiceServer, player: Player, gas: number)
	self.Gas[player] = gas
	-- Players see whole numbers, which keeps attribute updates down.
	local shownGas = math.floor(gas)
	if player:GetAttribute(FartServiceShared.GAS_ATTRIBUTE) ~= shownGas then
		player:SetAttribute(FartServiceShared.GAS_ATTRIBUTE, shownGas)
	end
end

-- Client request: start farting in `direction`, or switch to it if already farting.
-- Requests closer together than REQUEST_COOLDOWN aren't dropped: the latest one waits
-- and is acted on when the cooldown is up, so the server always ends up doing what the
-- player last asked for.
function FartServiceServer.HandleStartRequest(self: FartServiceServer, player: Player, direction: unknown)
	if not FartPhysics.IsDirection(direction) then
		return
	end
	local requestedDirection: FartPhysics.Direction = direction :: FartPhysics.Direction
	if self.Streams[player] == requestedDirection then
		self.PendingDirections[player] = nil
		return
	end
	local lastStartTime = self.LastStartTimes[player]
	if lastStartTime and os.clock() - lastStartTime < FartConfig.REQUEST_COOLDOWN then
		self.PendingDirections[player] = requestedDirection
		return
	end
	self:StartStream(player, requestedDirection)
end

-- Starts `player` farting in `direction`, or switches their fart to it, if they're
-- allowed to. If they aren't, their client is told to stop showing the fart.
function FartServiceServer.StartStream(self: FartServiceServer, player: Player, direction: FartPhysics.Direction)
	self.PendingDirections[player] = nil
	local isSwitching = self.Streams[player] ~= nil
	local boat = BoatServiceServer:GetLaunchedBoatOf(player)
	local gas = self.Gas[player] or 0
	local hasGas = if isSwitching then gas > 0 else gas >= FartConfig.MIN_GAS_TO_START
	if not boat or not boat:IsFloating() or not boat:GetSeatOf(player) or not hasGas then
		if isSwitching then
			self:StopStream(player, true)
		else
			self.StopFartRemote:FireClient(player, player)
		end
		return
	end

	self.LastStartTimes[player] = os.clock()
	self.Streams[player] = direction
	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer ~= player then
			self.PlayFartRemote:FireClient(otherPlayer, player, direction)
		end
	end
end

-- Ends `player`'s fart. `notifyFarter` also tells the farter, for when the server
-- stops it (out of gas, left the boat) rather than the farter letting go.
function FartServiceServer.StopStream(self: FartServiceServer, player: Player, notifyFarter: boolean)
	self.PendingDirections[player] = nil
	if not self.Streams[player] then
		return
	end
	self.Streams[player] = nil
	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer ~= player or notifyFarter then
			self.StopFartRemote:FireClient(otherPlayer, player)
		end
	end
end

-- How hard `boat`'s crew is farting right now, all added up: the push in studs/s² and
-- the turn in rad/s² (positive turns left). This is the raw push from the farts; the
-- boat's size decides how much it moves (see the Hull class).
function FartServiceServer.GetThrust(self: FartServiceServer, boat: Boat.Boat): (Vector3, number)
	local totalPush = Vector3.zero
	local totalTurn = 0
	if not boat:IsFloating() then
		return totalPush, totalTurn
	end
	local boatPosition = boat:GetPosition()
	for _, player in boat.Crew do
		local direction: FartPhysics.Direction? = self.Streams[player]
		local seat = if direction then boat:GetSeatOf(player) else nil
		if direction and seat and (self.Gas[player] or 0) > 0 then
			local push, turn = FartPhysics.GetThrust(boatPosition, seat.CFrame, direction, self.RampTimes[player] or 0)
			totalPush += push
			totalTurn += turn
		end
	end
	return totalPush, totalTurn
end

function FartServiceServer.Update(self: FartServiceServer, deltaTime: number)
	-- Requests that were waiting out the cooldown
	local now = os.clock()
	for player, direction: FartPhysics.Direction in self.PendingDirections do
		local lastStartTime = self.LastStartTimes[player]
		if not lastStartTime or now - lastStartTime >= FartConfig.REQUEST_COOLDOWN then
			self:StartStream(player, direction)
		end
	end

	-- Farts end when the farter runs out of gas or isn't riding on the river any more.
	for player in self.Streams do
		local boat = BoatServiceServer:GetLaunchedBoatOf(player)
		local gas = self.Gas[player] or 0
		if not boat or not boat:IsFloating() or not boat:GetSeatOf(player) or gas <= 0 then
			self:StopStream(player, true)
			continue
		end
		self:SetGas(player, math.max(0, gas - FartConfig.GAS_DRAIN * deltaTime))
	end

	for player, gas in self.Gas do
		local isFarting = self.Streams[player] ~= nil
		local rampTime = FartPhysics.UpdateRampTime(self.RampTimes[player] or 0, isFarting, deltaTime)
		if rampTime > 0 then
			self.RampTimes[player] = rampTime
		else
			self.RampTimes[player] = nil
		end
		if not isFarting and gas < FartConfig.GAS_MAX then
			self:SetGas(player, math.min(FartConfig.GAS_MAX, gas + FartConfig.GAS_REGEN * deltaTime))
		end
	end
end

return FartServiceServer :: FartServiceServer
]==],
	},
	{
		ParentPath = { "ServerScriptService", "Services", "WaterService" },
		Name = "WaterServiceServer",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ServerScriptService.Services.WaterService.WaterServiceServer
--
-- Moves every boat on the river. Each frame, for each boat, it works out what the
-- water under the boat is doing (its surface with the waves, its current and how rough
-- it is), asks FartService how hard the crew is farting, and steps the boat's Hull
-- with both. Where there's no water under a boat, nothing holds it up and it falls. A
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
			BoatServiceServer:WipeBoat(boat)
			continue
		end
		local thrust, turn = FartServiceServer:GetThrust(boat)
		hull:Step(water, thrust, turn, stepTime)
	end
end

return WaterServiceServer :: WaterServiceServer
]==],
	},
	{
		ParentPath = { "ReplicatedStorage", "Shared", "Modules", "Core" },
		Name = "Remotes",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ReplicatedStorage.Shared.Modules.Core.Remotes
--
-- Remotes are made in code, never by hand. The server half of a service creates
-- them in a "Remotes" folder inside that service's folder in
-- ReplicatedStorage.Shared.Services. The client half waits for them by name.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTES_FOLDER_NAME = "Remotes"

local Remotes = {}

local function GetOrCreateRemotesFolder(serviceName: string): Instance
	local serviceFolder = ReplicatedStorage.Shared.Services:FindFirstChild(serviceName)
	assert(serviceFolder, `ReplicatedStorage.Shared.Services has no {serviceName} folder`)
	local remotesFolder = serviceFolder:FindFirstChild(REMOTES_FOLDER_NAME)
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = REMOTES_FOLDER_NAME
		remotesFolder.Parent = serviceFolder
	end
	return remotesFolder
end

local function Create(serviceName: string, className: string, remoteName: string): Instance
	assert(RunService:IsServer(), "Only the server creates remotes")
	local remotesFolder = GetOrCreateRemotesFolder(serviceName)
	assert(not remotesFolder:FindFirstChild(remoteName), `{serviceName} already has a remote named {remoteName}`)
	local remote = Instance.new(className)
	remote.Name = remoteName
	remote.Parent = remotesFolder
	return remote
end

local function WaitFor(serviceName: string, remoteName: string): Instance
	local serviceFolder = ReplicatedStorage.Shared.Services:WaitForChild(serviceName)
	return serviceFolder:WaitForChild(REMOTES_FOLDER_NAME):WaitForChild(remoteName)
end

function Remotes.CreateEvent(serviceName: string, remoteName: string): RemoteEvent
	return Create(serviceName, "RemoteEvent", remoteName) :: RemoteEvent
end

function Remotes.CreateFunction(serviceName: string, remoteName: string): RemoteFunction
	return Create(serviceName, "RemoteFunction", remoteName) :: RemoteFunction
end

-- Waits until the server has created the remote. Use it from the client only.
function Remotes.WaitForEvent(serviceName: string, remoteName: string): RemoteEvent
	local remote = WaitFor(serviceName, remoteName)
	assert(remote:IsA("RemoteEvent"), `{serviceName}.{remoteName} is not a RemoteEvent`)
	return remote
end

-- Waits until the server has created the remote. Use it from the client only.
function Remotes.WaitForFunction(serviceName: string, remoteName: string): RemoteFunction
	local remote = WaitFor(serviceName, remoteName)
	assert(remote:IsA("RemoteFunction"), `{serviceName}.{remoteName} is not a RemoteFunction`)
	return remote
end

return Remotes
]==],
	},
	{
		ParentPath = { "ReplicatedStorage", "Shared", "Modules", "Game" },
		Name = "BoatConfig",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ReplicatedStorage.Shared.Modules.Game.BoatConfig

export type Handling = {
	PushScale: number,
	TurnScale: number,
	TopTurnSpeed: number,
}

local BoatConfig = {
	MIN_SEATS = 1,
	MAX_SEATS = 6,

	-- The boat template for each size, in ReplicatedStorage.Assets.Boats.
	-- Each template needs exactly that many Seats.
	TEMPLATE_NAMES = {
		[1] = "Boat1",
		[2] = "Boat2",
		[3] = "Boat3",
		[4] = "Boat4",
		[5] = "Boat5",
		[6] = "Boat6",
	} :: { [number]: string },

	-- How each boat size handles (ServerScriptService.Classes.Hull). Small boats are nimble,
	-- so one rider can steer them alone. Big boats are heavy: one rider turns them slowly,
	-- and the crew has to fart together to turn them quickly (every rider's turn adds up).
	--   PushScale      multiplies how hard farts (and rough water) push the boat along
	--   TurnScale      multiplies how hard farts (and rough water) turn it
	--   TopTurnSpeed   how fast it turns (rad/s) with ONE rider turning at full strength.
	--                  More riders turning together go past it.
	HANDLING = {
		[1] = { PushScale = 1.1, TurnScale = 1.5, TopTurnSpeed = math.rad(150) },
		[2] = { PushScale = 1.05, TurnScale = 1, TopTurnSpeed = math.rad(115) },
		[3] = { PushScale = 1, TurnScale = 0.75, TopTurnSpeed = math.rad(90) },
		[4] = { PushScale = 0.95, TurnScale = 0.6, TopTurnSpeed = math.rad(75) },
		[5] = { PushScale = 0.9, TurnScale = 0.5, TopTurnSpeed = math.rad(63) },
		[6] = { PushScale = 0.85, TurnScale = 0.4, TopTurnSpeed = math.rad(52) },
	} :: { [number]: Handling },

	-- Joining
	JOIN_TIME = 30, -- seconds players have to get in after the party leader spawns a boat
	LAUNCH_DELAY = 3, -- countdown (seconds) once every seat is taken or the leader starts the run early
	JOIN_DISTANCE = 40, -- how close (studs) a player must be to a boat to ask to join it
	REQUEST_COOLDOWN = 1, -- seconds a player has to wait between join or start requests
	CLEANUP_INTERVAL = 1, -- seconds between checks for removed boats to forget
	WIPE_DELAY = 1.5, -- seconds a boat that fell off the river hangs frozen before its crew respawns

	-- Tilting. A boat on the river rocks with the waves and leans away from the way it's
	-- speeding up or turning (its far side lifts when it surges forward, and it heels over
	-- in a turn or when it hits something), then rights itself.
	UPRIGHT_RESPONSIVENESS = 12, -- how quickly it tilts to follow the waves and its lean (higher = stiffer)
	LEAN_PER_ACCELERATION = 0.0035, -- radians of lean per stud/s² of speeding up, slowing down or turning
	LEAN_SMOOTHING = 6, -- how quickly the lean follows changes (higher = snappier, lower = smoother)
	MAX_TILT = math.rad(12), -- it never tilts further than this from level (waves and lean together)

	-- Every part of a spawned boat gets these, keeping its own density: a slippery,
	-- slightly bouncy hull that glances off rocks and banks instead of sticking to them.
	HULL_FRICTION = 0.05,
	HULL_ELASTICITY = 0.3,
	HULL_FRICTION_WEIGHT = 50, -- how much the hull's friction wins over what it touches
	HULL_ELASTICITY_WEIGHT = 50, -- how much the hull's bounciness wins over what it touches

	CENTER_SEAT_RADIUS = 1, -- a seat closer than this (studs) to the middle of the boat counts as a middle seat
}

return BoatConfig
]==],
	},
	{
		ParentPath = { "ReplicatedStorage", "Shared", "Modules", "Game" },
		Name = "CameraConfig",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ReplicatedStorage.Shared.Modules.Game.CameraConfig

local CameraConfig = {
	SEAT_CAM_BACK = 14, -- studs behind your seat
	SEAT_CAM_UP = 9, -- studs above your seat
	SEAT_CAM_LOOK_AHEAD = 10, -- how far past the middle of the boat the camera looks
	SEAT_CAM_SMOOTHING = 8, -- higher = the camera follows more tightly
	SHAKE_DECAY = 8, -- how fast camera shake dies down

	-- Your boat hitting something or landing hard shakes the Seat Cam
	IMPACT_SPEED_CHANGE = 12, -- studs/s your boat's speed has to change by at once to count
	IMPACT_SHAKE_PER_SPEED = 0.02, -- studs of shake per stud/s of that change
	MAX_IMPACT_SHAKE = 0.8, -- studs
}

return CameraConfig
]==],
	},
	{
		ParentPath = { "ReplicatedStorage", "Shared", "Modules", "Game" },
		Name = "CheckpointConfig",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ReplicatedStorage.Shared.Modules.Game.CheckpointConfig

export type CheckpointInfo = {
	Id: string, -- must match a folder name in Workspace.Map.Checkpoints
	DisplayName: string, -- what menus show
}

local CheckpointConfig = {
	LOBBY_ID = "Lobby",
	LOBBY_DISPLAY_NAME = "Lobby",

	-- Every checkpoint, in the order the river reaches them. These three are
	-- placeholders until the map is built: rename, add or remove entries to match it.
	CHECKPOINTS = {
		{ Id = "Checkpoint1", DisplayName = "Checkpoint 1" },
		{ Id = "Checkpoint2", DisplayName = "Checkpoint 2" },
		{ Id = "Checkpoint3", DisplayName = "Checkpoint 3" },
	} :: { CheckpointInfo },

	TELEPORT_COOLDOWN = 3, -- seconds a player has to wait between teleports
	SPAWN_HEIGHT = 3, -- studs above a location's Spawn part that players appear
	FINISH_RETURN_DELAY = 5, -- seconds after reaching the end before the crew goes back to the lobby
	CHECK_INTERVAL = 0.1, -- seconds between checks for boats reaching checkpoints or the end
}

return CheckpointConfig
]==],
	},
	{
		ParentPath = { "ReplicatedStorage", "Shared", "Modules", "Game" },
		Name = "DataConfig",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ReplicatedStorage.Shared.Modules.Game.DataConfig

export type PlayerData = {
	UnlockedCheckpoints: { [string]: boolean }, -- checkpoint Id -> true once reached
	Completed: boolean, -- has reached the end of the river at least once
}

local DataConfig = {
	DATASTORE_NAME = "PlayerData",
	KEY_PREFIX = "Player_",

	-- What a brand-new player starts with. Fields added here later are filled in
	-- for existing players the next time their data loads.
	DEFAULT_DATA = {
		UnlockedCheckpoints = {},
		Completed = false,
	} :: PlayerData,

	MAX_LOAD_ATTEMPTS = 5,
	LOAD_RETRY_DELAY = 3, -- seconds between load attempts
	AUTOSAVE_INTERVAL = 120, -- seconds between automatic saves
	SESSION_LOCK_EXPIRY = 600, -- seconds before a lock from a server that crashed is ignored
	WAIT_FOR_DATA_TIMEOUT = 15, -- longest a request waits (in seconds) for a player's data to load
}

return DataConfig
]==],
	},
	{
		ParentPath = { "ReplicatedStorage", "Shared", "Modules", "Game" },
		Name = "DockConfig",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ReplicatedStorage.Shared.Modules.Game.DockConfig

local DockConfig = {
	SPAWN_COOLDOWN = 3, -- seconds a player has to wait between boat spawn requests
	MAX_REQUEST_DISTANCE = 40, -- how close (in studs) a player must be to a dock's BoatSpawn to use it
}

return DockConfig
]==],
	},
	{
		ParentPath = { "ReplicatedStorage", "Shared", "Modules", "Game" },
		Name = "FartConfig",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ReplicatedStorage.Shared.Modules.Game.FartConfig

local FartConfig = {
	-- Strength. Holding a fart key pushes the boat with a set acceleration that builds up
	-- the longer you keep farting, up to a maximum. Switching direction keeps it built up,
	-- and after you let go it fades instead of resetting, so a quick re-press picks up
	-- close to where you left off. How much a push moves a boat depends on the boat's size
	-- (BoatConfig.HANDLING); water drag decides how fast it ends up going (WaterConfig).

	-- Pushing, in studs/s²: how much speed a fart adds every second
	STRAIGHT_ACCELERATION = 18, -- when a fart starts
	STRAIGHT_ACCELERATION_GAIN = 12, -- added for every second you keep farting
	MAX_STRAIGHT_ACCELERATION = 45, -- reached after 2.25 seconds of farting
	SIDE_PUSH_FRACTION = 0.45, -- a Left/Right fart also pushes sideways at this fraction of the above

	-- Turning, in rad/s² (1 rad is about 57 degrees)
	TURN_ACCELERATION = 1.6, -- when a Left/Right fart starts
	TURN_ACCELERATION_GAIN = 1.2, -- added for every second you keep farting
	MAX_TURN_ACCELERATION = 4, -- reached after 2 seconds of farting

	RAMP_DECAY = 3, -- after you let go, built-up strength fades this many times faster than it built up

	-- Gas meter (each player's is in their "Gas" attribute)
	GAS_MAX = 100,
	GAS_DRAIN = 10, -- per second while farting, the same however long you've farted: a full tank lasts 10 seconds
	GAS_REGEN = 15, -- per second while not farting
	MIN_GAS_TO_START = 5, -- below this, pressing a fart key just gives a sad little puff
	REQUEST_COOLDOWN = 0.1, -- seconds between start or switch requests the server acts on for one player;
	-- a request that comes sooner is held and acted on when the time is up

	-- Effects. They grow with the fart's strength, from when it starts to full acceleration.
	BUTT_OFFSET = CFrame.new(0, -1, 0.6), -- where gas comes out, relative to the HumanoidRootPart
	GAS_ANGLE = math.rad(45), -- how far left or right of straight back the gas comes out on a Left/Right fart
	MIN_PARTICLE_RATE = 20, -- particles per second when a fart starts...
	MAX_PARTICLE_RATE = 60, -- ...and at full acceleration
	MAX_PARTICLE_SPEED_MULTIPLIER = 2.5, -- the cloud's Speed is multiplied by up to this at full acceleration
	STREAM_VOLUME = 0.5, -- sound volume when a fart starts...
	MAX_STREAM_VOLUME = 1, -- ...and at full acceleration
	MIN_PITCH = 0.85, -- every fart picks a random starting pitch between these
	MAX_PITCH = 1.15,
	PITCH_RISE = 0.25, -- the pitch rises by this fraction by full acceleration
	DUD_PARTICLES = 3, -- the puff when there isn't enough gas
	DUD_VOLUME = 0.25,
	DUD_PITCH = 1.6, -- multiplies the pitch of duds (squeakier)
	DUD_SOUND_LIFETIME = 3, -- seconds before a dud sound is cleaned up
}

return FartConfig
]==],
	},
	{
		ParentPath = { "ReplicatedStorage", "Shared", "Modules", "Game" },
		Name = "WaterConfig",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ReplicatedStorage.Shared.Modules.Game.WaterConfig
--
-- How water acts on boats (WaterService samples the water, the Hull class moves the boat).

export type Wave = {
	Height: number, -- studs a crest rises above the still surface (a trough sinks as far below)
	Length: number, -- studs from one crest to the next
	Period: number, -- seconds between crests passing the same spot
	Direction: Vector2, -- which way it travels, flat on the water (X, Z)
}

export type WaterType = {
	Speed: number, -- studs/s the water flows toward its part's front face
	WaveScale: number, -- multiplies the height of every wave in WAVES
	Turbulence: number, -- studs/s² of random shoving, like rapids grabbing the boat
	TurnTurbulence: number, -- rad/s² of random twisting
}

local WaterConfig = {
	-- Drag. Water slows a boat toward the speed of the water under it, in two parts: a
	-- gentle drag at any speed, so a boat glides on when its crew stops farting, and a
	-- drag that grows with speed, so a boat levels off smoothly at its top speed instead
	-- of hitting a limit.
	GLIDE_DRAG = 0.5, -- per second
	TOP_SPEED = 30, -- studs/s that one rider farting Straight at full strength levels off at
	TURN_GLIDE_DRAG = 1.2, -- per second: how fast a boat stops turning once nobody turns it
	-- (a boat's top turn speed is its TopTurnSpeed in BoatConfig.HANDLING)
	AIR_DRAG = 0.15, -- out of the water, drag is this fraction of the water's

	-- Floating. The water holds a boat up at the surface like a soft spring, so it bobs on
	-- the waves and settles after a drop instead of bouncing back out.
	FLOAT_HEIGHT = 0, -- how far above the surface a boat's PrimaryPart floats
	FLOAT_STIFFNESS = 40, -- studs/s² of push back up for every stud a boat is pushed under
	MAX_FLOAT_DEPTH = 3, -- pushing a boat deeper than this doesn't push it back up any harder
	FLOAT_DAMPING = 9, -- how quickly bobbing dies down, per second
	SPLASH_DAMPING = 0.25, -- extra damping that grows with up/down speed, so a boat hitting the water fast stops quickly
	AIRBORNE_HEIGHT = 1.5, -- a boat's PrimaryPart this far above the surface is out of the water;
	-- between there and the surface the water's hold fades in, so leaving and landing are smooth
	TILT_DAMPING = 2, -- how quickly rocking dies down, per second

	-- Waves: gentle swells that boats bob and rock on. The water parts stay flat; only the
	-- boats move. Set WAVES to {} for flat water.
	WAVES = {
		{ Height = 0.2, Length = 40, Period = 3.2, Direction = Vector2.new(0.8, 0.6) },
		{ Height = 0.12, Length = 26, Period = 2.3, Direction = Vector2.new(-0.5, 0.85) },
	} :: { Wave },

	-- Rough water: turbulence changes smoothly over this many studs and seconds
	TURBULENCE_SIZE = 14,
	TURBULENCE_TIME = 2,

	-- Water parts are named after an entry here, or are calm, still water.
	WATER_TYPES = {
		Current = { Speed = 4, WaveScale = 1.3, Turbulence = 0, TurnTurbulence = 0 },
		Rapids = { Speed = 8, WaveScale = 2, Turbulence = 8, TurnTurbulence = 0.5 },
	} :: { [string]: WaterType },
	CALM_WATER = { Speed = 0, WaveScale = 1, Turbulence = 0, TurnTurbulence = 0 } :: WaterType,

	-- Finding the water. Boats look for a surface from this far above their PrimaryPart
	-- down to this far below it. Don't put two water surfaces within this range of each
	-- other, one above the other.
	WATER_CHECK_ABOVE = 8,
	WATER_CHECK_BELOW = 8,

	FALL_DISTANCE = 30, -- a boat this far below the last water it floated on has fallen off the river
	MAX_STEP_TIME = 0.1, -- a laggy frame never moves boats more than this many seconds' worth
}

return WaterConfig
]==],
	},
	{
		ParentPath = { "ReplicatedStorage", "Shared", "Modules", "Math" },
		Name = "Geometry",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ReplicatedStorage.Shared.Modules.Math.Geometry

local Geometry = {}

-- Whether a point is inside a part's box, taking its size and rotation into account.
function Geometry.IsPointInPart(point: Vector3, part: BasePart): boolean
	local relative = part.CFrame:PointToObjectSpace(point)
	local halfSize = part.Size / 2
	return math.abs(relative.X) <= halfSize.X
		and math.abs(relative.Y) <= halfSize.Y
		and math.abs(relative.Z) <= halfSize.Z
end

return Geometry
]==],
	},
	{
		ParentPath = { "ReplicatedStorage", "Shared", "Services", "BoatService" },
		Name = "BoatServiceClient",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.BoatService.BoatServiceClient
--
-- The client half of BoatService.
--   - While the local player sits in a boat on the river, jumping is switched off so
--     they don't fall out by accident. (The server still handles anyone who leaves.)
--   - BoatWiped fires when their boat falls off the river, for the UI (a RIP screen).
--   - RequestJoinBoat, RequestStartRun, IsLeaderOf and GetSecondsUntilDeparture are for
--     the joining UI (to be built): a Join button, the leader's Start button and the timer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BoatServiceShared = require(ReplicatedStorage.Shared.Services.BoatService.BoatServiceShared)
local Remotes = require(ReplicatedStorage.Shared.Modules.Core.Remotes)
local Signal = require(ReplicatedStorage.Packages.Signal)

local BoatServiceClient = {}

type BoatServiceClientMembers = {
	LockedHumanoid: Humanoid?, -- the humanoid whose jumping is currently switched off
	BoatWiped: Signal.Signal, -- fires () when the local player's boat falls off the river
}

export type BoatServiceClient = typeof(BoatServiceClient) & BoatServiceClientMembers

function BoatServiceClient.Init(self: BoatServiceClient)
	self.LockedHumanoid = nil
	self.BoatWiped = Signal.new()

	RunService.Heartbeat:Connect(function()
		self:UpdateJumpLock()
	end)

	-- Remotes are waited for in a separate thread so Init never yields.
	task.spawn(function()
		Remotes.WaitForEvent(BoatServiceShared.SERVICE_NAME, BoatServiceShared.NOTIFY_BOAT_WIPED).OnClientEvent
			:Connect(function()
				self.BoatWiped:Fire()
			end)
	end)
end

function BoatServiceClient.UpdateJumpLock(self: BoatServiceClient)
	local character = Players.LocalPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local seat = if humanoid then humanoid.SeatPart else nil
	local boatModel = if seat then BoatServiceShared.GetBoatModelFromPart(seat) else nil
	local isOnRiver = boatModel ~= nil and boatModel:GetAttribute(BoatServiceShared.STATE_ATTRIBUTE) == "Launched"
	local humanoidToLock = if isOnRiver then humanoid else nil

	if humanoidToLock == self.LockedHumanoid then
		return
	end
	local previousHumanoid = self.LockedHumanoid
	if previousHumanoid then
		previousHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end
	if humanoidToLock then
		humanoidToLock:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	end
	self.LockedHumanoid = humanoidToLock
end

-- Asks to sit in a free seat of `boatModel`, a boat waiting at a dock.
-- Returns whether it worked and, if not, a message to show the player.
function BoatServiceClient.RequestJoinBoat(self: BoatServiceClient, boatModel: Model): (boolean, string?)
	local remote = Remotes.WaitForFunction(BoatServiceShared.SERVICE_NAME, BoatServiceShared.REQUEST_JOIN_BOAT)
	local success, message = remote:InvokeServer(boatModel)
	return success == true, if type(message) == "string" then message else nil
end

-- Party leader only: start the run now instead of waiting for the join timer.
-- Returns whether it worked and, if not, a message to show the player.
function BoatServiceClient.RequestStartRun(self: BoatServiceClient): (boolean, string?)
	local remote = Remotes.WaitForFunction(BoatServiceShared.SERVICE_NAME, BoatServiceShared.REQUEST_START_RUN)
	local success, message = remote:InvokeServer()
	return success == true, if type(message) == "string" then message else nil
end

-- Whether the local player leads `boatModel`.
function BoatServiceClient.IsLeaderOf(self: BoatServiceClient, boatModel: Model): boolean
	return boatModel:GetAttribute(BoatServiceShared.LEADER_ATTRIBUTE) == Players.LocalPlayer.UserId
end

-- Seconds until `boatModel` leaves its dock, or nil once it has left.
function BoatServiceClient.GetSecondsUntilDeparture(self: BoatServiceClient, boatModel: Model): number?
	local departureTime = boatModel:GetAttribute(BoatServiceShared.DEPARTURE_TIME_ATTRIBUTE)
	if typeof(departureTime) ~= "number" then
		return nil
	end
	return math.max(0, departureTime - workspace:GetServerTimeNow())
end

return BoatServiceClient :: BoatServiceClient
]==],
	},
	{
		ParentPath = { "ReplicatedStorage", "Shared", "Services", "BoatService" },
		Name = "BoatServiceShared",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.BoatService.BoatServiceShared
--
-- Names and helpers both halves of BoatService (and other services) agree on.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoatConfig = require(ReplicatedStorage.Shared.Modules.Game.BoatConfig)

export type BoatState = "Docked" | "Launched" | "Destroyed"

local BoatServiceShared = {
	SERVICE_NAME = "BoatService",
	BOATS_FOLDER_NAME = "Boats", -- Workspace.Boats holds every spawned boat
	TEMPLATES_FOLDER_NAME = "Boats", -- ReplicatedStorage.Assets.Boats holds the boat templates
	COLLISION_GROUP = "Boats", -- boats pass through each other
	RIDER_COLLISION_GROUP = "Riders", -- riders on the river don't bump into anything; only their boat does

	-- Attributes on each spawned boat model, for clients and UI
	STATE_ATTRIBUTE = "State", -- a BoatState
	LEADER_ATTRIBUTE = "LeaderUserId", -- UserId of the party leader
	DEPARTURE_TIME_ATTRIBUTE = "DepartureTime", -- server time (workspace:GetServerTimeNow()) a docked boat leaves

	-- Remotes
	NOTIFY_BOAT_WIPED = "NotifyBoatWiped", -- RemoteEvent to each crew member when their boat falls off the river
	REQUEST_JOIN_BOAT = "RequestJoinBoat", -- RemoteFunction (boat: Model) -> (success: boolean, message: string?)
	REQUEST_START_RUN = "RequestStartRun", -- RemoteFunction () -> (success: boolean, message: string?); party leader only
}

-- The spawned boat model a part belongs to (for example a Seat), if any.
function BoatServiceShared.GetBoatModelFromPart(part: Instance): Model?
	local boatsFolder = workspace:FindFirstChild(BoatServiceShared.BOATS_FOLDER_NAME) or workspace
	local ancestor: Instance? = part
	while ancestor and ancestor.Parent ~= boatsFolder do
		ancestor = ancestor.Parent
	end
	return if ancestor and ancestor:IsA("Model") then ancestor else nil
end

-- Which way a rider faces, flat on the water: toward the middle of the boat. A rider
-- in a middle seat (like a one-seat boat) faces the way their seat faces.
function BoatServiceShared.GetRiderFacing(boatPosition: Vector3, seatCFrame: CFrame): Vector3
	local towardMiddle = (boatPosition - seatCFrame.Position) * Vector3.new(1, 0, 1)
	if towardMiddle.Magnitude >= BoatConfig.CENTER_SEAT_RADIUS then
		return towardMiddle.Unit
	end
	local seatFacing = seatCFrame.LookVector * Vector3.new(1, 0, 1)
	return if seatFacing.Magnitude > 0 then seatFacing.Unit else -Vector3.zAxis
end

return BoatServiceShared
]==],
	},
	{
		ParentPath = { "ReplicatedStorage", "Shared", "Services", "CameraService" },
		Name = "CameraServiceClient",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.CameraService.CameraServiceClient
--
-- Seat Cam: while the local player rides a boat on the river, the camera sits behind
-- their own seat and looks across the boat. That way Straight always pushes the boat
-- up the screen and Left always turns the view left. Press V (or Y on a controller)
-- to switch to the normal Roblox camera and back.
--
-- The camera rides at the height of the boat's middle, so it bobs gently with the
-- waves but doesn't swing up and down as the boat rocks. A hard bump or a big splash
-- shakes it.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BoatServiceShared = require(ReplicatedStorage.Shared.Services.BoatService.BoatServiceShared)
local CameraConfig = require(ReplicatedStorage.Shared.Modules.Game.CameraConfig)

local localPlayer = Players.LocalPlayer

local CameraServiceClient = {}

type CameraServiceClientMembers = {
	SeatCamEnabled: boolean,
	ShakeAmount: number,
	SmoothedCFrame: CFrame?,
	Random: Random,
	LastBoatModel: Model?, -- the boat the Seat Cam followed last frame...
	LastBoatVelocity: Vector3?, -- ...and how fast it was going, to notice bumps
}

export type CameraServiceClient = typeof(CameraServiceClient) & CameraServiceClientMembers

-- The boat model and seat the local player is riding on the river, if any.
local function GetRiddenSeat(): (Model?, BasePart?)
	local character = localPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local seat = if humanoid then humanoid.SeatPart else nil
	local boatModel = if seat then BoatServiceShared.GetBoatModelFromPart(seat) else nil
	if not seat or not boatModel or boatModel:GetAttribute(BoatServiceShared.STATE_ATTRIBUTE) ~= "Launched" then
		return nil, nil
	end
	return boatModel, seat
end

function CameraServiceClient.Init(self: CameraServiceClient)
	self.SeatCamEnabled = true
	self.ShakeAmount = 0
	self.SmoothedCFrame = nil
	self.Random = Random.new()
	self.LastBoatModel = nil
	self.LastBoatVelocity = nil

	RunService:BindToRenderStep("SeatCam", Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
		self:Update(deltaTime)
	end)
	ContextActionService:BindAction("ToggleSeatCam", function(_actionName, inputState, _input)
		if inputState == Enum.UserInputState.Begin then
			self.SeatCamEnabled = not self.SeatCamEnabled
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.V, Enum.KeyCode.ButtonY)
end

-- Shakes the camera. Bigger numbers shake harder; it dies down by itself.
function CameraServiceClient.Shake(self: CameraServiceClient, amount: number)
	self.ShakeAmount = math.max(self.ShakeAmount, amount)
end

-- Shakes the camera if `boatModel`'s speed changed sharply since last frame.
function CameraServiceClient.ShakeOnImpact(self: CameraServiceClient, boatModel: Model)
	local primaryPart = boatModel.PrimaryPart
	if not primaryPart then
		return
	end
	local velocity = primaryPart.AssemblyLinearVelocity
	local lastVelocity = self.LastBoatVelocity
	if lastVelocity and self.LastBoatModel == boatModel then
		local speedChange = (velocity - lastVelocity).Magnitude
		if speedChange >= CameraConfig.IMPACT_SPEED_CHANGE then
			self:Shake(math.min(CameraConfig.MAX_IMPACT_SHAKE, speedChange * CameraConfig.IMPACT_SHAKE_PER_SPEED))
		end
	end
	self.LastBoatModel = boatModel
	self.LastBoatVelocity = velocity
end

function CameraServiceClient.Update(self: CameraServiceClient, deltaTime: number)
	local camera = workspace.CurrentCamera
	local boatModel, seat = GetRiddenSeat()
	if not self.SeatCamEnabled or not boatModel or not seat then
		if camera.CameraType == Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Custom
		end
		self.SmoothedCFrame = nil
		self.LastBoatModel = nil
		self.LastBoatVelocity = nil
		return
	end
	self:ShakeOnImpact(boatModel)

	local boatPosition = boatModel:GetPivot().Position
	local facing = BoatServiceShared.GetRiderFacing(boatPosition, seat.CFrame)
	local seatPosition = Vector3.new(seat.Position.X, boatPosition.Y, seat.Position.Z)
	local eye = seatPosition - facing * CameraConfig.SEAT_CAM_BACK + Vector3.yAxis * CameraConfig.SEAT_CAM_UP
	local goal = CFrame.lookAt(eye, boatPosition + facing * CameraConfig.SEAT_CAM_LOOK_AHEAD)

	local smoothing = 1 - math.exp(-CameraConfig.SEAT_CAM_SMOOTHING * deltaTime)
	local current = (self.SmoothedCFrame or goal):Lerp(goal, smoothing)
	self.SmoothedCFrame = current

	if self.ShakeAmount > 0 then
		local offsetX = self.Random:NextNumber(-1, 1) * self.ShakeAmount
		local offsetY = self.Random:NextNumber(-1, 1) * self.ShakeAmount
		current *= CFrame.new(offsetX, offsetY, 0)
		self.ShakeAmount *= math.exp(-CameraConfig.SHAKE_DECAY * deltaTime)
	end

	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = current
end

return CameraServiceClient :: CameraServiceClient
]==],
	},
	{
		ParentPath = { "ReplicatedStorage", "Shared", "Services", "CheckpointService" },
		Name = "CheckpointServiceClient",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.CheckpointService.CheckpointServiceClient
--
-- The client half of CheckpointService. Keeps the list of checkpoints this player
-- has unlocked, and passes on checkpoint and finish events, for the UI to use.
-- The teleport menu (UI, to be built) shows CheckpointConfig.CHECKPOINTS, marks the
-- unlocked ones, and calls RequestTeleport.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CheckpointServiceShared = require(ReplicatedStorage.Shared.Services.CheckpointService.CheckpointServiceShared)
local Remotes = require(ReplicatedStorage.Shared.Modules.Core.Remotes)
local Signal = require(ReplicatedStorage.Packages.Signal)

local SERVICE_NAME = CheckpointServiceShared.SERVICE_NAME

local CheckpointServiceClient = {}

type CheckpointServiceClientMembers = {
	UnlockedCheckpointIds: { string },
	UnlockedCheckpointsChanged: Signal.Signal, -- fires (unlockedIds: { string })
	CheckpointReached: Signal.Signal, -- fires (checkpointId: string) when this player's boat reaches a checkpoint
	GameCompleted: Signal.Signal, -- fires () when this player's boat reaches the end
}

export type CheckpointServiceClient = typeof(CheckpointServiceClient) & CheckpointServiceClientMembers

function CheckpointServiceClient.Init(self: CheckpointServiceClient)
	self.UnlockedCheckpointIds = {}
	self.UnlockedCheckpointsChanged = Signal.new()
	self.CheckpointReached = Signal.new()
	self.GameCompleted = Signal.new()

	-- Remotes are waited for in a separate thread so Init never yields.
	task.spawn(function()
		local checkpointReachedRemote = Remotes.WaitForEvent(SERVICE_NAME, CheckpointServiceShared.CHECKPOINT_REACHED)
		checkpointReachedRemote.OnClientEvent:Connect(function(checkpointId: string, unlockedIds: { string })
			self:SetUnlockedCheckpointIds(unlockedIds)
			self.CheckpointReached:Fire(checkpointId)
		end)

		local gameCompletedRemote = Remotes.WaitForEvent(SERVICE_NAME, CheckpointServiceShared.GAME_COMPLETED)
		gameCompletedRemote.OnClientEvent:Connect(function()
			self.GameCompleted:Fire()
		end)

		local requestUnlocked =
			Remotes.WaitForFunction(SERVICE_NAME, CheckpointServiceShared.REQUEST_UNLOCKED_CHECKPOINTS)
		local unlockedIds = requestUnlocked:InvokeServer()
		if type(unlockedIds) == "table" then
			self:SetUnlockedCheckpointIds(unlockedIds)
		end
	end)
end

function CheckpointServiceClient.SetUnlockedCheckpointIds(self: CheckpointServiceClient, unlockedIds: { string })
	self.UnlockedCheckpointIds = unlockedIds
	self.UnlockedCheckpointsChanged:Fire(table.clone(unlockedIds))
end

function CheckpointServiceClient.GetUnlockedCheckpointIds(self: CheckpointServiceClient): { string }
	return table.clone(self.UnlockedCheckpointIds)
end

-- Asks the server to teleport this player to the lobby (CheckpointConfig.LOBBY_ID) or
-- an unlocked checkpoint. Returns whether it worked and, if not, a message to show.
function CheckpointServiceClient.RequestTeleport(self: CheckpointServiceClient, locationId: string): (boolean, string?)
	local remote = Remotes.WaitForFunction(SERVICE_NAME, CheckpointServiceShared.REQUEST_TELEPORT)
	local success, message = remote:InvokeServer(locationId)
	return success == true, if type(message) == "string" then message else nil
end

return CheckpointServiceClient :: CheckpointServiceClient
]==],
	},
	{
		ParentPath = { "ReplicatedStorage", "Shared", "Services", "CheckpointService" },
		Name = "CheckpointServiceShared",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.CheckpointService.CheckpointServiceShared
--
-- Names both halves of CheckpointService agree on.

local CheckpointServiceShared = {
	SERVICE_NAME = "CheckpointService",

	-- Remotes
	REQUEST_TELEPORT = "RequestTeleport", -- RemoteFunction (locationId: string) -> (success: boolean, message: string?)
	REQUEST_UNLOCKED_CHECKPOINTS = "RequestUnlockedCheckpoints", -- RemoteFunction () -> { string } of checkpoint Ids
	CHECKPOINT_REACHED = "CheckpointReached", -- RemoteEvent to a crew member (checkpointId: string, unlockedIds: { string })
	GAME_COMPLETED = "GameCompleted", -- RemoteEvent to a crew member who reached the end
}

return CheckpointServiceShared
]==],
	},
	{
		ParentPath = { "ReplicatedStorage", "Shared", "Services", "DockService" },
		Name = "DockServiceClient",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.DockService.DockServiceClient
--
-- The client half of DockService. When the player uses a dock's SpawnBoatPrompt,
-- DockSelected fires so the boat menu (UI, to be built) can open. The menu then
-- calls RequestSpawnBoat with the size the player picked. The server decides.

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DockServiceShared = require(ReplicatedStorage.Shared.Services.DockService.DockServiceShared)
local Remotes = require(ReplicatedStorage.Shared.Modules.Core.Remotes)
local Signal = require(ReplicatedStorage.Packages.Signal)

local DockServiceClient = {}

type DockServiceClientMembers = {
	SelectedDock: Model?, -- the dock the player last used a prompt on
	DockSelected: Signal.Signal, -- fires (dock: Model)
}

export type DockServiceClient = typeof(DockServiceClient) & DockServiceClientMembers

-- The dock model a prompt belongs to: its nearest Model ancestor inside a Docks folder.
local function FindDockModel(prompt: ProximityPrompt): Model?
	local ancestor = prompt.Parent
	while ancestor do
		local parent = ancestor.Parent
		if ancestor:IsA("Model") and parent and parent.Name == DockServiceShared.DOCKS_FOLDER_NAME then
			return ancestor
		end
		ancestor = parent
	end
	return nil
end

function DockServiceClient.Init(self: DockServiceClient)
	self.SelectedDock = nil
	self.DockSelected = Signal.new()

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt.Name ~= DockServiceShared.SPAWN_BOAT_PROMPT_NAME then
			return
		end
		local dockModel = FindDockModel(prompt)
		if dockModel then
			self.SelectedDock = dockModel
			self.DockSelected:Fire(dockModel)
		end
	end)
end

-- Asks the server to spawn a boat for `seatCount` players at `dock`.
-- Returns whether it worked and, if not, a message to show the player.
function DockServiceClient.RequestSpawnBoat(self: DockServiceClient, dock: Model, seatCount: number): (boolean, string?)
	local remote = Remotes.WaitForFunction(DockServiceShared.SERVICE_NAME, DockServiceShared.REQUEST_SPAWN_BOAT)
	local success, message = remote:InvokeServer(dock, seatCount)
	return success == true, if type(message) == "string" then message else nil
end

return DockServiceClient :: DockServiceClient
]==],
	},
	{
		ParentPath = { "ReplicatedStorage", "Shared", "Services", "DockService" },
		Name = "DockServiceShared",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.DockService.DockServiceShared
--
-- Names both halves of DockService agree on.

local DockServiceShared = {
	SERVICE_NAME = "DockService",
	DOCKS_FOLDER_NAME = "Docks", -- the folder of dock models in each location
	SPAWN_BOAT_PROMPT_NAME = "SpawnBoatPrompt", -- the ProximityPrompt inside each dock model

	-- Remotes
	REQUEST_SPAWN_BOAT = "RequestSpawnBoat", -- RemoteFunction (dock: Model, seatCount: number) -> (success: boolean, message: string?)
}

return DockServiceShared
]==],
	},
	{
		ParentPath = { "ReplicatedStorage", "Shared", "Services", "FartService" },
		Name = "FartPhysics",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.FartService.FartPhysics
--
-- The rules for what farting does. Pure math, shared by the server (which moves the
-- boat) and the client (which plays effects that match).
--
-- Strength: a fart pushes with a set acceleration that grows by a set amount every
-- second it has built up, up to a maximum (all in FartConfig). How far it has built up
-- is its "ramp time": it rises while the player farts, in any direction, and falls
-- RAMP_DECAY times as fast once they stop.
--
-- Direction: riders face the middle of the boat. "Straight" pushes the boat away from
-- the rider. "Left" turns the boat left, the same way from every seat, plus a small
-- sideways push. So with seats spread around the ring, everyone farting Straight
-- cancels out, and everyone farting Left spins the boat on the spot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoatServiceShared = require(ReplicatedStorage.Shared.Services.BoatService.BoatServiceShared)
local FartConfig = require(ReplicatedStorage.Shared.Modules.Game.FartConfig)

export type Direction = "Left" | "Straight" | "Right"

-- Seconds of farting it takes to build up to full strength, pushing and turning both.
local function GetRampDuration(startAcceleration: number, gain: number, maxAcceleration: number): number
	return if gain > 0 then math.max(0, (maxAcceleration - startAcceleration) / gain) else 0
end

local FartPhysics = {
	MAX_RAMP_TIME = math.max(
		GetRampDuration(
			FartConfig.STRAIGHT_ACCELERATION,
			FartConfig.STRAIGHT_ACCELERATION_GAIN,
			FartConfig.MAX_STRAIGHT_ACCELERATION
		),
		GetRampDuration(
			FartConfig.TURN_ACCELERATION,
			FartConfig.TURN_ACCELERATION_GAIN,
			FartConfig.MAX_TURN_ACCELERATION
		)
	),
}

function FartPhysics.IsDirection(value: unknown): boolean
	return value == "Left" or value == "Straight" or value == "Right"
end

-- A player's ramp time `deltaTime` seconds later: built up while `isFarting`, fading otherwise.
function FartPhysics.UpdateRampTime(rampTime: number, isFarting: boolean, deltaTime: number): number
	if isFarting then
		return math.min(FartPhysics.MAX_RAMP_TIME, rampTime + deltaTime)
	end
	return math.max(0, rampTime - deltaTime * FartConfig.RAMP_DECAY)
end

-- Studs/s² of push after `rampTime` seconds of build-up.
function FartPhysics.GetStraightAcceleration(rampTime: number): number
	return math.min(
		FartConfig.MAX_STRAIGHT_ACCELERATION,
		FartConfig.STRAIGHT_ACCELERATION + FartConfig.STRAIGHT_ACCELERATION_GAIN * rampTime
	)
end

-- Rad/s² of turn after `rampTime` seconds of build-up.
function FartPhysics.GetTurnAcceleration(rampTime: number): number
	return math.min(
		FartConfig.MAX_TURN_ACCELERATION,
		FartConfig.TURN_ACCELERATION + FartConfig.TURN_ACCELERATION_GAIN * rampTime
	)
end

-- How far a fart has built up: 0 at its starting strength, 1 at full strength. Used to
-- grow the effects.
function FartPhysics.GetRampProgress(rampTime: number): number
	if FartPhysics.MAX_RAMP_TIME <= 0 then
		return 1
	end
	return math.clamp(rampTime / FartPhysics.MAX_RAMP_TIME, 0, 1)
end

-- How fast a fart from `seatCFrame` speeds the boat up (studs/s²) and turns it (rad/s²)
-- after `rampTime` seconds of build-up. A positive turn is a LEFT turn (counter-clockwise
-- seen from above). This is the raw fart; the boat's size scales what it does
-- (BoatConfig.HANDLING).
function FartPhysics.GetThrust(
	boatPosition: Vector3,
	seatCFrame: CFrame,
	direction: Direction,
	rampTime: number
): (Vector3, number)
	local facing = BoatServiceShared.GetRiderFacing(boatPosition, seatCFrame)
	local right = facing:Cross(Vector3.yAxis) -- the rider's right hand
	local straightAcceleration = FartPhysics.GetStraightAcceleration(rampTime)

	if direction == "Straight" then
		-- Gas goes out behind the rider, so the boat moves away from them.
		return facing * straightAcceleration, 0
	end
	local sidePush = straightAcceleration * FartConfig.SIDE_PUSH_FRACTION
	local turnAcceleration = FartPhysics.GetTurnAcceleration(rampTime)
	if direction == "Left" then
		-- Like an outboard motor: shove our side right so the far side swings left.
		return right * sidePush, turnAcceleration
	else
		return -right * sidePush, -turnAcceleration
	end
end

return FartPhysics
]==],
	},
	{
		ParentPath = { "ReplicatedStorage", "Shared", "Services", "FartService" },
		Name = "FartServiceClient",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.FartService.FartServiceClient
--
-- The client half of FartService: turns key and controller presses into farting, and
-- plays everyone's fart effects. Hold a key to keep farting; its push builds up the
-- longer you keep farting (FartPhysics), and letting go stops. If you hold two keys,
-- the one you pressed last wins, and switching keeps the fart going at the strength
-- it has built up. Your own fart starts the moment you press, so it feels instant;
-- the server still decides whether the boat moves, and tells this client to stop if
-- it says no.
--
--   Fart Left       A, Left arrow, Q, or LB
--   Fart Straight   W, Up arrow, Space, or RT
--   Fart Right      D, Right arrow, E, or RB
--
-- On-screen buttons for touch devices (UI, to be built) call PressFart on press and
-- ReleaseFart on release. A gas meter reads the player's "Gas" attribute.
--
-- Asset contract:
--   ReplicatedStorage.Assets.VFX.FartCloud      ParticleEmitter: the gas cloud. While farting, its
--                                               Rate and Speed grow with the fart.
--   ReplicatedStorage.Assets.Sounds.Farts       Folder of Sounds; each fart loops one at random

local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BoatServiceShared = require(ReplicatedStorage.Shared.Services.BoatService.BoatServiceShared)
local FartConfig = require(ReplicatedStorage.Shared.Modules.Game.FartConfig)
local FartPhysics = require(ReplicatedStorage.Shared.Services.FartService.FartPhysics)
local FartServiceShared = require(ReplicatedStorage.Shared.Services.FartService.FartServiceShared)
local Remotes = require(ReplicatedStorage.Shared.Modules.Core.Remotes)
local Signal = require(ReplicatedStorage.Packages.Signal)

local SERVICE_NAME = FartServiceShared.SERVICE_NAME
local BUTT_ATTACHMENT_NAME = "FartButt"
local FART_CLOUD_NAME = "FartCloud"
local FART_SOUNDS_NAME = "Farts"

local ACTION_DIRECTIONS: { [string]: FartPhysics.Direction } = {
	FartLeft = "Left",
	FartStraight = "Straight",
	FartRight = "Right",
}

local localPlayer = Players.LocalPlayer

-- One player's fart that's happening right now, and its effects.
type Stream = {
	Direction: string,
	Emitter: ParticleEmitter?,
	Sound: Sound?,
	BasePitch: number,
}

local FartServiceClient = {}

type FartServiceClientMembers = {
	HeldDirections: { FartPhysics.Direction }, -- fart keys the local player is holding, in the order pressed
	LocalDirection: FartPhysics.Direction?, -- the direction the local player is farting, if they are
	Streams: { [Player]: Stream }, -- everyone farting right now, the local player included
	RampTimes: { [Player]: number }, -- how far each player's fart has built up, the same way the server works it out
	Random: Random,
	FartCloudTemplate: ParticleEmitter?,
	FartSounds: { Sound },
	RequestStartFartRemote: RemoteEvent?, -- set once the server has created it
	RequestStopFartRemote: RemoteEvent?,
	FartStarted: Signal.Signal, -- fires (direction: string) when the local player starts or switches farting
	FartStopped: Signal.Signal, -- fires () when the local player stops farting
}

export type FartServiceClient = typeof(FartServiceClient) & FartServiceClientMembers

-- True while the local player sits in a boat that's on the river.
local function IsRiding(): boolean
	local character = localPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local seat = if humanoid then humanoid.SeatPart else nil
	local boatModel = if seat then BoatServiceShared.GetBoatModelFromPart(seat) else nil
	return boatModel ~= nil and boatModel:GetAttribute(BoatServiceShared.STATE_ATTRIBUTE) == "Launched"
end

local function GetLocalGas(): number
	local gas = localPlayer:GetAttribute(FartServiceShared.GAS_ATTRIBUTE)
	return if typeof(gas) == "number" then gas else 0
end

local function FindAssets(): (ParticleEmitter?, { Sound })
	local assets = ReplicatedStorage.Assets
	local vfxFolder = assets:FindFirstChild("VFX")
	local fartCloud = if vfxFolder then vfxFolder:FindFirstChild(FART_CLOUD_NAME) else nil
	if not fartCloud or not fartCloud:IsA("ParticleEmitter") then
		warn(`Asset missing: ReplicatedStorage.Assets.VFX.{FART_CLOUD_NAME} (a ParticleEmitter). Farts won't show.`)
		fartCloud = nil
	end

	local fartSounds = {}
	local soundsFolder = assets:FindFirstChild("Sounds")
	local fartSoundsFolder = if soundsFolder then soundsFolder:FindFirstChild(FART_SOUNDS_NAME) else nil
	if fartSoundsFolder then
		for _, child in fartSoundsFolder:GetChildren() do
			if child:IsA("Sound") then
				table.insert(fartSounds, child)
			end
		end
	end
	if #fartSounds == 0 then
		warn(`Asset missing: Sounds in ReplicatedStorage.Assets.Sounds.{FART_SOUNDS_NAME}. Farts will be silent.`)
	end
	return fartCloud :: ParticleEmitter?, fartSounds
end

function FartServiceClient.Init(self: FartServiceClient)
	self.HeldDirections = {}
	self.LocalDirection = nil
	self.Streams = {}
	self.RampTimes = {}
	self.Random = Random.new()
	self.RequestStartFartRemote = nil
	self.RequestStopFartRemote = nil
	self.FartStarted = Signal.new()
	self.FartStopped = Signal.new()
	self.FartCloudTemplate, self.FartSounds = FindAssets()

	local function OnAction(actionName: string, inputState: Enum.UserInputState, _input: InputObject)
		local direction: FartPhysics.Direction? = ACTION_DIRECTIONS[actionName]
		if not direction then
			return Enum.ContextActionResult.Pass
		end
		if inputState == Enum.UserInputState.Begin then
			if not IsRiding() then
				-- Not on the river: let the keys do their normal job (like walking).
				return Enum.ContextActionResult.Pass
			end
			self:PressFart(direction)
			return Enum.ContextActionResult.Sink
		end
		-- Letting go: only take it if the press was a fart, so walking keys still let go normally.
		if not table.find(self.HeldDirections, direction) then
			return Enum.ContextActionResult.Pass
		end
		self:ReleaseFart(direction)
		return Enum.ContextActionResult.Sink
	end
	ContextActionService:BindAction(
		"FartLeft",
		OnAction,
		false,
		Enum.KeyCode.A,
		Enum.KeyCode.Left,
		Enum.KeyCode.Q,
		Enum.KeyCode.ButtonL1
	)
	ContextActionService:BindAction(
		"FartStraight",
		OnAction,
		false,
		Enum.KeyCode.W,
		Enum.KeyCode.Up,
		Enum.KeyCode.Space,
		Enum.KeyCode.ButtonR2
	)
	ContextActionService:BindAction(
		"FartRight",
		OnAction,
		false,
		Enum.KeyCode.D,
		Enum.KeyCode.Right,
		Enum.KeyCode.E,
		Enum.KeyCode.ButtonR1
	)

	RunService.RenderStepped:Connect(function(deltaTime)
		self:Update(deltaTime)
	end)

	-- Remotes are waited for in a separate thread so Init never yields.
	task.spawn(function()
		self.RequestStartFartRemote = Remotes.WaitForEvent(SERVICE_NAME, FartServiceShared.REQUEST_START_FART)
		self.RequestStopFartRemote = Remotes.WaitForEvent(SERVICE_NAME, FartServiceShared.REQUEST_STOP_FART)
		Remotes.WaitForEvent(SERVICE_NAME, FartServiceShared.PLAY_FART).OnClientEvent
			:Connect(function(farter: Player?, direction: string)
				if farter then -- nil if they left before this arrived
					self:StartStream(farter, direction)
				end
			end)
		Remotes.WaitForEvent(SERVICE_NAME, FartServiceShared.STOP_FART).OnClientEvent:Connect(function(farter: Player?)
			if farter == localPlayer then
				-- The server stopped our fart (out of gas, or we left the boat).
				table.clear(self.HeldDirections)
				self:SetLocalDirection(nil)
			elseif farter then
				self:StopStream(farter)
			end
		end)
	end)
end

-- A fart key (or on-screen button) went down.
function FartServiceClient.PressFart(self: FartServiceClient, direction: FartPhysics.Direction)
	local index = table.find(self.HeldDirections, direction)
	if index then
		table.remove(self.HeldDirections, index)
	end
	table.insert(self.HeldDirections, direction)
	if GetLocalGas() < FartConfig.MIN_GAS_TO_START then
		self:PlayDudEffect(localPlayer)
		return
	end
	self:SetLocalDirection(direction)
end

-- A fart key (or on-screen button) was let go: switch to another held key, or stop.
function FartServiceClient.ReleaseFart(self: FartServiceClient, direction: FartPhysics.Direction)
	local index = table.find(self.HeldDirections, direction)
	if index then
		table.remove(self.HeldDirections, index)
	end
	if self.LocalDirection == direction then
		self:SetLocalDirection(self.HeldDirections[#self.HeldDirections])
	end
end

-- Starts, switches or (with nil) stops the local player's fart, and tells the server.
function FartServiceClient.SetLocalDirection(self: FartServiceClient, direction: FartPhysics.Direction?)
	if direction == self.LocalDirection then
		return
	end
	local startRemote = self.RequestStartFartRemote
	local stopRemote = self.RequestStopFartRemote
	if not startRemote or not stopRemote then
		return -- the server hasn't set up yet
	end

	self.LocalDirection = direction
	if direction then
		self:StartStream(localPlayer, direction)
		startRemote:FireServer(direction)
		self.FartStarted:Fire(direction)
	else
		self:StopStream(localPlayer)
		stopRemote:FireServer()
		self.FartStopped:Fire()
	end
end

-- Every frame: build up (or fade) everyone's fart strength, grow each fart's effects
-- with it, and stop the local fart if the player ran out of gas or isn't riding any more.
function FartServiceClient.Update(self: FartServiceClient, deltaTime: number)
	if self.LocalDirection and (GetLocalGas() <= 0 or not IsRiding()) then
		table.clear(self.HeldDirections)
		self:SetLocalDirection(nil)
	end

	for player, rampTime in self.RampTimes do
		if not self.Streams[player] then
			local fadedRampTime = FartPhysics.UpdateRampTime(rampTime, false, deltaTime)
			if fadedRampTime > 0 and player.Parent then
				self.RampTimes[player] = fadedRampTime
			else
				self.RampTimes[player] = nil
			end
		end
	end
	for player, stream in self.Streams do
		if not player.Parent then
			self:StopStream(player)
			self.RampTimes[player] = nil
			continue
		end
		local rampTime = FartPhysics.UpdateRampTime(self.RampTimes[player] or 0, true, deltaTime)
		self.RampTimes[player] = rampTime
		local progress = FartPhysics.GetRampProgress(rampTime)
		local emitter = stream.Emitter
		local template = self.FartCloudTemplate
		if emitter and template then
			local speedMultiplier = 1 + (FartConfig.MAX_PARTICLE_SPEED_MULTIPLIER - 1) * progress
			emitter.Rate = FartConfig.MIN_PARTICLE_RATE
				+ (FartConfig.MAX_PARTICLE_RATE - FartConfig.MIN_PARTICLE_RATE) * progress
			emitter.Speed = NumberRange.new(template.Speed.Min * speedMultiplier, template.Speed.Max * speedMultiplier)
		end
		local sound = stream.Sound
		if sound then
			sound.PlaybackSpeed = stream.BasePitch * (1 + FartConfig.PITCH_RISE * progress)
			sound.Volume = FartConfig.STREAM_VOLUME
				+ (FartConfig.MAX_STREAM_VOLUME - FartConfig.STREAM_VOLUME) * progress
		end
	end
end

-- The attachment and emitter at a player's butt, made the first time they fart.
function FartServiceClient.GetButt(self: FartServiceClient, player: Player): (Attachment?, ParticleEmitter?)
	local character = player.Character
	local rootPart = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not rootPart or not rootPart:IsA("BasePart") then
		return nil, nil
	end

	local existing = rootPart:FindFirstChild(BUTT_ATTACHMENT_NAME)
	if existing and existing:IsA("Attachment") then
		return existing, existing:FindFirstChildOfClass("ParticleEmitter")
	end

	local butt = Instance.new("Attachment")
	butt.Name = BUTT_ATTACHMENT_NAME
	butt.CFrame = FartConfig.BUTT_OFFSET
	butt.Parent = rootPart
	local emitter: ParticleEmitter? = nil
	local template = self.FartCloudTemplate
	if template then
		local newEmitter = template:Clone()
		newEmitter.Enabled = false
		newEmitter.Parent = butt
		emitter = newEmitter
	end
	return butt, emitter
end

-- Starts `player`'s fart effects (a steady gas cloud and a looping sound), or points
-- them the new way if they're switching direction.
function FartServiceClient.StartStream(self: FartServiceClient, player: Player, direction: string)
	local butt, emitter = self:GetButt(player)
	if not butt then
		return
	end
	-- Gas comes out behind the rider, angled to the side on a Left or Right fart.
	local gasAngle = if direction == "Left"
		then -FartConfig.GAS_ANGLE
		elseif direction == "Right" then FartConfig.GAS_ANGLE
		else 0
	butt.CFrame = FartConfig.BUTT_OFFSET * CFrame.Angles(0, gasAngle, 0)
	local existingStream = self.Streams[player]
	if existingStream then
		-- Switching: the same fart keeps going (same sound, same strength), just aimed anew.
		existingStream.Direction = direction
		return
	end
	if emitter then
		emitter.Enabled = true
	end

	local sound: Sound? = nil
	local basePitch = self.Random:NextNumber(FartConfig.MIN_PITCH, FartConfig.MAX_PITCH)
	if #self.FartSounds > 0 then
		local newSound = self.FartSounds[self.Random:NextInteger(1, #self.FartSounds)]:Clone()
		newSound.Looped = true
		newSound.Volume = FartConfig.STREAM_VOLUME
		newSound.PlaybackSpeed = basePitch
		newSound.Parent = butt
		newSound:Play()
		sound = newSound
	end

	self.Streams[player] = {
		Direction = direction,
		Emitter = emitter,
		Sound = sound,
		BasePitch = basePitch,
	}
end

function FartServiceClient.StopStream(self: FartServiceClient, player: Player)
	local stream = self.Streams[player]
	if not stream then
		return
	end
	self.Streams[player] = nil
	local emitter = stream.Emitter
	if emitter then
		emitter.Enabled = false
	end
	local sound = stream.Sound
	if sound then
		sound:Stop()
		sound:Destroy()
	end
end

-- Not enough gas: a sad little puff.
function FartServiceClient.PlayDudEffect(self: FartServiceClient, player: Player)
	local butt, emitter = self:GetButt(player)
	if not butt then
		return
	end
	if self.Streams[player] then
		return -- already farting; the stream's effects are showing
	end
	butt.CFrame = FartConfig.BUTT_OFFSET
	local template = self.FartCloudTemplate
	if emitter and template then
		emitter.Speed = template.Speed
		emitter:Emit(FartConfig.DUD_PARTICLES)
	end
	if #self.FartSounds > 0 then
		local sound = self.FartSounds[self.Random:NextInteger(1, #self.FartSounds)]:Clone()
		sound.Volume = FartConfig.DUD_VOLUME
		sound.PlaybackSpeed = self.Random:NextNumber(FartConfig.MIN_PITCH, FartConfig.MAX_PITCH) * FartConfig.DUD_PITCH
		sound.Parent = butt
		sound:Play()
		Debris:AddItem(sound, FartConfig.DUD_SOUND_LIFETIME)
	end
end

return FartServiceClient :: FartServiceClient
]==],
	},
	{
		ParentPath = { "ReplicatedStorage", "Shared", "Services", "FartService" },
		Name = "FartServiceShared",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.FartService.FartServiceShared
--
-- Names both halves of FartService agree on.

local FartServiceShared = {
	SERVICE_NAME = "FartService",
	GAS_ATTRIBUTE = "Gas", -- on each Player: their current gas, a whole number from 0 to FartConfig.GAS_MAX

	-- Remotes
	REQUEST_START_FART = "RequestStartFart", -- RemoteEvent client -> server (direction: string): start (or switch) farting
	REQUEST_STOP_FART = "RequestStopFart", -- RemoteEvent client -> server (): stop farting
	PLAY_FART = "PlayFart", -- RemoteEvent server -> clients (farter: Player, direction: string): farter started farting
	STOP_FART = "StopFart", -- RemoteEvent server -> clients (farter: Player): farter stopped farting
}

return FartServiceShared
]==],
	},
}

local createdPaths: { string } = {}
local updatedPaths: { string } = {}
local skippedPaths: { string } = {}

-- Finds the instance at `path` (service first), creating missing Folders along the way.
local function GetOrCreatePath(path: { string }): Instance
	local current: Instance = game:GetService(path[1])
	for index = 2, #path do
		local child = current:FindFirstChild(path[index])
		if not child then
			child = Instance.new("Folder")
			child.Name = path[index]
			child.Parent = current
			table.insert(createdPaths, child:GetFullName())
		end
		current = child
	end
	return current
end

local recording = ChangeHistoryService:TryBeginRecording("Install game code")

-- Scripts first, shallowest first, so a ModuleScript with children (like UI) exists
-- before any folder inside it.
for _, scriptInfo in SCRIPTS do
	local parent = GetOrCreatePath(scriptInfo.ParentPath)
	local existing = parent:FindFirstChild(scriptInfo.Name)
	if existing and existing.ClassName ~= scriptInfo.ClassName then
		local existingPath = existing:GetFullName()
		warn(`{existingPath} is a {existing.ClassName}, expected a {scriptInfo.ClassName}. Skipped it.`)
		table.insert(skippedPaths, existingPath)
	elseif existing then
		if (existing :: any).Source ~= scriptInfo.Source then
			(existing :: any).Source = scriptInfo.Source
			table.insert(updatedPaths, existing:GetFullName())
		end
	else
		local newScript = Instance.new(scriptInfo.ClassName)
		newScript.Name = scriptInfo.Name;
		(newScript :: any).Source = scriptInfo.Source
		newScript.Parent = parent
		table.insert(createdPaths, newScript:GetFullName())
	end
end

for _, folderPath in FOLDERS do
	GetOrCreatePath(folderPath)
end

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end

print(`Install done: {#createdPaths} created, {#updatedPaths} updated, {#skippedPaths} skipped.`)
for _, path in createdPaths do
	print(`  + {path}`)
end
for _, path in updatedPaths do
	print(`  ~ {path}`)
end
