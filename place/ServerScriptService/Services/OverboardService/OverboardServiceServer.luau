--!strict
-- ModuleScript: ServerScriptService.Services.OverboardService.OverboardServiceServer
--
-- Riders who get knocked off their boat, from the hit to grabbing back on.
--   1. Knocked off: every frame, each rider hanging on to a boat on the river is checked
--      for anything solid overlapping them (hazards aside: those pop the boat instead).
--      If it's coming at them at KNOCK_OFF_SPEED or more, compared to how they're moving,
--      they're knocked off: thrown clear, tumbling. They stay in the crew, with their
--      seat kept for them.
--   2. Knocked out: they go limp (the Ragdoll class) and float for KNOCKOUT_TIME.
--   3. Swimming: they come round facing their boat. Farting (FartService, with the same
--      gas) pushes them the way they face, and they turn left and right (RequestSwimTurn).
--      The Swimmer class moves their body; the server runs its physics.
--   4. Back aboard: swimming to within GRAB_DISTANCE of anywhere along their own stretch
--      of their boat's edge grabs them back on there.
-- A swimmer who isn't back aboard within SWIM_TIME_LIMIT, or falls off the river, is taken
-- out of the crew, which sends them back to their checkpoint (CheckpointService), and is
-- told why (NotifyLeftBehind). If their boat is wiped or finishes, they go with the rest
-- of the crew. All the numbers are in OverboardConfig.
--
-- Each player's Overboard, WakeTime and GiveUpTime attributes tell clients and UI where
-- they're at (see OverboardServiceShared).

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Boat = require(ServerScriptService.Classes.Boat)
local BoatServiceServer = require(ServerScriptService.Services.BoatService.BoatServiceServer)
local BoatServiceShared = require(ReplicatedStorage.Shared.Services.BoatService.BoatServiceShared)
local FartServiceServer = require(ServerScriptService.Services.FartService.FartServiceServer)
local ObstacleServiceShared = require(ReplicatedStorage.Shared.Services.ObstacleService.ObstacleServiceShared)
local OverboardConfig = require(ReplicatedStorage.Shared.Modules.Game.OverboardConfig)
local OverboardServiceShared = require(ReplicatedStorage.Shared.Services.OverboardService.OverboardServiceShared)
local Ragdoll = require(ServerScriptService.Classes.Ragdoll)
local Remotes = require(ReplicatedStorage.Shared.Modules.Core.Remotes)
local RiderSpots = require(ReplicatedStorage.Shared.Services.RiderService.RiderSpots)
local Swimmer = require(ServerScriptService.Classes.Swimmer)
local WaterConfig = require(ReplicatedStorage.Shared.Modules.Game.WaterConfig)
local WaterServiceServer = require(ServerScriptService.Services.WaterService.WaterServiceServer)

local SERVICE_NAME = OverboardServiceShared.SERVICE_NAME
-- How far (studs) outside a rider's hit box the nearest point of a part can be and still
-- count as touching them. Spatial queries go by rough bounding boxes; this checks closer.
local HIT_TOLERANCE = 0.5

-- Someone knocked off their boat, and how they're getting on.
type Overboard = {
	Boat: Boat.Boat,
	Character: Model,
	Humanoid: Humanoid,
	RootPart: BasePart,
	Ragdoll: Ragdoll.Ragdoll?, -- while they're knocked out
	Swimmer: Swimmer.Swimmer,
	WakeTime: number, -- os.clock() they come round
	GiveUpTime: number?, -- os.clock() they're sent back if they aren't aboard (set once they're swimming)
}

local OverboardServiceServer = {}

type OverboardServiceServerMembers = {
	Overboards: { [Player]: Overboard }, -- everyone overboard right now
	TurnInputs: { [Player]: number }, -- -1 for each swimmer asking to turn left, 1 for right (missing = neither)
	GraceTimes: { [Player]: number }, -- os.clock() until which each player who just grabbed back on can't be knocked off
	HitParameters: OverlapParams,
	Random: Random,
	NotifyLeftBehindRemote: RemoteEvent,
}

export type OverboardServiceServer = typeof(OverboardServiceServer) & OverboardServiceServerMembers

local function Flatten(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

-- Whether `point` is inside the box at `boxCFrame` of size `boxSize`, give or take `tolerance`.
local function IsInBox(point: Vector3, boxCFrame: CFrame, boxSize: Vector3, tolerance: number): boolean
	local offset = boxCFrame:PointToObjectSpace(point)
	local halfSize = boxSize / 2 + Vector3.one * tolerance
	return math.abs(offset.X) <= halfSize.X and math.abs(offset.Y) <= halfSize.Y and math.abs(offset.Z) <= halfSize.Z
end

-- Whether `part` belongs to a character (a player's, or any other model with a Humanoid).
local function IsInCharacter(part: BasePart): boolean
	local model = part:FindFirstAncestorOfClass("Model")
	return model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
end

-- The point on `part` (counted as a box) closest to `position`.
local function GetClosestPoint(part: BasePart, position: Vector3): Vector3
	local offset = part.CFrame:PointToObjectSpace(position)
	local halfSize = part.Size / 2
	local clamped = Vector3.new(
		math.clamp(offset.X, -halfSize.X, halfSize.X),
		math.clamp(offset.Y, -halfSize.Y, halfSize.Y),
		math.clamp(offset.Z, -halfSize.Z, halfSize.Z)
	)
	return part.CFrame:PointToWorldSpace(clamped)
end

function OverboardServiceServer.Init(self: OverboardServiceServer)
	self.Overboards = {}
	self.TurnInputs = {}
	self.GraceTimes = {}
	self.Random = Random.new()
	self:SetUpCollisionGroups()

	-- Only parts a boat would bump into count as hitting a rider.
	local hitParameters = OverlapParams.new()
	hitParameters.CollisionGroup = BoatServiceShared.COLLISION_GROUP
	hitParameters.RespectCanCollide = true
	self.HitParameters = hitParameters

	self.NotifyLeftBehindRemote = Remotes.CreateEvent(SERVICE_NAME, OverboardServiceShared.NOTIFY_LEFT_BEHIND)
	Remotes.CreateEvent(SERVICE_NAME, OverboardServiceShared.REQUEST_SWIM_TURN).OnServerEvent
		:Connect(function(player: Player, direction: unknown)
			self:HandleTurnRequest(player, direction)
		end)

	-- Anyone leaving their boat's crew (it was wiped or finished, say) stops being overboard.
	BoatServiceServer.CrewMemberLeft:Connect(function(player: Player)
		self:EndOverboard(player, false)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:EndOverboard(player, true)
		self.TurnInputs[player] = nil
		self.GraceTimes[player] = nil
	end)
	RunService.Heartbeat:Connect(function(deltaTime)
		self:Update(deltaTime)
	end)
end

-- Swimmers bump into the map and get shoved by obstacles, but pass through boats,
-- riders and each other.
function OverboardServiceServer.SetUpCollisionGroups(self: OverboardServiceServer)
	local swimmerGroup = OverboardServiceShared.COLLISION_GROUP
	local obstacleGroup = ObstacleServiceShared.COLLISION_GROUP
	for _, collisionGroup in { swimmerGroup, obstacleGroup } do
		if not PhysicsService:IsCollisionGroupRegistered(collisionGroup) then
			PhysicsService:RegisterCollisionGroup(collisionGroup)
		end
	end
	for _, otherGroup in { BoatServiceShared.COLLISION_GROUP, BoatServiceShared.RIDER_COLLISION_GROUP, swimmerGroup } do
		PhysicsService:CollisionGroupSetCollidable(swimmerGroup, otherGroup, false)
	end
	for _, otherGroup in { "Default", obstacleGroup } do
		PhysicsService:CollisionGroupSetCollidable(swimmerGroup, otherGroup, true)
	end
end

-- Client request: turn left (-1), right (1) or stop turning (0) while swimming.
function OverboardServiceServer.HandleTurnRequest(self: OverboardServiceServer, player: Player, direction: unknown)
	if direction == 0 then
		self.TurnInputs[player] = nil
	elseif direction == -1 or direction == 1 then
		self.TurnInputs[player] = direction :: number
	end
end

function OverboardServiceServer.Update(self: OverboardServiceServer, deltaTime: number)
	local stepTime = math.min(deltaTime, WaterConfig.MAX_STEP_TIME)
	local now = os.clock()
	self:CheckHits(now)
	for player, overboard in table.clone(self.Overboards) do
		self:StepOverboard(player, overboard, now, stepTime)
	end
end

-- Knocks off every rider on the river who something is hitting hard enough.
function OverboardServiceServer.CheckHits(self: OverboardServiceServer, now: number)
	for player, graceTime in self.GraceTimes do
		if now >= graceTime then
			self.GraceTimes[player] = nil
		end
	end
	for _, boat in BoatServiceServer:GetLaunchedBoats() do
		local primaryPart = boat.Model.PrimaryPart
		if not boat:IsFloating() or not primaryPart then
			continue
		end
		for _, player in table.clone(boat.SeatRiders) do
			if self.GraceTimes[player] then
				continue
			end
			local hitVelocity = self:FindHit(player, primaryPart)
			if hitVelocity then
				self:KnockOff(player, boat, primaryPart, hitVelocity)
			end
		end
	end
end

-- How fast whatever is hitting `player` is coming at them (compared to how they're moving,
-- as they hang on to the boat whose PrimaryPart is `primaryPart`), if anything solid is
-- hitting them at KNOCK_OFF_SPEED or more. The hardest hit wins.
function OverboardServiceServer.FindHit(self: OverboardServiceServer, player: Player, primaryPart: BasePart): Vector3?
	local character = player.Character
	local rootPart = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not rootPart or not rootPart:IsA("BasePart") then
		return nil
	end
	local hitBox = rootPart.CFrame * OverboardConfig.HIT_BOX_OFFSET
	local halfHeight = OverboardConfig.HIT_BOX_SIZE.Y / 2

	local hardestHit: Vector3? = nil
	local hardestSpeed = OverboardConfig.KNOCK_OFF_SPEED
	for _, part in workspace:GetPartBoundsInBox(hitBox, OverboardConfig.HIT_BOX_SIZE, self.HitParameters) do
		-- Hazards pop the boat instead. Terrain has no shape to measure against here.
		if
			part:IsA("Terrain")
			or part:GetAttribute(ObstacleServiceShared.HAZARD_ATTRIBUTE) == true
			or IsInCharacter(part)
		then
			continue
		end
		-- Where on their body it's hitting (on the line up the middle of the hit box, so
		-- something hitting only their legs counts), and the nearest point of it there.
		local heightOnBody = hitBox:PointToObjectSpace(GetClosestPoint(part, hitBox.Position)).Y
		local bodyPoint = hitBox:PointToWorldSpace(Vector3.new(0, math.clamp(heightOnBody, -halfHeight, halfHeight), 0))
		local closestPoint = GetClosestPoint(part, bodyPoint)
		if not IsInBox(closestPoint, hitBox, OverboardConfig.HIT_BOX_SIZE, HIT_TOLERANCE) then
			continue -- near them, but not touching
		end
		local hitVelocity = part:GetVelocityAtPosition(closestPoint) - primaryPart:GetVelocityAtPosition(bodyPoint)
		-- Only how fast it's coming at them counts, so sliding along a wall doesn't knock
		-- them off but running into one does.
		local awayFromPart = bodyPoint - closestPoint
		local speed = if awayFromPart.Magnitude > 1e-3
			then hitVelocity:Dot(awayFromPart.Unit)
			else hitVelocity.Magnitude
		if speed >= hardestSpeed then
			hardestSpeed = speed
			hardestHit = hitVelocity
		end
	end
	return hardestHit
end

-- Knocks `player` off `boat`: thrown clear by a hit coming at them at `hitVelocity`,
-- tumbling and limp.
function OverboardServiceServer.KnockOff(
	self: OverboardServiceServer,
	player: Player,
	boat: Boat.Boat,
	primaryPart: BasePart,
	hitVelocity: Vector3
)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local rootPart = if humanoid then humanoid.RootPart else nil
	if not character or not humanoid or not rootPart or humanoid.Health <= 0 or self.Overboards[player] then
		return
	end
	local riderVelocity = primaryPart:GetVelocityAtPosition(rootPart.Position)
	local outward = Flatten(rootPart.Position - boat:GetPosition())
	if not boat:KnockOff(player) then
		return
	end

	-- Thrown off with the hit's speed plus a bounce, up and away from the boat.
	local velocity = riderVelocity
		+ hitVelocity * (1 + OverboardConfig.THROW_BOUNCE)
		+ (if outward.Magnitude > 0 then outward.Unit * OverboardConfig.THROW_OUT_SPEED else Vector3.zero)
	local across = Flatten(velocity)
	if across.Magnitude > OverboardConfig.MAX_THROW_SPEED then
		across = across.Unit * OverboardConfig.MAX_THROW_SPEED
	end
	velocity = across + Vector3.yAxis * (velocity.Y + OverboardConfig.THROW_UP_SPEED)
	local spinAxis =
		Vector3.new(self.Random:NextNumber(-1, 1), self.Random:NextNumber(-1, 1), self.Random:NextNumber(-1, 1))
	local spin = if spinAxis.Magnitude > 1e-3 then spinAxis.Unit * OverboardConfig.THROW_SPIN else Vector3.zero

	humanoid.PlatformStand = true
	local ragdoll = Ragdoll.new(character, humanoid)
	local swimmer = Swimmer.new(character, rootPart)
	swimmer:Throw(velocity, spin)

	local now = os.clock()
	self.Overboards[player] = {
		Boat = boat,
		Character = character,
		Humanoid = humanoid,
		RootPart = rootPart,
		Ragdoll = ragdoll,
		Swimmer = swimmer,
		WakeTime = now + OverboardConfig.KNOCKOUT_TIME,
		GiveUpTime = nil,
	}
	player:SetAttribute(OverboardServiceShared.STATE_ATTRIBUTE, "KnockedOut")
	player:SetAttribute(
		OverboardServiceShared.WAKE_TIME_ATTRIBUTE,
		workspace:GetServerTimeNow() + OverboardConfig.KNOCKOUT_TIME
	)
end

-- Moves one overboard player on by a frame: they come round when it's time, float and
-- swim, grab back on if they've reached their boat, or are left behind.
function OverboardServiceServer.StepOverboard(
	self: OverboardServiceServer,
	player: Player,
	overboard: Overboard,
	now: number,
	deltaTime: number
)
	local isStillHere = overboard.Character.Parent ~= nil
		and player.Character == overboard.Character
		and overboard.Humanoid.Health > 0
		and overboard.Boat:IsOverboard(player)
	if not isStillHere then
		-- They died, respawned or left the crew some other way.
		self:EndOverboard(player, true)
		return
	end
	if overboard.Ragdoll and now >= overboard.WakeTime then
		self:WakeUp(player, overboard)
	end

	local swimmer = overboard.Swimmer
	local position = overboard.RootPart.Position
	local water = WaterServiceServer:GetWater(position, now)
	if not water and position.Y < swimmer.LastWaterHeight - OverboardConfig.FALL_DISTANCE then
		self:LeaveBehind(player, "Fell")
		return
	end

	local isSwimming = overboard.Ragdoll == nil
	local push = if isSwimming then FartServiceServer:GetPush(player) * OverboardConfig.FART_PUSH_SCALE else 0
	local turnDirection = if isSwimming then self.TurnInputs[player] or 0 else 0
	swimmer:Step(water, push, turnDirection, deltaTime)
	if not isSwimming then
		return
	end

	local giveUpTime = overboard.GiveUpTime
	if giveUpTime and now >= giveUpTime then
		self:LeaveBehind(player, "TooLong")
		return
	end
	self:TryGrabOn(player, overboard)
end

-- `player` comes round: their body stiffens up and they start swimming, facing their boat.
function OverboardServiceServer.WakeUp(self: OverboardServiceServer, player: Player, overboard: Overboard)
	local ragdoll = overboard.Ragdoll
	if ragdoll then
		ragdoll:Destroy()
		overboard.Ragdoll = nil
	end
	overboard.Swimmer:StartSwimming(overboard.Boat:GetPosition() - overboard.RootPart.Position)
	overboard.GiveUpTime = os.clock() + OverboardConfig.SWIM_TIME_LIMIT

	player:SetAttribute(OverboardServiceShared.STATE_ATTRIBUTE, "Swimming")
	player:SetAttribute(OverboardServiceShared.WAKE_TIME_ATTRIBUTE, nil)
	player:SetAttribute(
		OverboardServiceShared.GIVE_UP_TIME_ATTRIBUTE,
		workspace:GetServerTimeNow() + OverboardConfig.SWIM_TIME_LIMIT
	)
end

-- Grabs `player` back on to their boat if they've swum close enough to their own
-- stretch of its edge.
function OverboardServiceServer.TryGrabOn(self: OverboardServiceServer, player: Player, overboard: Overboard)
	local boat = overboard.Boat
	local seat = boat:GetOverboardSeat(player)
	local spot = if seat then boat:GetRiderSpot(seat) else nil
	local primaryPart = boat.Model.PrimaryPart
	if not boat:IsFloating() or not spot or not primaryPart then
		return
	end
	local position = primaryPart.CFrame:PointToObjectSpace(overboard.RootPart.Position)
	local angle, distance = RiderSpots.GetClosestSlide(spot, position)
	if distance > OverboardConfig.GRAB_DISTANCE then
		return
	end

	-- Hand the body back before Roblox welds it to the seat (so nothing keeps turning it),
	-- then hang them on where they grabbed.
	local swimmer = overboard.Swimmer
	local heading = swimmer.Heading
	swimmer:Destroy(nil)
	overboard.Humanoid.PlatformStand = false
	if not boat:Reboard(player, angle) then
		-- Roblox wouldn't sit them: back into the water to try again.
		overboard.Humanoid.PlatformStand = true
		local newSwimmer = Swimmer.new(overboard.Character, overboard.RootPart)
		newSwimmer:StartSwimming(heading)
		overboard.Swimmer = newSwimmer
		return
	end
	self:Forget(player)
	self.GraceTimes[player] = os.clock() + OverboardConfig.REBOARD_GRACE_TIME
end

-- `player` didn't make it back to their boat: they leave its crew (which sends them back
-- to their checkpoint) and are told why.
function OverboardServiceServer.LeaveBehind(
	self: OverboardServiceServer,
	player: Player,
	reason: OverboardServiceShared.LeftBehindReason
)
	if not self.Overboards[player] then
		return
	end
	self:EndOverboard(player, true)
	self.NotifyLeftBehindRemote:FireClient(player, reason)
end

-- Stops `player` being overboard, if they are: their body stiffens up and goes back to
-- them. `leaveBoat` also takes them out of their boat's crew.
function OverboardServiceServer.EndOverboard(self: OverboardServiceServer, player: Player, leaveBoat: boolean)
	local overboard = self.Overboards[player]
	if not overboard then
		return
	end
	self:Forget(player)
	local ragdoll = overboard.Ragdoll
	if ragdoll then
		ragdoll:Destroy()
	end
	overboard.Swimmer:Destroy(player)
	if overboard.Humanoid.Parent then
		overboard.Humanoid.PlatformStand = false
	end
	if leaveBoat then
		overboard.Boat:RemoveFromCrew(player)
	end
end

-- Clears what this service keeps about `player` being overboard.
function OverboardServiceServer.Forget(self: OverboardServiceServer, player: Player)
	self.Overboards[player] = nil
	self.TurnInputs[player] = nil
	player:SetAttribute(OverboardServiceShared.STATE_ATTRIBUTE, nil)
	player:SetAttribute(OverboardServiceShared.WAKE_TIME_ATTRIBUTE, nil)
	player:SetAttribute(OverboardServiceShared.GIVE_UP_TIME_ATTRIBUTE, nil)
end

return OverboardServiceServer :: OverboardServiceServer
