--!strict
-- ModuleScript: ServerScriptService.Services.FartService.FartServiceServer
--
-- Checks every fart a client asks for, spends the player's gas and pushes their
-- boat. Clients only ask; this decides. Also handles FARTQUAKEs (several Mega Farts
-- on one boat at almost the same moment) and tells other players to play the effect.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Boat = require(ServerScriptService.Classes.Boat)
local BoatConfig = require(ReplicatedStorage.Shared.Modules.Game.BoatConfig)
local BoatServiceServer = require(ServerScriptService.Services.BoatService.BoatServiceServer)
local FartConfig = require(ReplicatedStorage.Shared.Modules.Game.FartConfig)
local FartPhysics = require(ReplicatedStorage.Shared.Services.FartService.FartPhysics)
local FartServiceShared = require(ReplicatedStorage.Shared.Services.FartService.FartServiceShared)
local Remotes = require(ReplicatedStorage.Shared.Modules.Core.Remotes)

local SERVICE_NAME = FartServiceShared.SERVICE_NAME

type Mega = {
	Player: Player,
	Time: number,
	Push: Vector3,
	Spin: number,
}

local FartServiceServer = {}

type FartServiceServerMembers = {
	Gas: { [Player]: number },
	LastFartTimes: { [Player]: number },
	RecentMegas: { [Boat.Boat]: { Mega } },
	PlayFartRemote: RemoteEvent,
	PlayFartquakeRemote: RemoteEvent,
}

export type FartServiceServer = typeof(FartServiceServer) & FartServiceServerMembers

function FartServiceServer.Init(self: FartServiceServer)
	self.Gas = {}
	self.LastFartTimes = {}
	self.RecentMegas = setmetatable({}, { __mode = "k" }) :: any
	self.PlayFartRemote = Remotes.CreateEvent(SERVICE_NAME, FartServiceShared.PLAY_FART)
	self.PlayFartquakeRemote = Remotes.CreateEvent(SERVICE_NAME, FartServiceShared.PLAY_FARTQUAKE)

	Remotes.CreateEvent(SERVICE_NAME, FartServiceShared.REQUEST_FART).OnServerEvent
		:Connect(function(player: Player, direction: unknown, heldTime: unknown)
			self:HandleFartRequest(player, direction, heldTime)
		end)

	Players.PlayerAdded:Connect(function(player)
		self:SetGas(player, FartConfig.GAS_MAX)
	end)
	for _, player in Players:GetPlayers() do
		self:SetGas(player, FartConfig.GAS_MAX)
	end
	Players.PlayerRemoving:Connect(function(player)
		self.Gas[player] = nil
		self.LastFartTimes[player] = nil
	end)

	RunService.Heartbeat:Connect(function(deltaTime)
		self:Regenerate(deltaTime)
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

function FartServiceServer.Regenerate(self: FartServiceServer, deltaTime: number)
	for player, gas in self.Gas do
		if gas < FartConfig.GAS_MAX then
			self:SetGas(player, math.min(FartConfig.GAS_MAX, gas + FartConfig.GAS_REGEN * deltaTime))
		end
	end
end

-- Client request: fart in `direction` after holding the key for `heldTime` seconds.
function FartServiceServer.HandleFartRequest(
	self: FartServiceServer,
	player: Player,
	direction: unknown,
	heldTime: unknown
)
	if not FartPhysics.IsDirection(direction) then
		return
	end
	if typeof(heldTime) ~= "number" or heldTime ~= heldTime then
		return -- not a number, or NaN
	end

	local boat = BoatServiceServer:GetLaunchedBoatOf(player)
	if not boat or not boat:IsFloating() then
		return
	end
	local seat = boat:GetSeatOf(player)
	if not seat then
		return
	end

	local now = os.clock()
	local lastFartTime = self.LastFartTimes[player]
	if lastFartTime and now - lastFartTime < FartConfig.TOOT_COOLDOWN * FartConfig.COOLDOWN_LENIENCY then
		return
	end
	local held = math.clamp(heldTime, 0, FartConfig.MEGA_CHARGE_TIME)
	local gas = self.Gas[player] or 0
	local cost = FartPhysics.GetCost(held)
	if gas < cost then
		return
	end
	self:SetGas(player, gas - cost)
	self.LastFartTimes[player] = now

	local power = FartPhysics.GetPower(held)
	local isMega = FartPhysics.IsMega(held)
	local seatCount = #boat.Seats
	local push, spin = FartPhysics.GetKick(boat:GetPosition(), seat.CFrame, direction :: FartPhysics.Direction, power)
	push *= BoatConfig.PUSH_SCALES[seatCount] or 1
	spin *= BoatConfig.SPIN_SCALES[seatCount] or 1
	boat:AddVelocity(push, spin)

	if isMega then
		self:RegisterMega(boat, { Player = player, Time = now, Push = push, Spin = spin })
	end

	-- Everyone else sees and hears it. The farter played it the moment they let go.
	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer ~= player then
			self.PlayFartRemote:FireClient(otherPlayer, player, direction, power, isMega)
		end
	end
end

-- Remembers a Mega Fart. If enough different crew members have Mega Farted within
-- FARTQUAKE_WINDOW, it's a FARTQUAKE: every one of those pushes gets stronger.
function FartServiceServer.RegisterMega(self: FartServiceServer, boat: Boat.Boat, mega: Mega)
	local megas: { Mega } = self.RecentMegas[boat] or {}
	self.RecentMegas[boat] = megas
	for index = #megas, 1, -1 do
		if mega.Time - megas[index].Time > FartConfig.FARTQUAKE_WINDOW then
			table.remove(megas, index)
		end
	end
	table.insert(megas, mega)

	local playersNeeded = math.max(2, math.min(FartConfig.FARTQUAKE_MIN_PLAYERS, #boat.Crew))
	local megaPlayers: { [Player]: boolean } = {}
	local playerCount = 0
	for _, entry in megas do
		if not megaPlayers[entry.Player] then
			megaPlayers[entry.Player] = true
			playerCount += 1
		end
	end
	if playerCount < playersNeeded then
		return
	end

	local extra = FartConfig.FARTQUAKE_MULT - 1
	for _, entry in megas do
		boat:AddVelocity(entry.Push * extra, entry.Spin * extra)
	end
	table.clear(megas)
	for _, crewMember in boat.Crew do
		self.PlayFartquakeRemote:FireClient(crewMember)
	end
end

return FartServiceServer :: FartServiceServer
