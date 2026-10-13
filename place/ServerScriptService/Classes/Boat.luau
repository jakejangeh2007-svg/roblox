--!strict
-- ModuleScript: ServerScriptService.Classes.Boat
--
-- A boat cloned from a template in ReplicatedStorage.Assets.Boats. It waits at a
-- dock until every seat is taken, counts down, then moves into the river.
--
-- Template contract (a Model built by hand, with no scripts inside):
--   PrimaryPart   must be set. Weld every other part to it with WeldConstraints.
--   Seats         one Seat per player, anywhere in the model. The number of Seats must
--                 match the size the template is listed under in BoatConfig.TEMPLATE_NAMES.
--
-- States: Docked -> Launching -> Launched -> Destroyed. Launching goes back to Docked
-- if a seat empties during the countdown. The model's State and LaunchTime attributes
-- (see BoatServiceShared) mirror this for clients.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoatConfig = require(ReplicatedStorage.Shared.Modules.Game.BoatConfig)
local BoatServiceShared = require(ReplicatedStorage.Shared.Services.BoatService.BoatServiceShared)
local Signal = require(ReplicatedStorage.Packages.Signal)

local Boat = {}
Boat.__index = Boat

type BoatMembers = {
	Model: Model,
	Owner: Player, -- who spawned it
	Seats: { Seat },
	State: BoatServiceShared.BoatState,
	Crew: { Player }, -- who was aboard at launch, minus anyone who has left since
	LaunchCFrame: CFrame,
	LastCheckpointIndex: number, -- the location it launched from, then each checkpoint it reaches
	EmptySince: number?, -- os.clock() when a docked boat last became empty, nil while anyone is aboard
	LaunchCount: number, -- goes up whenever a countdown starts or stops, so an old countdown can tell it's stale
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

-- Checks a template follows the contract above. Returns a problem description if not.
function Boat.CheckTemplate(template: Instance?, seatCount: number): string?
	if not template or not template:IsA("Model") then
		return "is missing (it should be a Model)"
	end
	if not template.PrimaryPart then
		return "has no PrimaryPart set"
	end
	local foundSeats = #GetSeats(template)
	if foundSeats ~= seatCount then
		return `has {foundSeats} Seats but should have {seatCount}`
	end
	return nil
end

-- Clones `template` to `dockCFrame` and puts it in `parent`. The template must have
-- passed CheckTemplate.
function Boat.new(
	template: Model,
	owner: Player,
	dockCFrame: CFrame,
	launchCFrame: CFrame,
	startIndex: number,
	parent: Instance
): Boat
	local model = template:Clone()
	local self = setmetatable(
		{
			Model = model,
			Owner = owner,
			Seats = GetSeats(model),
			State = "Docked",
			Crew = {},
			LaunchCFrame = launchCFrame,
			LastCheckpointIndex = startIndex,
			EmptySince = os.clock(),
			LaunchCount = 0,
			Connections = {},
			CrewMemberLeft = Signal.new(),
		} :: BoatMembers,
		Boat
	)

	local primaryPart = model.PrimaryPart
	if primaryPart then
		-- Held in place for now. Water movement will unanchor it when it's added.
		primaryPart.Anchored = true
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

-- True while the boat is still at its dock (waiting or counting down).
function Boat.IsAtDock(self: Boat): boolean
	return self.State == "Docked" or self.State == "Launching"
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

-- Takes `player` out of their seat in this boat, if they're in one.
function Boat.Eject(self: Boat, player: Player)
	for _, seat in self.Seats do
		if GetPlayerInSeat(seat) == player then
			EjectFromSeat(seat)
		end
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

	local seatedCount = #self:GetSeatedPlayers()
	if seatedCount == 0 then
		self.EmptySince = self.EmptySince or os.clock()
	else
		self.EmptySince = nil
	end
	if seatedCount == #self.Seats then
		self:BeginLaunch()
	else
		self:CancelLaunch()
	end
end

function Boat.BeginLaunch(self: Boat)
	if self.State ~= "Docked" then
		return
	end
	self:SetState("Launching")
	self.LaunchCount += 1
	local launchCount = self.LaunchCount
	self.Model:SetAttribute(
		BoatServiceShared.LAUNCH_TIME_ATTRIBUTE,
		workspace:GetServerTimeNow() + BoatConfig.LAUNCH_DELAY
	)
	task.delay(BoatConfig.LAUNCH_DELAY, function()
		-- The state may have changed during the countdown.
		local currentState: BoatServiceShared.BoatState = self.State
		if self.LaunchCount == launchCount and currentState == "Launching" then
			self:Launch()
		end
	end)
end

function Boat.CancelLaunch(self: Boat)
	if self.State ~= "Launching" then
		return
	end
	self.LaunchCount += 1
	self:SetState("Docked")
	self.Model:SetAttribute(BoatServiceShared.LAUNCH_TIME_ATTRIBUTE, nil)
end

function Boat.Launch(self: Boat)
	self.Crew = self:GetSeatedPlayers()
	self:SetState("Launched")
	self.Model:SetAttribute(BoatServiceShared.LAUNCH_TIME_ATTRIBUTE, nil)
	self:MoveTo(self.LaunchCFrame)
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
	self.LaunchCount += 1
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
