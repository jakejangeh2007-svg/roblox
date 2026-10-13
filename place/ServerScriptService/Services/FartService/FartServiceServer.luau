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
