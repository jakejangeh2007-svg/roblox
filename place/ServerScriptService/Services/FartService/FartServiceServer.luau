--!strict
-- ModuleScript: ServerScriptService.Services.FartService.FartServiceServer
--
-- Runs every player's farting. A client asks to start farting (or to stop); this checks
-- they're riding a boat on the river (or swimming back to theirs after being knocked off)
-- and have gas, and keeps them farting until they stop, run out of gas or can't any more.
-- Their fart builds up strength while they keep it going and fades after they stop
-- (FartPhysics), and its push eases in and out smoothly. Gas drains at a flat rate while
-- farting and refills while not. Other players are told when someone starts or stops, so
-- they can show it.
--
-- This service doesn't move boats or swimmers. WaterService asks GetFartForces for the
-- pushes from each boat's crew and moves the boat with everything else acting on it;
-- OverboardService asks GetPush for each swimmer's.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Boat = require(ServerScriptService.Classes.Boat)
local BoatServiceServer = require(ServerScriptService.Services.BoatService.BoatServiceServer)
local FartConfig = require(ReplicatedStorage.Shared.Modules.Game.FartConfig)
local FartPhysics = require(ReplicatedStorage.Shared.Services.FartService.FartPhysics)
local FartServiceShared = require(ReplicatedStorage.Shared.Services.FartService.FartServiceShared)
local Hull = require(ServerScriptService.Classes.Hull)
local OverboardServiceShared = require(ReplicatedStorage.Shared.Services.OverboardService.OverboardServiceShared)
local Remotes = require(ReplicatedStorage.Shared.Modules.Core.Remotes)

local SERVICE_NAME = FartServiceShared.SERVICE_NAME
local MIN_PUSH = 0.01 -- a fart whose push has eased below this (studs/s²) has finished

local FartServiceServer = {}

type FartServiceServerMembers = {
	Gas: { [Player]: number },
	Farters: { [Player]: boolean }, -- everyone farting right now
	PendingStarts: { [Player]: boolean }, -- start requests waiting out the cooldown
	RampTimes: { [Player]: number }, -- how far each player's fart has built up (missing = not at all)
	Pushes: { [Player]: number }, -- how hard each player's fart is pushing right now, eased (missing = not at all)
	LastStartTimes: { [Player]: number },
	PlayFartRemote: RemoteEvent,
	StopFartRemote: RemoteEvent,
}

export type FartServiceServer = typeof(FartServiceServer) & FartServiceServerMembers

function FartServiceServer.Init(self: FartServiceServer)
	self.Gas = {}
	self.Farters = {}
	self.PendingStarts = {}
	self.RampTimes = {}
	self.Pushes = {}
	self.LastStartTimes = {}
	self.PlayFartRemote = Remotes.CreateEvent(SERVICE_NAME, FartServiceShared.PLAY_FART)
	self.StopFartRemote = Remotes.CreateEvent(SERVICE_NAME, FartServiceShared.STOP_FART)

	Remotes.CreateEvent(SERVICE_NAME, FartServiceShared.REQUEST_START_FART).OnServerEvent
		:Connect(function(player: Player)
			self:HandleStartRequest(player)
		end)
	Remotes.CreateEvent(SERVICE_NAME, FartServiceShared.REQUEST_STOP_FART).OnServerEvent
		:Connect(function(player: Player)
			self:StopFart(player, false)
		end)

	Players.PlayerAdded:Connect(function(player)
		self:SetGas(player, FartConfig.GAS_MAX)
	end)
	for _, player in Players:GetPlayers() do
		self:SetGas(player, FartConfig.GAS_MAX)
	end
	Players.PlayerRemoving:Connect(function(player)
		self:StopFart(player, false)
		self.Gas[player] = nil
		self.RampTimes[player] = nil
		self.Pushes[player] = nil
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

-- Client request: start farting. A request that comes sooner than REQUEST_COOLDOWN
-- after the last start isn't dropped: it waits and is acted on when the cooldown is up,
-- so the server always ends up doing what the player last asked for.
function FartServiceServer.HandleStartRequest(self: FartServiceServer, player: Player)
	if self.Farters[player] then
		return
	end
	local lastStartTime = self.LastStartTimes[player]
	if lastStartTime and os.clock() - lastStartTime < FartConfig.REQUEST_COOLDOWN then
		self.PendingStarts[player] = true
		return
	end
	self:StartFart(player)
end

-- Whether `player` is somewhere they can fart: hanging on to a boat on the river, or
-- swimming back to theirs (not while they're knocked out).
function FartServiceServer.CanFart(self: FartServiceServer, player: Player): boolean
	local boat = BoatServiceServer:GetLaunchedBoatOf(player)
	if not boat or not boat:IsFloating() then
		return false
	end
	if boat:GetSeatOf(player) then
		return true
	end
	return boat:IsOverboard(player) and OverboardServiceShared.GetState(player) == "Swimming"
end

-- Starts `player` farting, if they're allowed to. If they aren't, their client is told
-- to stop showing the fart.
function FartServiceServer.StartFart(self: FartServiceServer, player: Player)
	self.PendingStarts[player] = nil
	if not self:CanFart(player) or (self.Gas[player] or 0) < FartConfig.MIN_GAS_TO_START then
		self.StopFartRemote:FireClient(player, player)
		return
	end

	self.LastStartTimes[player] = os.clock()
	self.Farters[player] = true
	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer ~= player then
			self.PlayFartRemote:FireClient(otherPlayer, player)
		end
	end
end

-- Ends `player`'s fart. `notifyFarter` also tells the farter, for when the server
-- stops it (out of gas, left the boat) rather than the farter letting go.
function FartServiceServer.StopFart(self: FartServiceServer, player: Player, notifyFarter: boolean)
	self.PendingStarts[player] = nil
	if not self.Farters[player] then
		return
	end
	self.Farters[player] = nil
	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer ~= player or notifyFarter then
			self.StopFartRemote:FireClient(otherPlayer, player)
		end
	end
end

-- How hard `player`'s fart is pushing right now (studs/s² on a boat of
-- FartConfig.REFERENCE_MASS), eased in and out; 0 if they aren't farting.
function FartServiceServer.GetPush(self: FartServiceServer, player: Player): number
	return self.Pushes[player] or 0
end

-- The pushes from `boat`'s crew's farts right now: each rider's fart as a force from
-- where their body hangs on to the boat, toward its middle. Hull does the physics.
function FartServiceServer.GetFartForces(self: FartServiceServer, boat: Boat.Boat): { Hull.AppliedForce }
	local forces: { Hull.AppliedForce } = {}
	if not boat:IsFloating() then
		return forces
	end
	local boatPosition = boat:GetPosition()
	for _, player in boat.Crew do
		local push = self.Pushes[player]
		local seat = if push then boat:GetSeatOf(player) else nil
		if push and seat then
			local character = player.Character
			local rootPart = if character then character:FindFirstChild("HumanoidRootPart") else nil
			local riderCFrame = if rootPart and rootPart:IsA("BasePart") then rootPart.CFrame else seat.CFrame
			table.insert(forces, {
				Position = riderCFrame.Position,
				Force = FartPhysics.GetForce(boatPosition, riderCFrame, push),
			})
		end
	end
	return forces
end

function FartServiceServer.Update(self: FartServiceServer, deltaTime: number)
	-- Start requests that were waiting out the cooldown
	local now = os.clock()
	for player in self.PendingStarts do
		local lastStartTime = self.LastStartTimes[player]
		if not lastStartTime or now - lastStartTime >= FartConfig.REQUEST_COOLDOWN then
			self:StartFart(player)
		end
	end

	-- Farts end when the farter runs out of gas, or isn't riding on the river or swimming
	-- any more (knocked off, say).
	for player in self.Farters do
		local gas = self.Gas[player] or 0
		if gas <= 0 or not self:CanFart(player) then
			self:StopFart(player, true)
			continue
		end
		self:SetGas(player, math.max(0, gas - FartConfig.GAS_DRAIN * deltaTime))
	end

	-- Each fart's strength builds up or fades, and its push eases toward it.
	local blend = if FartConfig.PUSH_RESPONSE_TIME > 0
		then 1 - math.exp(-deltaTime / FartConfig.PUSH_RESPONSE_TIME)
		else 1
	for player, gas in self.Gas do
		local isFarting = self.Farters[player] == true
		local rampTime = FartPhysics.UpdateRampTime(self.RampTimes[player] or 0, isFarting, deltaTime)
		if rampTime > 0 then
			self.RampTimes[player] = rampTime
		else
			self.RampTimes[player] = nil
		end

		local targetPush = if isFarting then FartPhysics.GetPushAcceleration(rampTime) else 0
		local push = self.Pushes[player] or 0
		push += (targetPush - push) * blend
		if isFarting or push >= MIN_PUSH then
			self.Pushes[player] = push
		else
			self.Pushes[player] = nil
		end

		if not isFarting and gas < FartConfig.GAS_MAX then
			self:SetGas(player, math.min(FartConfig.GAS_MAX, gas + FartConfig.GAS_REGEN * deltaTime))
		end
	end
end

return FartServiceServer :: FartServiceServer
