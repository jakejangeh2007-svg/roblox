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
