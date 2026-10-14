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
-- is stepped by WaterService every frame.
-- Riders don't sit in the boat: they hang on to the outside of it at their seat
-- (RiderConfig.HANG_OFFSET), with their legs in the water. They can slide round the edge
-- within their own stretch of it: the rim is shared out between the seats, each rider
-- getting from their seat halfway to the next seat each way (a lone seat gets the whole
-- way round). RiderService moves them. They weigh what they weigh, but while they're on
-- a boat they don't bump into anything, so only the hull touches the world.
-- A rider knocked off on the river (OverboardService) is still part of the crew, and
-- their seat is kept for them until they swim back and grab on again, or give up.
--
-- Template contract (a Model built by hand, with no scripts inside):
--   PrimaryPart   must be set: a flat part in the middle of the boat, at the height the
--                 water should come up to, with its top face pointing up. It can be invisible.
--   Welds         every other part, Seats included, welded to the PrimaryPart with
--                 WeldConstraints (directly or through other welded parts).
--   Physics       every part gets BoatConfig's slippery, slightly bouncy HULL_ settings,
--                 keeping its own density.
--   Seats         one Seat per player: where they hold on. The number of Seats must match
--                 the size the template is listed under in BoatConfig.TEMPLATE_NAMES. Put
--                 them on the rim, spread evenly round the edge, facing the middle; each
--                 rider hangs outside their seat at RiderConfig.HANG_OFFSET and slides round
--                 a circle about the PrimaryPart from there.
--
-- States: Docked -> Launched -> Destroyed. The model's State, LeaderUserId and
-- DepartureTime attributes (see BoatServiceShared) mirror this for clients.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BoatConfig = require(ReplicatedStorage.Shared.Modules.Game.BoatConfig)
local BoatServiceShared = require(ReplicatedStorage.Shared.Services.BoatService.BoatServiceShared)
local Hull = require(ServerScriptService.Classes.Hull)
local RiderServiceShared = require(ReplicatedStorage.Shared.Services.RiderService.RiderServiceShared)
local RiderSpots = require(ReplicatedStorage.Shared.Services.RiderService.RiderSpots)
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
	Hull: Hull.Hull?, -- how it moves on the river; made when it launches
	SeatRiders: { [Seat]: Player }, -- who is hanging on at each seat right now
	RiderSpots: { [BasePart]: RiderSpots.RiderSpot }, -- where each seat's rider hangs on and can slide
	RiderSlides: { [Seat]: number }, -- how far round the edge each seat's rider has slid (radians)
	RiderParts: { [Player]: { [BasePart]: string } }, -- each rider's body parts and the collision group to put back
	Overboard: { [Player]: Seat }, -- crew knocked off on the river, and the seat kept for each of them
	Reboarding: { [Seat]: Player }, -- who is grabbing back on at each seat right now
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
			SeatRiders = {},
			RiderSpots = {},
			RiderSlides = {},
			RiderParts = {},
			Overboard = {},
			Reboarding = {},
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
	if primaryPart then
		local seatParts: { BasePart } = {}
		for _, seat in self.Seats do
			table.insert(seatParts, seat)
		end
		self.RiderSpots = RiderSpots.GetSpots(primaryPart.CFrame, seatParts)
	end
	self:MoveTo(dockCFrame)

	for _, seat in self.Seats do
		table.insert(
			self.Connections,
			seat:GetPropertyChangedSignal("Occupant"):Connect(function()
				self:OnSeatChanged(seat)
			end)
		)
		-- Roblox welds a rider to their seat when they sit; once it has, move them to
		-- hang on outside it, where OnSeatChanged put them.
		table.insert(
			self.Connections,
			seat.ChildAdded:Connect(function(child)
				if child.Name == "SeatWeld" then
					task.defer(function()
						self:SetRiderSlide(seat, self:GetRiderSlide(seat))
					end)
				end
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
	-- Whoever was hanging on here has let go.
	local previousRider = self.SeatRiders[seat]
	if previousRider then
		self.SeatRiders[seat] = nil
		self:ReleaseRider(previousRider)
	end

	local isLaunched = self.State == "Launched"
	local humanoid = seat.Occupant
	local rider = GetPlayerInSeat(seat)
	local isReboarding = rider ~= nil and self.Reboarding[seat] == rider
	self.Reboarding[seat] = nil
	if humanoid and ((isLaunched and not isReboarding) or not rider) then
		-- Only players ride, and nobody climbs aboard after launch (apart from crew
		-- grabbing back on after being knocked off).
		EjectFromSeat(seat)
		return
	end
	if rider then
		self.SeatRiders[seat] = rider
		self:PrepareRider(rider)
		-- Someone grabbing back on was put where they grabbed (by Reboard); anyone else
		-- starts at their seat.
		self:SetRiderSlide(seat, if isReboarding then self:GetRiderSlide(seat) else 0)
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
	local primaryPart = self.Model.PrimaryPart
	if primaryPart then
		self.Hull = Hull.new(primaryPart)
	end
end

-- Moves whoever hangs on at `seat` `angle` radians round the edge from it (see
-- RiderSpots), and tells every client (the seat's SlideAngle attribute).
function Boat.SetRiderSlide(self: Boat, seat: Seat, angle: number)
	local spot = self.RiderSpots[seat]
	if not spot then
		return
	end
	self.RiderSlides[seat] = angle
	if seat:GetAttribute(RiderServiceShared.SLIDE_ANGLE_ATTRIBUTE) ~= angle then
		seat:SetAttribute(RiderServiceShared.SLIDE_ANGLE_ATTRIBUTE, angle)
	end
	local seatWeld = seat:FindFirstChild("SeatWeld")
	if seatWeld and seatWeld:IsA("Weld") then
		seatWeld.C0 = RiderSpots.GetSeatWeldC0(spot, angle)
		seatWeld.C1 = CFrame.identity
	end
end

-- How far round the edge from `seat` its rider has slid (radians, positive is to their right).
function Boat.GetRiderSlide(self: Boat, seat: Seat): number
	return self.RiderSlides[seat] or 0
end

-- Where `seat`'s rider hangs on and how far they can slide, if it's one of this boat's seats.
function Boat.GetRiderSpot(self: Boat, seat: Seat): RiderSpots.RiderSpot?
	return self.RiderSpots[seat]
end

-- While `player` hangs on, their body doesn't bump into anything; only the hull does.
function Boat.PrepareRider(self: Boat, player: Player)
	local character = player.Character
	if not character or self.RiderParts[player] then
		return
	end
	local riderParts: { [BasePart]: string } = {}
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			riderParts[descendant] = descendant.CollisionGroup
			descendant.CollisionGroup = BoatServiceShared.RIDER_COLLISION_GROUP
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
	for part, collisionGroup in riderParts do
		if part.Parent then
			part.CollisionGroup = collisionGroup
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

-- Knocks `player` off this boat on the river: they let go, but stay in the crew, and
-- their seat is kept for them. Returns that seat, or nil if they weren't hanging on here.
function Boat.KnockOff(self: Boat, player: Player): Seat?
	local seat = self:GetSeatOf(player)
	if self.State ~= "Launched" or not seat then
		return nil
	end
	self.Overboard[player] = seat
	self.SeatRiders[seat] = nil
	self:ReleaseRider(player)
	EjectFromSeat(seat)
	return seat
end

-- Whether `player` is in the crew but knocked off.
function Boat.IsOverboard(self: Boat, player: Player): boolean
	return if self.Overboard[player] then true else false
end

-- The seat kept for `player` while they're knocked off, if they are.
function Boat.GetOverboardSeat(self: Boat, player: Player): Seat?
	return self.Overboard[player]
end

-- Puts knocked-off `player` back on at their seat, `angle` radians round the edge from it
-- (see RiderSpots). Returns false if they can't grab on (they aren't overboard, the boat
-- isn't floating, or their character isn't alive).
function Boat.Reboard(self: Boat, player: Player, angle: number): boolean
	local seat = self.Overboard[player]
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not seat or not self:IsFloating() or seat.Occupant or not humanoid or humanoid.Health <= 0 then
		return false
	end
	self.Overboard[player] = nil
	self.Reboarding[seat] = player
	self.RiderSlides[seat] = angle
	seat:Sit(humanoid)
	if not seat:FindFirstChild("SeatWeld") then
		-- Roblox wouldn't sit them: they're still overboard.
		self.Reboarding[seat] = nil
		self.Overboard[player] = seat
		return false
	end
	return true
end

-- Takes knocked-off `player` out of the crew (they gave up, or fell off the river).
function Boat.RemoveFromCrew(self: Boat, player: Player)
	if self.Overboard[player] then
		self.Overboard[player] = nil
		self:RemoveMissingCrew()
	end
end

-- After launch: anyone in the crew who is no longer seated, and wasn't knocked off, has
-- left the boat.
function Boat.RemoveMissingCrew(self: Boat)
	local seatedPlayers = self:GetSeatedPlayers()
	for index = #self.Crew, 1, -1 do
		local player = self.Crew[index]
		if not table.find(seatedPlayers, player) and not self.Overboard[player] then
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
	for player in self.RiderParts do
		self:ReleaseRider(player)
	end
	table.clear(self.SeatRiders)
	table.clear(self.Overboard)
	table.clear(self.Reboarding)
	if wasLaunched then
		for _, player in self.Crew do
			self.CrewMemberLeft:Fire(player)
		end
	end
	self.Crew = {}
	self.Model:Destroy()
end

return Boat
