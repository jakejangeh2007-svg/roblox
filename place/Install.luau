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
-- On the river the server owns its physics: WaterService keeps it afloat and
-- FartService pushes it.
--
-- Template contract (a Model built by hand, with no scripts inside):
--   PrimaryPart   must be set: a flat part in the middle of the boat, at the height the
--                 water should come up to, with its top face pointing up. It can be invisible.
--   Welds         every other part, Seats included, welded to the PrimaryPart with
--                 WeldConstraints (directly or through other welded parts).
--   Seats         one Seat per player. The number of Seats must match the size the
--                 template is listed under in BoatConfig.TEMPLATE_NAMES. Put them around
--                 the edge facing the middle. A one-seat boat can have its seat in the
--                 middle, facing forward.
--
-- States: Docked -> Launched -> Destroyed. The model's State, LeaderUserId and
-- DepartureTime attributes (see BoatServiceShared) mirror this for clients.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoatConfig = require(ReplicatedStorage.Shared.Modules.Game.BoatConfig)
local BoatServiceShared = require(ReplicatedStorage.Shared.Services.BoatService.BoatServiceShared)
local Signal = require(ReplicatedStorage.Packages.Signal)

local Boat = {}
Boat.__index = Boat

type BoatMembers = {
	Model: Model,
	Leader: Player, -- the party leader: who spawned it, or who took over after they left
	Seats: { Seat },
	State: BoatServiceShared.BoatState,
	Frozen: boolean, -- held still in mid-air after falling off the river, until it's removed
	Crew: { Player }, -- who was aboard at launch, minus anyone who has left since
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
	self:StartFloating()
end

-- Hands the boat over to physics: unanchors it, keeps it upright (it can still spin
-- freely) and makes the server simulate it.
function Boat.StartFloating(self: Boat)
	local primaryPart = self.Model.PrimaryPart
	if not primaryPart then
		return
	end

	local uprightAttachment = Instance.new("Attachment")
	uprightAttachment.Name = "UprightAttachment"
	-- The attachment's primary axis (its X axis) points along the boat's up direction.
	uprightAttachment.CFrame = CFrame.fromMatrix(Vector3.zero, Vector3.yAxis, Vector3.xAxis)
	uprightAttachment.Parent = primaryPart

	local upright = Instance.new("AlignOrientation")
	upright.Name = "Upright"
	upright.Mode = Enum.OrientationAlignmentMode.OneAttachment
	upright.AlignType = Enum.AlignType.PrimaryAxisParallel
	upright.PrimaryAxis = Vector3.yAxis
	upright.Attachment0 = uprightAttachment
	upright.MaxTorque = math.huge
	upright.Responsiveness = BoatConfig.UPRIGHT_RESPONSIVENESS
	upright.Parent = primaryPart

	primaryPart.Anchored = false
	self:ClaimNetworkOwnership()
	primaryPart.AssemblyLinearVelocity = Vector3.zero
	primaryPart.AssemblyAngularVelocity = Vector3.zero
end

-- Makes sure the server simulates the boat. Seated players can otherwise end up owning
-- it, so BoatService calls this again every CLEANUP_INTERVAL.
function Boat.ClaimNetworkOwnership(self: Boat)
	local primaryPart = self.Model.PrimaryPart
	if not primaryPart or not primaryPart:CanSetNetworkOwnership() then
		return
	end
	if primaryPart:GetNetworkOwnershipAuto() or primaryPart:GetNetworkOwner() ~= nil then
		primaryPart:SetNetworkOwner(nil)
	end
end

-- Adds to the boat's speed (studs/s) and turn speed (rad/s, positive turns left).
function Boat.AddVelocity(self: Boat, push: Vector3, spin: number)
	local primaryPart = self.Model.PrimaryPart
	if not primaryPart or not self:IsFloating() then
		return
	end
	primaryPart.AssemblyLinearVelocity += push
	primaryPart.AssemblyAngularVelocity += Vector3.yAxis * spin
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

	-- Boats pass through each other.
	local collisionGroup = BoatServiceShared.COLLISION_GROUP
	if not PhysicsService:IsCollisionGroupRegistered(collisionGroup) then
		PhysicsService:RegisterCollisionGroup(collisionGroup)
	end
	PhysicsService:CollisionGroupSetCollidable(collisionGroup, collisionGroup, false)

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

-- Forgets boats that were destroyed, and makes sure the server still simulates every
-- boat on the river.
function BoatServiceServer.CleanUp(self: BoatServiceServer)
	for index = #self.Boats, 1, -1 do
		local boat = self.Boats[index]
		if boat.State == "Destroyed" then
			table.remove(self.Boats, index)
		elseif boat:IsFloating() then
			boat:ClaimNetworkOwnership()
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
-- stop); this checks they're riding a boat on the river and have gas, then pushes
-- their boat every frame until they stop, run out of gas or leave the boat. Power
-- grows the longer they keep farting (FartPhysics.GetPower). Gas drains at a flat
-- rate while farting and refills while not. Other players are told when someone
-- starts or stops, so they can show it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local BoatConfig = require(ReplicatedStorage.Shared.Modules.Game.BoatConfig)
local BoatServiceServer = require(ServerScriptService.Services.BoatService.BoatServiceServer)
local FartConfig = require(ReplicatedStorage.Shared.Modules.Game.FartConfig)
local FartPhysics = require(ReplicatedStorage.Shared.Services.FartService.FartPhysics)
local FartServiceShared = require(ReplicatedStorage.Shared.Services.FartService.FartServiceShared)
local Remotes = require(ReplicatedStorage.Shared.Modules.Core.Remotes)

local SERVICE_NAME = FartServiceShared.SERVICE_NAME

type Stream = {
	Direction: FartPhysics.Direction,
	StartedAt: number, -- os.clock() when this fart started, for its power
}

local FartServiceServer = {}

type FartServiceServerMembers = {
	Gas: { [Player]: number },
	Streams: { [Player]: Stream }, -- everyone farting right now
	LastStartTimes: { [Player]: number },
	PlayFartRemote: RemoteEvent,
	StopFartRemote: RemoteEvent,
}

export type FartServiceServer = typeof(FartServiceServer) & FartServiceServerMembers

function FartServiceServer.Init(self: FartServiceServer)
	self.Gas = {}
	self.Streams = {}
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
function FartServiceServer.HandleStartRequest(self: FartServiceServer, player: Player, direction: unknown)
	if not FartPhysics.IsDirection(direction) then
		return
	end
	local current = self.Streams[player]
	if current and current.Direction == direction then
		return
	end
	local now = os.clock()
	local lastStartTime = self.LastStartTimes[player]
	if lastStartTime and now - lastStartTime < FartConfig.REQUEST_COOLDOWN then
		return
	end
	local boat = BoatServiceServer:GetLaunchedBoatOf(player)
	if not boat or not boat:IsFloating() or not boat:GetSeatOf(player) then
		return
	end
	if (self.Gas[player] or 0) < FartConfig.MIN_GAS_TO_START then
		return
	end

	self.LastStartTimes[player] = now
	self.Streams[player] = { Direction = direction :: FartPhysics.Direction, StartedAt = now }
	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer ~= player then
			self.PlayFartRemote:FireClient(otherPlayer, player, direction)
		end
	end
end

-- Ends `player`'s fart. `notifyFarter` also tells the farter, for when the server
-- stops it (out of gas, left the boat) rather than the farter letting go.
function FartServiceServer.StopStream(self: FartServiceServer, player: Player, notifyFarter: boolean)
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

function FartServiceServer.Update(self: FartServiceServer, deltaTime: number)
	local now = os.clock()
	for player, stream in self.Streams do
		local boat = BoatServiceServer:GetLaunchedBoatOf(player)
		local seat = if boat then boat:GetSeatOf(player) else nil
		local gas = self.Gas[player] or 0
		if not boat or not seat or not boat:IsFloating() or gas <= 0 then
			self:StopStream(player, true)
			continue
		end

		local power = FartPhysics.GetPower(now - stream.StartedAt)
		local thrust, spin = FartPhysics.GetThrust(boat:GetPosition(), seat.CFrame, stream.Direction, power)
		local seatCount = #boat.Seats
		thrust *= BoatConfig.PUSH_SCALES[seatCount] or 1
		spin *= BoatConfig.SPIN_SCALES[seatCount] or 1
		boat:AddVelocity(thrust * deltaTime, spin * deltaTime)
		self:SetGas(player, math.max(0, gas - FartConfig.GAS_DRAIN * deltaTime))
	end

	for player, gas in self.Gas do
		if not self.Streams[player] and gas < FartConfig.GAS_MAX then
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

	-- Multiplies every fart push and turn, by boat size. Bigger boats are heavier to steer.
	PUSH_SCALES = {
		[1] = 1.2,
		[2] = 1.1,
		[3] = 1.05,
		[4] = 1,
		[5] = 0.9,
		[6] = 0.8,
	} :: { [number]: number },
	SPIN_SCALES = {
		[1] = 1.5,
		[2] = 1.2,
		[3] = 1.1,
		[4] = 1,
		[5] = 0.85,
		[6] = 0.7,
	} :: { [number]: number },

	-- Joining
	JOIN_TIME = 30, -- seconds players have to get in after the party leader spawns a boat
	LAUNCH_DELAY = 3, -- countdown (seconds) once every seat is taken or the leader starts the run early
	JOIN_DISTANCE = 40, -- how close (studs) a player must be to a boat to ask to join it
	REQUEST_COOLDOWN = 1, -- seconds a player has to wait between join or start requests
	CLEANUP_INTERVAL = 1, -- seconds between checks for boats to remove (also re-claims boat physics for the server)
	WIPE_DELAY = 1.5, -- seconds a boat that fell off the river hangs frozen before its crew respawns

	UPRIGHT_RESPONSIVENESS = 25, -- how quickly a tipped boat rights itself
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
	-- Push. Holding a fart key farts nonstop. Power starts at MIN_POWER and grows to
	-- MAX_POWER over POWER_RAMP_TIME seconds of farting; letting go resets it.
	THRUST = 8, -- studs/s² a Straight fart speeds the boat up by, at power 1
	SIDE_THRUST = 0.45, -- sideways push of a Left/Right fart, as a fraction of THRUST
	SPIN_THRUST = 0.7, -- rad/s² a Left/Right fart turns the boat by, at power 1
	MIN_POWER = 1,
	MAX_POWER = 2.5,
	POWER_RAMP_TIME = 3, -- seconds of nonstop farting to reach MAX_POWER

	-- Gas meter (each player's is in their "Gas" attribute)
	GAS_MAX = 100,
	GAS_DRAIN = 10, -- per second while farting, the same at any power: a full tank lasts 10 seconds
	GAS_REGEN = 15, -- per second while not farting
	MIN_GAS_TO_START = 5, -- below this, pressing a fart key just gives a sad little puff
	REQUEST_COOLDOWN = 0.1, -- seconds the server waits between accepting start requests from one player

	-- Effects
	BUTT_OFFSET = CFrame.new(0, -1, 0.6), -- where gas comes out, relative to the HumanoidRootPart
	GAS_ANGLE = math.rad(45), -- how far left or right of straight back the gas comes out on a Left/Right fart
	STREAM_PARTICLE_RATE = 25, -- particles per second while farting, multiplied by power
	DUD_PARTICLES = 3, -- the puff when there isn't enough gas
	STREAM_VOLUME = 0.5, -- sound volume at MIN_POWER...
	MAX_STREAM_VOLUME = 1, -- ...rising to this at MAX_POWER
	MIN_PITCH = 0.85, -- every fart picks a random starting pitch between these
	MAX_PITCH = 1.15,
	PITCH_RISE_PER_POWER = 0.15, -- the pitch rises by this much for each point of power above MIN_POWER
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

local WaterConfig = {
	WATER_DRAG = 0.9, -- how fast boats slow down
	SPIN_DRAG = 1.6, -- how fast spinning stops
	TILT_DRAG = 4, -- how fast wobbling stops

	FLOAT_HEIGHT = 0, -- how far above the water surface a boat's PrimaryPart sits
	FLOAT_STIFFNESS = 60, -- how strongly boats snap onto the surface
	FLOAT_DAMPING = 8, -- how quickly bobbing stops
	WATER_CHECK_ABOVE = 4, -- boats look for water from this far above their PrimaryPart...
	WATER_CHECK_BELOW = 8, -- ...down to this far below it

	FALL_DISTANCE = 30, -- a boat this far below the last water it floated on has fallen off the river

	-- Water parts named one of these flow toward their front face at this many studs/s.
	-- Any other water part is still water.
	CURRENT_SPEEDS = {
		Current = 4,
		Rapids = 8,
	} :: { [string]: number },
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

function CameraServiceClient.Update(self: CameraServiceClient, deltaTime: number)
	local camera = workspace.CurrentCamera
	local boatModel, seat = GetRiddenSeat()
	if not self.SeatCamEnabled or not boatModel or not seat then
		if camera.CameraType == Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Custom
		end
		self.SmoothedCFrame = nil
		return
	end

	local boatPosition = boatModel:GetPivot().Position
	local facing = BoatServiceShared.GetRiderFacing(boatPosition, seat.CFrame)
	local eye = seat.Position - facing * CameraConfig.SEAT_CAM_BACK + Vector3.yAxis * CameraConfig.SEAT_CAM_UP
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

-- A fart's power after `fartingTime` seconds of nonstop farting: MIN_POWER at the
-- start, growing evenly to MAX_POWER after POWER_RAMP_TIME.
function FartPhysics.GetPower(fartingTime: number): number
	local progress = math.clamp(fartingTime / FartConfig.POWER_RAMP_TIME, 0, 1)
	return FartConfig.MIN_POWER + (FartConfig.MAX_POWER - FartConfig.MIN_POWER) * progress
end

-- How fast a fart from `seatCFrame` speeds the boat up (studs/s²) and turns it
-- (rad/s²) at `power`. A positive turn is a LEFT turn (counter-clockwise seen from above).
-- Multiply both by the frame's time to get the change for that frame.
function FartPhysics.GetThrust(
	boatPosition: Vector3,
	seatCFrame: CFrame,
	direction: Direction,
	power: number
): (Vector3, number)
	local facing = BoatServiceShared.GetRiderFacing(boatPosition, seatCFrame)
	local right = facing:Cross(Vector3.yAxis) -- the rider's right hand

	if direction == "Straight" then
		-- Gas goes out behind the rider, so the boat moves away from them.
		return facing * FartConfig.THRUST * power, 0
	elseif direction == "Left" then
		-- Like an outboard motor: shove our side right so the far side swings left.
		return right * FartConfig.THRUST * FartConfig.SIDE_THRUST * power, FartConfig.SPIN_THRUST * power
	else
		return -right * FartConfig.THRUST * FartConfig.SIDE_THRUST * power, -FartConfig.SPIN_THRUST * power
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
-- plays everyone's fart effects. Hold a key to keep farting; its power grows the
-- longer you hold it (FartPhysics.GetPower), and letting go stops. If you hold two
-- keys, the one you pressed last wins. Your own fart starts the moment you press, so
-- it feels instant; the server still decides whether the boat moves.
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
--                                               Rate and Speed are set from fart power.
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
	StartedAt: number, -- os.clock() when it started, for its power
	Emitter: ParticleEmitter?,
	Sound: Sound?,
	BasePitch: number,
}

local FartServiceClient = {}

type FartServiceClientMembers = {
	HeldDirections: { FartPhysics.Direction }, -- fart keys the local player is holding, in the order pressed
	LocalDirection: FartPhysics.Direction?, -- the direction the local player is farting, if they are
	Streams: { [Player]: Stream }, -- everyone farting right now, the local player included
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

	RunService.RenderStepped:Connect(function()
		self:Update()
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

-- Every frame: grow each fart's effects with its power, and stop the local fart if
-- the player ran out of gas or isn't riding any more.
function FartServiceClient.Update(self: FartServiceClient)
	if self.LocalDirection and (GetLocalGas() <= 0 or not IsRiding()) then
		table.clear(self.HeldDirections)
		self:SetLocalDirection(nil)
	end

	local now = os.clock()
	local powerRange = FartConfig.MAX_POWER - FartConfig.MIN_POWER
	for player, stream in self.Streams do
		if not player.Parent then
			self:StopStream(player)
			continue
		end
		local power = FartPhysics.GetPower(now - stream.StartedAt)
		local powerProgress = if powerRange > 0 then (power - FartConfig.MIN_POWER) / powerRange else 1
		local emitter = stream.Emitter
		local template = self.FartCloudTemplate
		if emitter and template then
			emitter.Rate = FartConfig.STREAM_PARTICLE_RATE * power
			emitter.Speed = NumberRange.new(template.Speed.Min * power, template.Speed.Max * power)
		end
		local sound = stream.Sound
		if sound then
			sound.PlaybackSpeed = stream.BasePitch
				* (1 + (power - FartConfig.MIN_POWER) * FartConfig.PITCH_RISE_PER_POWER)
			sound.Volume = FartConfig.STREAM_VOLUME
				+ (FartConfig.MAX_STREAM_VOLUME - FartConfig.STREAM_VOLUME) * powerProgress
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

-- Starts (or switches) `player`'s fart effects: a steady gas cloud and a looping sound.
function FartServiceClient.StartStream(self: FartServiceClient, player: Player, direction: string)
	self:StopStream(player)
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
		StartedAt = os.clock(),
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
