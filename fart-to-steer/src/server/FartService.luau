--!strict
-- Checks every fart a player sends, spends their gas and pushes their boat.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BoatService = require(script.Parent.BoatService)
local Config = require(ReplicatedStorage.Shared.Config)
local FartPhysics = require(ReplicatedStorage.Shared.FartPhysics)

local Remotes = ReplicatedStorage.Remotes

type Mega = {
	player: Player,
	time: number,
	push: Vector3,
	spin: number,
}

local FartService = {}

local QUAKE_COLOR = Color3.fromRGB(255, 220, 60)

local recentMegas: { [BoatService.Boat]: { Mega } } = {}

-- Remembers a Mega Fart. If enough different riders on the boat have Mega
-- Farted within FARTQUAKE_WINDOW, it's a FARTQUAKE: returns true plus the
-- combined push and spin of those Megas, so the bonus can be added on top.
local function registerMega(boat: BoatService.Boat, mega: Mega): (boolean, Vector3, number)
	local list = recentMegas[boat] or {}
	recentMegas[boat] = list
	for i = #list, 1, -1 do
		if mega.time - list[i].time > Config.FARTQUAKE_WINDOW then
			table.remove(list, i)
		end
	end
	table.insert(list, mega)

	local riderCount = 0
	for _ in boat.riders do
		riderCount += 1
	end
	local needed = math.max(2, math.min(Config.FARTQUAKE_MIN_PLAYERS, riderCount))

	local seen: { [Player]: boolean } = {}
	local count = 0
	for _, entry in list do
		if not seen[entry.player] then
			seen[entry.player] = true
			count += 1
		end
	end
	if count < needed then
		return false, Vector3.zero, 0
	end

	local push, spin = Vector3.zero, 0
	for _, entry in list do
		push += entry.push
		spin += entry.spin
	end
	table.clear(list)
	return true, push, spin
end

local function onFart(player: Player, direction: unknown, heldTime: unknown)
	if not FartPhysics.isDirection(direction) then
		return
	end
	if typeof(heldTime) ~= "number" or heldTime ~= heldTime then
		return -- not a number, or NaN
	end
	local rider = BoatService.riders[player]
	if not rider or rider.boat.resetting then
		return
	end

	local now = os.clock()
	-- a little slack, because network packets can arrive bunched together
	if now - rider.lastFart < Config.TOOT_COOLDOWN * 0.8 then
		return
	end
	local held = math.clamp(heldTime, 0, Config.MEGA_CHARGE_TIME)
	local cost = FartPhysics.getCost(held)
	if rider.gas < cost then
		return
	end
	rider.gas -= cost
	rider.lastFart = now

	local boat = rider.boat
	local root = boat.root
	local power = FartPhysics.getPower(held)
	local push, spin = FartPhysics.getKick(
		root.CFrame,
		boat.seats[rider.seatIndex].WorldPosition,
		direction :: FartPhysics.Direction,
		power
	)
	push *= boat.boatType.pushScale
	spin *= boat.boatType.spinScale
	root.AssemblyLinearVelocity += push
	root.AssemblyAngularVelocity += Vector3.yAxis * spin

	local isMega = FartPhysics.isMega(held)
	if isMega then
		local quaked, bonusPush, bonusSpin =
			registerMega(boat, { player = player, time = now, push = push, spin = spin })
		if quaked then
			local extra = Config.FARTQUAKE_MULT - 1
			root.AssemblyLinearVelocity += bonusPush * extra
			root.AssemblyAngularVelocity += Vector3.yAxis * bonusSpin * extra
			BoatService.notify(boat, "FARTQUAKE!", QUAKE_COLOR, 1.5)
		end
	end

	-- Everyone else sees and hears it. The farter already played it the moment they let go.
	for _, other in Players:GetPlayers() do
		if other ~= player then
			Remotes.FartFX:FireClient(other, player, direction, power, isMega)
		end
	end
end

local function regenerate(dt: number)
	for player, rider in BoatService.riders do
		rider.gas = math.min(Config.GAS_MAX, rider.gas + Config.GAS_REGEN * dt)
		local shown = math.floor(rider.gas)
		if player:GetAttribute("Gas") ~= shown then
			player:SetAttribute("Gas", shown)
		end
	end
end

function FartService.start()
	Remotes.Fart.OnServerEvent:Connect(onFart)
	RunService.Heartbeat:Connect(regenerate)
end

return FartService
