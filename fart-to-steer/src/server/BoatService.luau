--!strict
-- Builds the round boats, seats players on them, and handles falling off,
-- finishing and respawning. The server owns every boat's physics, so all
-- players' farts count the same and nobody's lag can break the boat.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BoatTypes = require(ReplicatedStorage.Shared.BoatTypes)
local Config = require(ReplicatedStorage.Shared.Config)
local Course = require(script.Parent.Course)

local NoticeRemote = ReplicatedStorage.Remotes.Notice

export type Boat = {
	model: Model,
	root: BasePart,
	boatType: BoatTypes.BoatType,
	seats: { Attachment },
	riders: { [number]: Player }, -- seat number -> player
	spawn: CFrame,
	startedAt: number,
	resetting: boolean,
}

export type Rider = {
	player: Player,
	boat: Boat,
	seatIndex: number,
	gas: number,
	lastFart: number,
}

local BoatService = {
	boats = {} :: { Boat },
	riders = {} :: { [Player]: Rider },
}

local BOAT_GROUP = "Boats"
local RIDER_GROUP = "Riders"
local RIP_COLOR = Color3.fromRGB(255, 90, 90)
local FINISH_COLOR = Color3.fromRGB(90, 255, 130)

local course: Course.Course
local boatsFolder: Folder

local function setupCollisionGroups()
	for _, group in { BOAT_GROUP, RIDER_GROUP } do
		if not PhysicsService:IsCollisionGroupRegistered(group) then
			PhysicsService:RegisterCollisionGroup(group)
		end
	end
	-- Boats pass through each other, and riders only touch the world through their tube.
	PhysicsService:CollisionGroupSetCollidable(BOAT_GROUP, BOAT_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(BOAT_GROUP, RIDER_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(RIDER_GROUP, RIDER_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(RIDER_GROUP, "Default", false)
end

-- Make sure the server simulates the boat. Welding a character onto it can
-- hand it to that player, so this runs again after seating and every second.
local function claimOwnership(boat: Boat)
	local root = boat.root
	if not root:CanSetNetworkOwnership() then
		return
	end
	if root:GetNetworkOwnershipAuto() or root:GetNetworkOwner() ~= nil then
		root:SetNetworkOwner(nil)
	end
end

local function weldToRoot(root: BasePart, part: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
end

local function buildBoat(boatType: BoatTypes.BoatType, spawn: CFrame, index: number): Boat
	local model = Instance.new("Model")
	model.Name = "Boat" .. index
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	-- Invisible part in the middle. Everything is welded to it and it is the
	-- assembly root, so seats and pushes are all measured from here.
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(2, 1, 2)
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.RootPriority = 127
	root.CollisionGroup = BOAT_GROUP
	root.CFrame = spawn
	root.Parent = model
	model.PrimaryPart = root

	local ringRadius = boatType.ringRadius
	local tubeRadius = boatType.tubeRadius

	-- The tube: short striped cylinders around a circle
	local segments = math.max(12, math.round(ringRadius * 2.5))
	local segmentLength = 2 * math.pi * ringRadius / segments * 1.15
	for i = 1, segments do
		local angle = (i - 1) / segments * 2 * math.pi
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * ringRadius
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))

		local segment = Instance.new("Part")
		segment.Name = "Tube"
		segment.Shape = Enum.PartType.Cylinder
		segment.Size = Vector3.new(segmentLength, tubeRadius * 2, tubeRadius * 2)
		segment.CFrame = spawn * CFrame.fromMatrix(offset, tangent, Vector3.yAxis)
		segment.Color = if i % 2 == 0 then boatType.color else Color3.new(1, 1, 1)
		segment.Material = Enum.Material.SmoothPlastic
		segment.CustomPhysicalProperties = PhysicalProperties.new(0.3, 0.1, 0.5, 1, 1)
		segment.CollisionGroup = BOAT_GROUP
		segment.Parent = model
		weldToRoot(root, segment)
	end

	-- The floor in the middle of the ring (just for looks)
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Shape = Enum.PartType.Cylinder
	floor.Size = Vector3.new(0.4, ringRadius * 2, ringRadius * 2)
	floor.CFrame = spawn * CFrame.new(0, -tubeRadius * 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2)
	floor.Color = boatType.color:Lerp(Color3.new(0, 0, 0), 0.3)
	floor.Material = Enum.Material.SmoothPlastic
	floor.CanCollide = false
	floor.Massless = true
	floor.CollisionGroup = BOAT_GROUP
	floor.Parent = model
	weldToRoot(root, floor)

	-- Seats sit on the outer half of the tube, facing the middle
	local seats = {}
	local seatRadius = ringRadius + tubeRadius * 0.5
	local seatY = tubeRadius + Config.SEAT_HEIGHT
	for i = 1, boatType.seats do
		local angle = (i - 1) / boatType.seats * 2 * math.pi
		local position = Vector3.new(math.cos(angle) * seatRadius, seatY, math.sin(angle) * seatRadius)
		local seat = Instance.new("Attachment")
		seat.Name = "Seat" .. i
		seat.CFrame = CFrame.lookAt(position, Vector3.new(0, seatY, 0))
		seat.Parent = root
		seats[i] = seat
	end

	-- Keep the ring upright while letting it spin freely. The attachment's
	-- primary axis (its X axis) points up, and the constraint keeps it pointing up.
	local upright = Instance.new("Attachment")
	upright.Name = "Upright"
	upright.CFrame = CFrame.fromMatrix(Vector3.zero, Vector3.yAxis, Vector3.xAxis)
	upright.Parent = root

	local align = Instance.new("AlignOrientation")
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.AlignType = Enum.AlignType.PrimaryAxisParallel
	align.PrimaryAxis = Vector3.yAxis
	align.Attachment0 = upright
	align.MaxTorque = math.huge
	align.Responsiveness = 25
	align.Parent = root

	model.Parent = boatsFolder

	local boat: Boat = {
		model = model,
		root = root,
		boatType = boatType,
		seats = seats,
		riders = {},
		spawn = spawn,
		startedAt = os.clock(),
		resetting = false,
	}
	claimOwnership(boat)
	return boat
end

local function addBoat(): Boat
	local index = #BoatService.boats + 1
	local boatType = BoatTypes[Config.DEFAULT_BOAT]
	assert(boatType, `Config.DEFAULT_BOAT "{Config.DEFAULT_BOAT}" is not in BoatTypes`)
	local spawn = course.spawns[(index - 1) % #course.spawns + 1]
	local boat = buildBoat(boatType, spawn, index)
	table.insert(BoatService.boats, boat)
	return boat
end

local function findFreeSeat(): (Boat, number)
	for _, boat in BoatService.boats do
		for _, seatIndex in boat.boatType.fillOrder do
			if not boat.riders[seatIndex] then
				return boat, seatIndex
			end
		end
	end
	local boat = addBoat()
	return boat, boat.boatType.fillOrder[1]
end

local function resetBoat(boat: Boat)
	local root = boat.root
	root.Anchored = true
	root.CFrame = boat.spawn
	root.Anchored = false
	claimOwnership(boat) -- unanchoring hands ownership back to the engine
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	boat.startedAt = os.clock()
	boat.resetting = false
	for _, player in boat.riders do
		local rider = BoatService.riders[player]
		if rider then
			rider.gas = Config.GAS_MAX
		end
	end
end

function BoatService.notify(boat: Boat, text: string, color: Color3, shake: number)
	for _, player in boat.riders do
		NoticeRemote:FireClient(player, text, color, shake)
	end
end

local function wipe(boat: Boat)
	boat.resetting = true
	boat.root.Anchored = true -- freeze in mid-air for the RIP moment
	BoatService.notify(boat, "RIP: Rest In Pfft", RIP_COLOR, 0)
	task.delay(Config.RESET_DELAY, resetBoat, boat)
end

local function finish(boat: Boat)
	boat.resetting = true
	local seconds = os.clock() - boat.startedAt
	local time = string.format("%d:%04.1f", math.floor(seconds / 60), seconds % 60)
	BoatService.notify(boat, `FINISH! {time}`, FINISH_COLOR, 0.5)
	task.delay(Config.FINISH_RESET_DELAY, resetBoat, boat)
end

local function isInside(part: BasePart, position: Vector3): boolean
	local relative = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(relative.X) <= half.X and math.abs(relative.Y) <= half.Y and math.abs(relative.Z) <= half.Z
end

local function unseat(player: Player)
	local rider = BoatService.riders[player]
	if not rider then
		return
	end
	BoatService.riders[player] = nil
	local boat = rider.boat
	if boat.riders[rider.seatIndex] == player then
		boat.riders[rider.seatIndex] = nil
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local weld = rootPart and rootPart:FindFirstChild("RiderWeld")
	if weld then
		weld:Destroy()
	end

	-- An empty boat goes back to the start, ready for the next player.
	if next(boat.riders) == nil and not boat.resetting then
		resetBoat(boat)
	end
end

local function setRiderPhysics(instance: Instance)
	if instance:IsA("BasePart") then
		instance.Massless = true
		instance.CollisionGroup = RIDER_GROUP
	end
end

local function seatCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local rootPart = character:WaitForChild("HumanoidRootPart", 10)
	if not (humanoid and humanoid:IsA("Humanoid") and rootPart and rootPart:IsA("BasePart")) then
		return
	end
	if character.Parent == nil or player.Character ~= character or BoatService.riders[player] then
		return
	end

	local boat, seatIndex = findFreeSeat()
	local seat = boat.seats[seatIndex]
	boat.riders[seatIndex] = player
	BoatService.riders[player] = {
		player = player,
		boat = boat,
		seatIndex = seatIndex,
		gas = Config.GAS_MAX,
		lastFart = 0,
	}

	for _, descendant in character:GetDescendants() do
		setRiderPhysics(descendant)
	end
	character.DescendantAdded:Connect(setRiderPhysics)

	rootPart.CFrame = boat.root.CFrame * seat.CFrame
	local weld = Instance.new("Weld")
	weld.Name = "RiderWeld"
	weld.Part0 = boat.root
	weld.Part1 = rootPart
	weld.C0 = seat.CFrame
	weld.Parent = rootPart

	humanoid.Sit = true
	humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
		-- no jumping off the boat
		if not humanoid.Sit and humanoid.Health > 0 and BoatService.riders[player] then
			humanoid.Sit = true
		end
	end)
	humanoid.Died:Connect(function()
		unseat(player)
	end)

	-- Tell the client which boat and seat it's on (used by the camera and controls)
	local boatValue = Instance.new("ObjectValue")
	boatValue.Name = "RiderBoat"
	boatValue.Value = boat.model
	boatValue.Parent = character
	character:SetAttribute("SeatIndex", seatIndex)
	player:SetAttribute("Gas", Config.GAS_MAX)

	claimOwnership(boat)
end

local ownershipTimer = 0

local function update(dt: number)
	ownershipTimer += dt
	local checkOwnership = ownershipTimer >= 1
	if checkOwnership then
		ownershipTimer = 0
	end

	local finishPart = course.finish
	for _, boat in BoatService.boats do
		if boat.resetting then
			continue
		end
		local hasRiders = next(boat.riders) ~= nil
		local position = boat.root.Position
		if position.Y < Config.KILL_Y then
			if hasRiders then
				wipe(boat)
			else
				resetBoat(boat)
			end
		elseif hasRiders and finishPart and isInside(finishPart, position) then
			finish(boat)
		elseif checkOwnership then
			claimOwnership(boat)
		end
	end
end

function BoatService.start(newCourse: Course.Course)
	course = newCourse
	setupCollisionGroups()

	boatsFolder = Instance.new("Folder")
	boatsFolder.Name = "Boats"
	boatsFolder.Parent = workspace

	-- one boat waiting at the start before anyone joins
	addBoat()

	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function(character)
			seatCharacter(player, character)
		end)
		player.CharacterRemoving:Connect(function()
			unseat(player)
		end)
		if player.Character then
			task.spawn(seatCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(unseat)

	RunService.Heartbeat:Connect(update)
end

return BoatService
