--[[
	INSTALL TEST KIT: paste this into Roblox Studio's Command Bar to add the test kit.

	It adds ServerScriptService.TestKit (a ModuleScript with MockCourse inside). While it exists, every playtest
	builds a grey-box test world at runtime (see the comments at the top of TestKit).
	When you're done testing, delete ServerScriptService.TestKit. Nothing else changes.

	Run the main Install.luau first, so the Server script knows to look for the test kit.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local FOLDERS: { { string } } = {}

local SCRIPTS: { { ParentPath: { string }, Name: string, ClassName: string, Source: string } } = {
	{
		ParentPath = { "ServerScriptService" },
		Name = "TestKit",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ServerScriptService.TestKit
--
-- TEST ONLY. DELETE THIS MODULESCRIPT WHEN YOU'RE DONE TESTING.
--
-- When it exists, the Server startup script calls TestKit.Build before any service
-- starts. Build makes a grey-box test world at runtime, so it all disappears when the
-- playtest stops. Nothing is saved into your place.
--   - A lobby and every checkpoint in CheckpointConfig.CHECKPOINTS: a platform, docks,
--     a "start the run" prompt on every dock, and teleport posts.
--   - Ponds joined by rivers without walls (Current and Rapids) and the finish.
--   - A mock obstacle course along the rivers (MockCourse, inside this module): swinging
--     doors, a sliding gate, slicing fan blades, spike balls, a swinging mace and side
--     fans, built from plain blocks through the real obstacle system.
--   - Round boat templates Boat1-Boat6, mock obstacle templates, a fart cloud, a dazed
--     effect for knocked-out players and a placeholder fart sound, but only where you
--     haven't made your own yet.
--   - A stand-in gas meter at the bottom middle of the screen (StarterGui.HUD, with the names
--     the UI.HUD.GasMeter module looks for), unless you've built your own HUD.
-- If Workspace.Map already exists, it's moved to ServerStorage for this playtest only.
--
-- Because there's no UI yet, the test world uses ProximityPrompts instead:
--   E at a dock's pier       spawn a boat with that dock's number of seats
--   F next to a docked boat  start the run now (party leader only, sitting in the boat)
--   E at a teleport post     teleport there (once unlocked)
-- Results that didn't work are printed in Output.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterGui = game:GetService("StarterGui")

local BoatConfig = require(ReplicatedStorage.Shared.Modules.Game.BoatConfig)
local BoatServiceServer = require(ServerScriptService.Services.BoatService.BoatServiceServer)
local CheckpointConfig = require(ReplicatedStorage.Shared.Modules.Game.CheckpointConfig)
local CheckpointServiceServer = require(ServerScriptService.Services.CheckpointService.CheckpointServiceServer)
local DockServiceServer = require(ServerScriptService.Services.DockService.DockServiceServer)
local DockServiceShared = require(ReplicatedStorage.Shared.Services.DockService.DockServiceShared)
local GasMeter = require(ReplicatedStorage.UI.HUD.GasMeter)
local MockCourse = require(script.MockCourse)
local ObstacleServiceShared = require(ReplicatedStorage.Shared.Services.ObstacleService.ObstacleServiceShared)

local WATER_Y = 100 -- height of the water surface; high up, so boats that fall off fall far
local POND_LENGTH = 140
local POND_HALF_WIDTH = 60
local RIVER_LENGTH = 140
local RIVER_HALF_WIDTH = 20
local SEGMENT_LENGTH = POND_LENGTH + RIVER_LENGTH
local PLATFORM_WIDTH = 40
local DOCK_SPACING = 22
local DOCK_COUNT = 6 -- dock 1 spawns a 1-seat boat, dock 2 a 2-seat boat, and so on
local FINISH_POND_LENGTH = 80

local WATER_COLOR = Color3.fromRGB(70, 160, 230)
local CURRENT_COLOR = Color3.fromRGB(110, 190, 245)
local RAPIDS_COLOR = Color3.fromRGB(160, 215, 250)
local WALL_COLOR = Color3.fromRGB(150, 110, 75)
local PLATFORM_COLOR = Color3.fromRGB(120, 170, 90)
local PIER_COLOR = Color3.fromRGB(170, 130, 85)
local POST_COLOR = Color3.fromRGB(240, 200, 60)
local BOAT_COLORS = {
	Color3.fromRGB(255, 170, 60),
	Color3.fromRGB(255, 120, 170),
	Color3.fromRGB(120, 220, 120),
	Color3.fromRGB(255, 80, 80),
	Color3.fromRGB(120, 110, 255),
	Color3.fromRGB(60, 200, 220),
}

local TestKit = {}

local function MakePart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- An invisible marker part that nothing touches.
local function MakeMarker(parent: Instance, name: string, size: Vector3, cframe: CFrame): Part
	local marker = MakePart(parent, name, size, cframe, Color3.new(1, 1, 1))
	marker.Transparency = 1
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	return marker
end

local function MakeFolder(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function GetOrMakeFolder(parent: Instance, name: string): Instance
	return parent:FindFirstChild(name) or MakeFolder(parent, name)
end

local function MakePrompt(parent: Instance, name: string, actionText: string, objectText: string, key: Enum.KeyCode)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = key
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 14
	prompt.Parent = parent
	return prompt
end

local function Report(player: Player, success: boolean, message: string?)
	if not success then
		print(`[TestKit] {player.Name}: {message or "didn't work"}`)
	end
end

-- Water from x0..x1, z0..z1 with its top at WATER_Y. A named current flows toward +Z.
local function AddWater(waterFolder: Instance, name: string, x0: number, z0: number, x1: number, z1: number)
	local center = Vector3.new((x0 + x1) / 2, WATER_Y - 1, (z0 + z1) / 2)
	local color = if name == "Rapids" then RAPIDS_COLOR elseif name == "Current" then CURRENT_COLOR else WATER_COLOR
	local water = MakePart(
		waterFolder,
		name,
		Vector3.new(x1 - x0, 2, z1 - z0),
		CFrame.lookAt(center, center + Vector3.zAxis),
		color
	)
	water.Material = Enum.Material.Glass
	water.Transparency = 0.3
	water.CanCollide = false
	water.CanTouch = false
end

-- A wall from (x0, z0) to (x1, z1) that sticks out of the water.
local function AddWall(sceneryFolder: Instance, x0: number, z0: number, x1: number, z1: number)
	local size = Vector3.new(math.max(math.abs(x1 - x0), 2), 6, math.max(math.abs(z1 - z0), 2))
	local center = Vector3.new((x0 + x1) / 2, WATER_Y + 1, (z0 + z1) / 2)
	MakePart(sceneryFolder, "Wall", size, CFrame.new(center), WALL_COLOR)
end

-- Walls across the pond at z, with a gap in the middle for the river.
local function AddCrossWallWithGap(sceneryFolder: Instance, z: number)
	AddWall(sceneryFolder, -POND_HALF_WIDTH, z, -RIVER_HALF_WIDTH, z)
	AddWall(sceneryFolder, RIVER_HALF_WIDTH, z, POND_HALF_WIDTH, z)
end

-- One location (lobby or checkpoint) with its pond, platform, docks and pieces.
local function BuildLocation(
	locationFolder: Instance,
	waterFolder: Instance,
	sceneryFolder: Instance,
	baseZ: number,
	isLobby: boolean
): number
	AddWater(waterFolder, "Water", -POND_HALF_WIDTH, baseZ, POND_HALF_WIDTH, baseZ + POND_LENGTH)
	AddWall(sceneryFolder, -POND_HALF_WIDTH, baseZ, -POND_HALF_WIDTH, baseZ + POND_LENGTH)
	if isLobby then
		AddWall(sceneryFolder, -POND_HALF_WIDTH, baseZ, POND_HALF_WIDTH, baseZ)
	else
		AddCrossWallWithGap(sceneryFolder, baseZ)
	end
	AddCrossWallWithGap(sceneryFolder, baseZ + POND_LENGTH)

	-- Land on the east side of the pond
	local platformX = POND_HALF_WIDTH + PLATFORM_WIDTH / 2
	MakePart(
		locationFolder,
		"Platform",
		Vector3.new(PLATFORM_WIDTH, 6, POND_LENGTH),
		CFrame.new(platformX, WATER_Y - 1, baseZ + POND_LENGTH / 2),
		PLATFORM_COLOR
	)
	MakeMarker(locationFolder, "Spawn", Vector3.new(4, 1, 4), CFrame.new(platformX, WATER_Y + 2.5, baseZ + 70))
	local launchPosition = Vector3.new(-25, WATER_Y, baseZ + 70)
	MakeMarker(
		locationFolder,
		"Launch",
		Vector3.new(2, 1, 2),
		CFrame.lookAt(launchPosition, launchPosition + Vector3.zAxis)
	)

	-- Docks: a pier sticking out from the platform, with the boat spot past its end
	local docksFolder = MakeFolder(locationFolder, DockServiceShared.DOCKS_FOLDER_NAME)
	for dockNumber = 1, DOCK_COUNT do
		local dockZ = baseZ + 12 + (dockNumber - 1) * DOCK_SPACING
		local dockModel = Instance.new("Model")
		dockModel.Name = `Dock{dockNumber}`
		local pier = MakePart(
			dockModel,
			"Pier",
			Vector3.new(16, 1, 8),
			CFrame.new(POND_HALF_WIDTH - 8, WATER_Y + 1, dockZ),
			PIER_COLOR
		)
		local boatSpawn = MakeMarker(dockModel, "BoatSpawn", Vector3.new(2, 1, 2), CFrame.new(32, WATER_Y, dockZ))
		local seatCount = math.min(dockNumber, BoatConfig.MAX_SEATS)
		local spawnPrompt = MakePrompt(
			pier,
			DockServiceShared.SPAWN_BOAT_PROMPT_NAME,
			`Spawn {seatCount}-seat boat`,
			dockModel.Name,
			Enum.KeyCode.E
		)
		local startPrompt = MakePrompt(boatSpawn, "StartRunPrompt", "Start the run now", "Leader only", Enum.KeyCode.F)
		dockModel.PrimaryPart = pier
		dockModel.Parent = docksFolder

		spawnPrompt.Triggered:Connect(function(player: Player)
			Report(player, DockServiceServer:HandleSpawnRequest(player, dockModel, seatCount))
		end)
		startPrompt.Triggered:Connect(function(player: Player)
			Report(player, BoatServiceServer:HandleStartRequest(player))
		end)
	end

	-- Where the river out of this pond starts
	return baseZ + POND_LENGTH
end

-- Posts on every platform that teleport to each location.
local function BuildTeleportPosts(locationFolders: { Instance }, locationIds: { string }, locationNames: { string })
	for locationIndex, locationFolder in locationFolders do
		local baseZ = (locationIndex - 1) * SEGMENT_LENGTH
		local postsFolder = MakeFolder(locationFolder, "TeleportPosts")
		for targetIndex, targetId in locationIds do
			local post = MakePart(
				postsFolder,
				"Post",
				Vector3.new(2, 6, 2),
				CFrame.new(POND_HALF_WIDTH + PLATFORM_WIDTH - 6, WATER_Y + 5, baseZ + 10 + (targetIndex - 1) * 8),
				POST_COLOR
			)
			local prompt = MakePrompt(post, "TeleportPrompt", "Teleport", locationNames[targetIndex], Enum.KeyCode.E)
			prompt.Triggered:Connect(function(player: Player)
				Report(player, CheckpointServiceServer:HandleTeleportRequest(player, targetId))
			end)
		end
	end
end

local function BuildMap()
	local existingMap = workspace:FindFirstChild("Map")
	if existingMap then
		existingMap.Name = "MapSetAsideByTestKit"
		existingMap.Parent = ServerStorage
		print("[TestKit] Moved your Workspace.Map to ServerStorage for this playtest.")
	end

	local map = MakeFolder(workspace, "Map")
	local waterFolder = MakeFolder(map, "Water")
	local sceneryFolder = MakeFolder(map, "Scenery")
	local obstaclesFolder = MakeFolder(map, ObstacleServiceShared.OBSTACLES_FOLDER_NAME)
	local checkpointsFolder = MakeFolder(map, "Checkpoints")

	local locationFolders: { Instance } = {}
	local locationIds = { CheckpointConfig.LOBBY_ID }
	local locationNames = { CheckpointConfig.LOBBY_DISPLAY_NAME }
	local lobbyFolder = MakeFolder(map, "Lobby")
	table.insert(locationFolders, lobbyFolder)
	for _, info in CheckpointConfig.CHECKPOINTS do
		table.insert(locationFolders, MakeFolder(checkpointsFolder, info.Id))
		table.insert(locationIds, info.Id)
		table.insert(locationNames, info.DisplayName)
	end

	for locationIndex, locationFolder in locationFolders do
		local baseZ = (locationIndex - 1) * SEGMENT_LENGTH
		local riverStartZ = BuildLocation(locationFolder, waterFolder, sceneryFolder, baseZ, locationIndex == 1)
		if locationIndex > 1 then
			-- Entering this pond from the river means reaching the checkpoint.
			MakeMarker(
				locationFolder,
				"Zone",
				Vector3.new(POND_HALF_WIDTH * 2, 30, 20),
				CFrame.new(0, WATER_Y + 5, baseZ + 10)
			)
		end

		-- A river with no walls: fall off the side and you start over at your checkpoint.
		local riverName = if locationIndex % 2 == 1 then "Current" else "Rapids"
		AddWater(waterFolder, riverName, -RIVER_HALF_WIDTH, riverStartZ, RIVER_HALF_WIDTH, riverStartZ + RIVER_LENGTH)
		MockCourse.PlaceRiver(obstaclesFolder, locationIndex, riverStartZ, WATER_Y)
	end

	-- The finish pond after the last river
	local finishZ = #locationFolders * SEGMENT_LENGTH
	AddWater(waterFolder, "Water", -POND_HALF_WIDTH, finishZ, POND_HALF_WIDTH, finishZ + FINISH_POND_LENGTH)
	AddCrossWallWithGap(sceneryFolder, finishZ)
	AddWall(sceneryFolder, -POND_HALF_WIDTH, finishZ, -POND_HALF_WIDTH, finishZ + FINISH_POND_LENGTH)
	AddWall(sceneryFolder, POND_HALF_WIDTH, finishZ, POND_HALF_WIDTH, finishZ + FINISH_POND_LENGTH)
	AddWall(
		sceneryFolder,
		-POND_HALF_WIDTH,
		finishZ + FINISH_POND_LENGTH,
		POND_HALF_WIDTH,
		finishZ + FINISH_POND_LENGTH
	)
	local finish =
		MakeMarker(map, "Finish", Vector3.new(POND_HALF_WIDTH * 2, 30, 20), CFrame.new(0, WATER_Y + 5, finishZ + 10))
	finish.Transparency = 0.8
	finish.Color = Color3.fromRGB(80, 255, 120)
	finish.Material = Enum.Material.Neon

	BuildTeleportPosts(locationFolders, locationIds, locationNames)
end

local function WeldToRoot(root: BasePart, part: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
end

-- A round inflatable boat: a ring of tube with a seat on its outer edge for each rider
-- to hang on to, facing the middle, and blockers between their stretches of the edge.
local function BuildBoatTemplate(seatCount: number): Model
	local model = Instance.new("Model")
	model.Name = BoatConfig.TEMPLATE_NAMES[seatCount]
	local color = BOAT_COLORS[seatCount] or BOAT_COLORS[1]
	local ringRadius = 2.5 + seatCount * 0.9
	local tubeRadius = 1.1

	-- The PrimaryPart: flat, in the middle, at the waterline
	local root = MakePart(model, "Root", Vector3.new(2, 0.2, 2), CFrame.new(), color)
	root.Transparency = 1
	root.CanCollide = false
	model.PrimaryPart = root

	local segmentCount = math.max(12, math.round(ringRadius * 3))
	local segmentLength = 2 * math.pi * ringRadius / segmentCount * 1.15
	for segmentNumber = 1, segmentCount do
		local angle = (segmentNumber - 1) / segmentCount * 2 * math.pi
		local offset = Vector3.new(math.cos(angle) * ringRadius, 0.5, math.sin(angle) * ringRadius)
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		local segment = MakePart(
			model,
			"Tube",
			Vector3.new(segmentLength, tubeRadius * 2, tubeRadius * 2),
			CFrame.fromMatrix(offset, tangent, Vector3.yAxis),
			if segmentNumber % 2 == 0 then color else Color3.new(1, 1, 1)
		)
		segment.Shape = Enum.PartType.Cylinder
		WeldToRoot(root, segment)
	end

	local floor = MakePart(
		model,
		"Floor",
		Vector3.new(0.3, ringRadius * 2, ringRadius * 2),
		CFrame.new(0, -0.1, 0) * CFrame.Angles(0, 0, math.pi / 2),
		color:Lerp(Color3.new(0, 0, 0), 0.3)
	)
	floor.Shape = Enum.PartType.Cylinder
	WeldToRoot(root, floor)

	-- On the outer top of the tube, where a rider hanging outside holds on
	local seatHeight = 0.5 + tubeRadius * 0.8
	local seatRadius = ringRadius + tubeRadius * 0.8
	for seatNumber = 1, seatCount do
		local angle = (seatNumber - 1) / seatCount * 2 * math.pi
		local position = Vector3.new(math.cos(angle) * seatRadius, seatHeight, math.sin(angle) * seatRadius)
		local seat = Instance.new("Seat")
		seat.Name = `Seat{seatNumber}`
		seat.Size = Vector3.new(2, 0.4, 1.2)
		seat.CFrame = CFrame.lookAt(position, Vector3.new(0, seatHeight, 0))
		seat.Color = color
		seat.TopSurface = Enum.SurfaceType.Smooth
		seat.Parent = model
		WeldToRoot(root, seat)
	end

	-- Blockers between the riders' stretches of the edge (riders slide up to them, not
	-- through them; the Boat class sets where each stretch ends)
	if seatCount >= 2 then
		for blockerNumber = 1, seatCount do
			local angle = (blockerNumber - 0.5) / seatCount * 2 * math.pi
			local radius = ringRadius + tubeRadius
			local position = Vector3.new(math.cos(angle) * radius, 0.8, math.sin(angle) * radius)
			local blocker = MakePart(
				model,
				"Blocker",
				Vector3.new(0.4, 2.4, 1.6),
				CFrame.lookAt(position, Vector3.new(0, 0.8, 0)),
				color:Lerp(Color3.new(0, 0, 0), 0.5)
			)
			blocker.CanCollide = false
			WeldToRoot(root, blocker)
		end
	end
	return model
end

local function BuildAssets()
	local assets = ReplicatedStorage.Assets
	local templatesFolder = GetOrMakeFolder(assets, "Boats")
	for seatCount = BoatConfig.MIN_SEATS, BoatConfig.MAX_SEATS do
		if not templatesFolder:FindFirstChild(BoatConfig.TEMPLATE_NAMES[seatCount]) then
			BuildBoatTemplate(seatCount).Parent = templatesFolder
		end
	end

	local vfxFolder = GetOrMakeFolder(assets, "VFX")
	if not vfxFolder:FindFirstChild("FartCloud") then
		local fartCloud = Instance.new("ParticleEmitter")
		fartCloud.Name = "FartCloud"
		fartCloud.Texture = "rbxasset://textures/particles/smoke_main.dds"
		fartCloud.Color = ColorSequence.new(Color3.fromRGB(160, 210, 70), Color3.fromRGB(110, 140, 60))
		fartCloud.EmissionDirection = Enum.NormalId.Back
		fartCloud.Rate = 0
		fartCloud.Lifetime = NumberRange.new(0.8, 1.4)
		fartCloud.Speed = NumberRange.new(6, 12)
		fartCloud.SpreadAngle = Vector2.new(20, 20)
		fartCloud.Drag = 3
		fartCloud.Acceleration = Vector3.new(0, 3, 0)
		fartCloud.Size = NumberSequence.new(0.8, 3.5)
		fartCloud.Transparency = NumberSequence.new(0.2, 1)
		fartCloud.RotSpeed = NumberRange.new(-90, 90)
		fartCloud.Parent = vfxFolder
	end
	if not vfxFolder:FindFirstChild("Dazed") then
		-- Yellow sparkles popping up over a knocked-out player's head
		local dazed = Instance.new("ParticleEmitter")
		dazed.Name = "Dazed"
		dazed.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		dazed.Color = ColorSequence.new(Color3.fromRGB(255, 230, 90))
		dazed.LightEmission = 0.6
		dazed.EmissionDirection = Enum.NormalId.Top
		dazed.Rate = 14
		dazed.Lifetime = NumberRange.new(0.6, 1)
		dazed.Speed = NumberRange.new(1.5, 3)
		dazed.SpreadAngle = Vector2.new(60, 60)
		dazed.Size = NumberSequence.new(0.6, 0)
		dazed.RotSpeed = NumberRange.new(-180, 180)
		dazed.Parent = vfxFolder
	end

	local fartSoundsFolder = GetOrMakeFolder(GetOrMakeFolder(assets, "Sounds"), "Farts")
	if not fartSoundsFolder:FindFirstChildOfClass("Sound") then
		-- A built-in splash as a stand-in until real fart sounds are added.
		local placeholder = Instance.new("Sound")
		placeholder.Name = "PlaceholderSplash"
		placeholder.SoundId = "rbxasset://sounds/impact_water.mp3"
		placeholder.Parent = fartSoundsFolder
	end

	MockCourse.BuildTemplates(GetOrMakeFolder(assets, ObstacleServiceShared.TEMPLATES_FOLDER_NAME))

	GetOrMakeFolder(workspace, "Boats")
end

-- A plain gas meter, bottom middle, sized with Scale only.
local function BuildGasMeter()
	if StarterGui:FindFirstChild(GasMeter.HUD_NAME) then
		return -- your own HUD wins
	end
	local hud = Instance.new("ScreenGui")
	hud.Name = GasMeter.HUD_NAME
	hud.ResetOnSpawn = false

	local meter = Instance.new("Frame")
	meter.Name = GasMeter.GAS_METER_NAME
	meter.AnchorPoint = Vector2.new(0.5, 1)
	meter.Position = UDim2.fromScale(0.5, 0.96)
	meter.Size = UDim2.fromScale(0.3, 0.035)
	meter.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
	meter.BorderSizePixel = 0
	meter.Parent = hud

	local fill = Instance.new("Frame")
	fill.Name = GasMeter.FILL_NAME
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(150, 210, 60)
	fill.BorderSizePixel = 0
	fill.Parent = meter

	for _, frame in { meter, fill } do
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = frame
	end

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = "GAS"
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.ZIndex = 2
	label.Parent = meter

	hud.Parent = StarterGui
end

function TestKit.Build()
	BuildAssets()
	BuildMap()
	BuildGasMeter()
	print(
		"[TestKit] Test world built. Walk to a dock and press E to spawn a boat, sit in it, then wait for the timer or press F to start. Slide round the edge with A / D, fart with W."
	)
end

return TestKit
]==],
	},
	{
		ParentPath = { "ServerScriptService", "TestKit" },
		Name = "MockCourse",
		ClassName = "ModuleScript",
		Source = [==[
--!strict
-- ModuleScript: ServerScriptService.TestKit.MockCourse
--
-- TEST ONLY: part of the TestKit, and deleted with it.
--
-- A mock obstacle course for the test world, built from plain blocks so it can be thrown
-- away once real models exist. It uses the real obstacle system, the same way a real map
-- will:
--   - BuildTemplates puts one mock template per obstacle into ReplicatedStorage.Assets.Obstacles
--     (only where there isn't one already, so a real model with the same name wins).
--   - PlaceRiver puts markers for those templates along a river in Workspace.Map.Obstacles.
--     ObstacleService swaps each marker for a copy of its template when the game starts.
--
-- The templates (red parts are hazards that pop boats):
--   SwingingDoor      Swinger: a door on a hinge post that swings open and shut
--   SlidingGate       Slider: a gate across the river that lifts out of the water and drops
--   FanBlades         Spinner: big blades turning along the river, slicing into the water
--   SpikeBall         a floating spiked ball that stays put
--   PatrolSpikeBall   Slider: a spiked ball hanging from a rail, running back and forth
--   SwingingMace      Swinger: a spiked ball on a pole swinging across the river
--   SideFan           WindFan: a big fan at the side blowing boats across the river
-- Every template is built with the water surface at its pivot's height, the river flowing
-- toward +Z, and the river's left bank (as you go downstream) toward -X.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ObstacleServiceShared = require(ReplicatedStorage.Shared.Services.ObstacleService.ObstacleServiceShared)

local SCENERY_COLOR = Color3.fromRGB(120, 115, 110)
local MOVING_COLOR = Color3.fromRGB(245, 190, 50)
local HAZARD_COLOR = Color3.fromRGB(230, 40, 40)
local DOOR_COLOR = Color3.fromRGB(150, 95, 55)

local MockCourse = {}

local function MakePart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function Weld(root: BasePart, part: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
end

local function MakeHazard(part: BasePart)
	part:SetAttribute(ObstacleServiceShared.HAZARD_ATTRIBUTE, true)
	part.Color = HAZARD_COLOR
	part.Material = Enum.Material.Neon
end

-- A CFrame at `position` whose front face points straight up (for a Base whose axis is vertical).
local function FacingUp(position: Vector3): CFrame
	return CFrame.fromMatrix(position, Vector3.xAxis, Vector3.zAxis)
end

-- A ball of diameter `size` at `center`, with spikes all round, every part a hazard and
-- welded to `root` (the ball itself if nil). Returns the ball.
local function AddSpikeBall(model: Model, center: Vector3, size: number, root: BasePart?): Part
	local ball = MakePart(model, "SpikeBall", Vector3.new(size, size, size), CFrame.new(center), HAZARD_COLOR)
	ball.Shape = Enum.PartType.Ball
	MakeHazard(ball)
	if root then
		Weld(root, ball)
	end
	local spikeLength = size * 0.4
	for _, direction in
		{
			Vector3.xAxis,
			-Vector3.xAxis,
			Vector3.yAxis,
			-Vector3.yAxis,
			Vector3.zAxis,
			-Vector3.zAxis,
			Vector3.new(1, 1, 1).Unit,
			Vector3.new(-1, 1, -1).Unit,
			Vector3.new(1, -1, -1).Unit,
			Vector3.new(-1, -1, 1).Unit,
		}
	do
		local spikeCenter = center + direction * (size / 2 + spikeLength / 2 - 0.2)
		-- A cylinder's length runs along its X axis; turn that to point outward.
		local spike = MakePart(
			model,
			"Spike",
			Vector3.new(spikeLength, size * 0.12, size * 0.12),
			CFrame.lookAt(spikeCenter, spikeCenter + direction) * CFrame.Angles(0, math.pi / 2, 0),
			HAZARD_COLOR
		)
		spike.Shape = Enum.PartType.Cylinder
		MakeHazard(spike)
		Weld(root or ball, spike)
	end
	return ball
end

-- Two posts sticking out of the water at either side of the river, joined by a beam at `height`.
local function AddGantry(model: Model, height: number)
	for _, x in { -22.5, 22.5 } do
		MakePart(model, "Post", Vector3.new(1.6, height + 4, 1.6), CFrame.new(x, (height - 4) / 2, 0), SCENERY_COLOR)
	end
	MakePart(model, "Beam", Vector3.new(46.6, 1.6, 1.6), CFrame.new(0, height, 0), SCENERY_COLOR)
end

local function NewTemplate(name: string, obstacleType: ObstacleServiceShared.ObstacleType?): Model
	local model = Instance.new("Model")
	model.Name = name
	if obstacleType then
		model:SetAttribute(ObstacleServiceShared.TYPE_ATTRIBUTE, obstacleType)
	end
	return model
end

local function BuildSwingingDoor(): Model
	-- A hinge post at the left bank and a door reaching toward the middle of the river,
	-- swinging downstream to open.
	local model = NewTemplate("SwingingDoor", "Swinger")
	MakePart(
		model,
		ObstacleServiceShared.BASE_NAME,
		Vector3.new(1.6, 1.6, 9),
		FacingUp(Vector3.new(0, 2, 0)),
		SCENERY_COLOR
	)
	MakePart(model, ObstacleServiceShared.MOVING_NAME, Vector3.new(19, 6, 0.8), CFrame.new(10.3, 1.5, 0), DOOR_COLOR)
	model:SetAttribute("FromAngle", 0)
	model:SetAttribute("ToAngle", -80)
	model:SetAttribute("MoveTime", 1.2)
	model:SetAttribute("HoldTime", 1.8)
	return model
end

local function BuildSlidingGate(): Model
	-- A gate across the river that lifts up out of the water, under a beam.
	local model = NewTemplate("SlidingGate", "Slider")
	for _, x in { -22.5, 22.5 } do
		MakePart(model, "Post", Vector3.new(1.6, 18, 1.6), CFrame.new(x, 5, 0), SCENERY_COLOR)
	end
	MakePart(
		model,
		ObstacleServiceShared.BASE_NAME,
		Vector3.new(46.6, 1.6, 1.6),
		FacingUp(Vector3.new(0, 14, 0)),
		SCENERY_COLOR
	)
	MakePart(model, ObstacleServiceShared.MOVING_NAME, Vector3.new(40, 7, 1), CFrame.new(0, 1, 0), MOVING_COLOR)
	model:SetAttribute("Distance", 8.5)
	model:SetAttribute("MoveTime", 1)
	model:SetAttribute("HoldTime", 2.2)
	return model
end

local function BuildFanBlades(): Model
	-- Three long blades on a hub above the middle of the river, turning around the
	-- direction the river flows and slicing down into the water.
	local model = NewTemplate("FanBlades", "Spinner")
	AddGantry(model, 18)
	MakePart(model, "Strut", Vector3.new(1, 7, 1), CFrame.new(0, 14, 0), SCENERY_COLOR)
	local hubCFrame = CFrame.new(0, 10, 0)
	MakePart(
		model,
		ObstacleServiceShared.BASE_NAME,
		Vector3.new(2, 2, 2),
		hubCFrame * CFrame.new(0, 0, -1.6),
		SCENERY_COLOR
	)
	local hub = MakePart(model, ObstacleServiceShared.MOVING_NAME, Vector3.new(3, 3, 1.4), hubCFrame, MOVING_COLOR)
	for bladeNumber = 1, 3 do
		local angle = (bladeNumber - 1) / 3 * 2 * math.pi
		local blade = MakePart(
			model,
			"Blade",
			Vector3.new(2.4, 14, 0.6),
			hubCFrame * CFrame.Angles(0, 0, angle) * CFrame.new(0, -8.5, 0),
			HAZARD_COLOR
		)
		MakeHazard(blade)
		Weld(hub, blade)
	end
	model:SetAttribute("Speed", 12)
	return model
end

local function BuildSpikeBall(): Model
	-- A spiked ball floating half out of the water. It doesn't move, so it needs no
	-- Obstacle attribute; its parts are hazards wherever they are.
	local model = NewTemplate("SpikeBall", nil)
	AddSpikeBall(model, Vector3.new(0, 0.5, 0), 6, nil)
	return model
end

local function BuildPatrolSpikeBall(): Model
	-- A spiked ball hanging from a carriage that runs along a rail across the river.
	local model = NewTemplate("PatrolSpikeBall", "Slider")
	AddGantry(model, 10)
	local start = Vector3.new(-14, 10, 0)
	MakePart(
		model,
		ObstacleServiceShared.BASE_NAME,
		Vector3.new(1.4, 1.4, 1.4),
		CFrame.lookAt(start + Vector3.new(0, 0, -1.6), start + Vector3.new(1, 0, -1.6)),
		SCENERY_COLOR
	)
	local carriage =
		MakePart(model, ObstacleServiceShared.MOVING_NAME, Vector3.new(2, 1.6, 2), CFrame.new(start), MOVING_COLOR)
	local chain =
		MakePart(model, "Chain", Vector3.new(0.4, 6, 0.4), CFrame.new(start + Vector3.new(0, -3.8, 0)), SCENERY_COLOR)
	Weld(carriage, chain)
	AddSpikeBall(model, start + Vector3.new(0, -7.5, 0), 5, carriage)
	model:SetAttribute("Distance", 28)
	model:SetAttribute("MoveTime", 2.4)
	model:SetAttribute("HoldTime", 0.4)
	return model
end

local function BuildSwingingMace(): Model
	-- A spiked ball on a pole hanging from a beam, swinging across the river like a pendulum.
	local model = NewTemplate("SwingingMace", "Swinger")
	AddGantry(model, 20)
	local pivot = Vector3.new(0, 19, 0)
	MakePart(model, ObstacleServiceShared.BASE_NAME, Vector3.new(1.6, 1.6, 1.6), CFrame.new(pivot), SCENERY_COLOR)
	local pole = MakePart(
		model,
		ObstacleServiceShared.MOVING_NAME,
		Vector3.new(0.6, 14, 0.6),
		CFrame.new(0, 12, 0),
		MOVING_COLOR
	)
	AddSpikeBall(model, Vector3.new(0, 2, 0), 6, pole)
	model:SetAttribute("FromAngle", -55)
	model:SetAttribute("ToAngle", 55)
	model:SetAttribute("MoveTime", 1.5)
	model:SetAttribute("HoldTime", 0.15)
	return model
end

local function BuildSideFan(): Model
	-- A big fan standing at the river's left bank, blowing across the river toward +X.
	local model = NewTemplate("SideFan", "WindFan")
	local fanCenter = Vector3.new(0, 4, 0)
	MakePart(
		model,
		"FrameTop",
		Vector3.new(1.2, 1.2, 14.4),
		CFrame.new(fanCenter + Vector3.new(0, 7, 0)),
		SCENERY_COLOR
	)
	MakePart(
		model,
		"FrameBottom",
		Vector3.new(1.2, 1.2, 14.4),
		CFrame.new(fanCenter + Vector3.new(0, -7, 0)),
		SCENERY_COLOR
	)
	MakePart(
		model,
		"FrameSide",
		Vector3.new(1.2, 14.4, 1.2),
		CFrame.new(fanCenter + Vector3.new(0, 0, 7)),
		SCENERY_COLOR
	)
	MakePart(
		model,
		"FrameSide",
		Vector3.new(1.2, 14.4, 1.2),
		CFrame.new(fanCenter + Vector3.new(0, 0, -7)),
		SCENERY_COLOR
	)
	local axle = fanCenter + Vector3.new(-1.4, 0, 0)
	MakePart(
		model,
		ObstacleServiceShared.BASE_NAME,
		Vector3.new(1.6, 1.6, 1.6),
		CFrame.lookAt(axle, axle + Vector3.xAxis),
		SCENERY_COLOR
	)
	local hub = MakePart(
		model,
		ObstacleServiceShared.MOVING_NAME,
		Vector3.new(1.2, 2.4, 2.4),
		CFrame.new(fanCenter),
		MOVING_COLOR
	)
	for bladeNumber = 1, 4 do
		local angle = (bladeNumber - 1) / 4 * 2 * math.pi
		local blade = MakePart(
			model,
			"FanBlade",
			Vector3.new(0.4, 5.4, 2.2),
			CFrame.new(fanCenter) * CFrame.Angles(angle, 0, 0) * CFrame.new(0, 3.6, 0),
			MOVING_COLOR
		)
		Weld(hub, blade)
	end

	-- The wind: across the whole river in front of the fan
	local windCenter = Vector3.new(24, 3, 0)
	local wind = MakePart(
		model,
		ObstacleServiceShared.WIND_NAME,
		Vector3.new(24, 14, 44),
		CFrame.lookAt(windCenter, windCenter + Vector3.xAxis),
		Color3.fromRGB(200, 230, 255)
	)
	wind.Transparency = 0.92
	wind.CanCollide = false
	local streaks = Instance.new("ParticleEmitter")
	streaks.Name = "WindStreaks"
	streaks.Texture = "rbxasset://textures/particles/smoke_main.dds"
	streaks.EmissionDirection = Enum.NormalId.Front
	streaks.Rate = 40
	streaks.Lifetime = NumberRange.new(0.8, 1.2)
	streaks.Speed = NumberRange.new(35, 45)
	streaks.Size = NumberSequence.new(0.6, 1.4)
	streaks.Transparency = NumberSequence.new(0.6, 1)
	streaks.Color = ColorSequence.new(Color3.new(1, 1, 1))
	streaks.Enabled = false
	streaks.Parent = wind

	model:SetAttribute("Strength", 28)
	model:SetAttribute("OnTime", 3)
	model:SetAttribute("OffTime", 3)
	model:SetAttribute("Speed", 150)
	return model
end

local TEMPLATE_BUILDERS: { [string]: () -> Model } = {
	SwingingDoor = BuildSwingingDoor,
	SlidingGate = BuildSlidingGate,
	FanBlades = BuildFanBlades,
	SpikeBall = BuildSpikeBall,
	PatrolSpikeBall = BuildPatrolSpikeBall,
	SwingingMace = BuildSwingingMace,
	SideFan = BuildSideFan,
}

-- Puts a mock template into `templatesFolder` for every obstacle that hasn't got one yet.
function MockCourse.BuildTemplates(templatesFolder: Instance)
	for name, build in TEMPLATE_BUILDERS do
		if not templatesFolder:FindFirstChild(name) then
			local template = build()
			template.WorldPivot = CFrame.identity
			template.Parent = templatesFolder
		end
	end
end

-- One marker on a river: which template, where (x and z along the river, from its
-- start), turned how far round (degrees), with which settings.
type Placement = {
	Template: string,
	X: number,
	Z: number,
	Turn: number?,
	Settings: { [string]: number }?,
}

-- What goes on each river, from the lobby's river (1) to the last one before the finish.
-- The river is 40 studs wide (X from -20 to 20) and 140 long.
local RIVER_LAYOUTS: { { Placement } } = {
	{
		-- Doors that swing open and shut, then floating spike balls to steer round
		{ Template = "SwingingDoor", X = -20, Z = 40 },
		{ Template = "SwingingDoor", X = 20, Z = 40, Turn = 180, Settings = { ToAngle = 80 } },
		{ Template = "SpikeBall", X = -8, Z = 85 },
		{ Template = "SpikeBall", X = 9, Z = 108 },
	},
	{
		-- Fan blades slicing the middle, then a fan blowing from the left
		{ Template = "FanBlades", X = 0, Z = 40 },
		{ Template = "SideFan", X = -24, Z = 95 },
	},
	{
		-- A gate to time, then a spike ball patrolling across
		{ Template = "SlidingGate", X = 0, Z = 40 },
		{ Template = "PatrolSpikeBall", X = 0, Z = 95 },
	},
	{
		-- A bit of everything
		{ Template = "SwingingMace", X = 0, Z = 30 },
		{ Template = "SideFan", X = 24, Z = 72, Turn = 180, Settings = { StartDelay = 1.5 } },
		{ Template = "FanBlades", X = 0, Z = 112, Settings = { Speed = -14 } },
	},
}

-- Puts markers for river `riverNumber`'s obstacles into `obstaclesFolder`, for a river
-- starting at `riverStartZ` with its water surface at `waterY`.
function MockCourse.PlaceRiver(obstaclesFolder: Instance, riverNumber: number, riverStartZ: number, waterY: number)
	local layout = RIVER_LAYOUTS[riverNumber]
	if not layout then
		return
	end
	for index, placement in layout do
		local marker = Instance.new("Part")
		marker.Name = `River{riverNumber}{placement.Template}{index}`
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanQuery = false
		marker.CanTouch = false
		marker.Transparency = 1
		marker.Size = Vector3.one
		marker.CFrame = CFrame.new(placement.X, waterY, riverStartZ + placement.Z)
			* CFrame.Angles(0, math.rad(placement.Turn or 0), 0)
		marker:SetAttribute(ObstacleServiceShared.TEMPLATE_ATTRIBUTE, placement.Template)
		local settings: { [string]: number } = placement.Settings or {}
		for name, value in settings do
			marker:SetAttribute(name, value)
		end
		marker.Parent = obstaclesFolder
	end
end

return MockCourse
]==],
	},
}

local createdPaths: { string } = {}
local updatedPaths: { string } = {}
local skippedPaths: { string } = {}

-- Finds the instance at `path` (service first), creating missing Folders along the way.
local function GetOrCreatePath(path: { string }): Instance
	local current: Instance = game:GetService(path[1])
	for index = 2, #path do
		local child = current:FindFirstChild(path[index])
		if not child then
			child = Instance.new("Folder")
			child.Name = path[index]
			child.Parent = current
			table.insert(createdPaths, child:GetFullName())
		end
		current = child
	end
	return current
end

local recording = ChangeHistoryService:TryBeginRecording("Install test kit")

-- Scripts first, shallowest first, so a ModuleScript with children (like UI) exists
-- before any folder inside it.
for _, scriptInfo in SCRIPTS do
	local parent = GetOrCreatePath(scriptInfo.ParentPath)
	local existing = parent:FindFirstChild(scriptInfo.Name)
	if existing and existing.ClassName ~= scriptInfo.ClassName then
		local existingPath = existing:GetFullName()
		warn(`{existingPath} is a {existing.ClassName}, expected a {scriptInfo.ClassName}. Skipped it.`)
		table.insert(skippedPaths, existingPath)
	elseif existing then
		if (existing :: any).Source ~= scriptInfo.Source then
			(existing :: any).Source = scriptInfo.Source
			table.insert(updatedPaths, existing:GetFullName())
		end
	else
		local newScript = Instance.new(scriptInfo.ClassName)
		newScript.Name = scriptInfo.Name;
		(newScript :: any).Source = scriptInfo.Source
		newScript.Parent = parent
		table.insert(createdPaths, newScript:GetFullName())
	end
end

for _, folderPath in FOLDERS do
	GetOrCreatePath(folderPath)
end

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end

print(`Install done: {#createdPaths} created, {#updatedPaths} updated, {#skippedPaths} skipped.`)
for _, path in createdPaths do
	print(`  + {path}`)
end
for _, path in updatedPaths do
	print(`  ~ {path}`)
end
