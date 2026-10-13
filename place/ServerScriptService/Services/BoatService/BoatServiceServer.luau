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
