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
