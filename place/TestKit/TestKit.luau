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
--   - Ponds joined by rivers without walls (Current and Rapids), a few rocks and the finish.
--   - Round boat templates Boat1-Boat6, a fart cloud and a placeholder fart sound, but only
--     where you haven't made your own yet.
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
local ROCK_COLOR = Color3.fromRGB(110, 110, 115)
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

local function AddRock(sceneryFolder: Instance, x: number, z: number)
	local rock = MakePart(sceneryFolder, "Rock", Vector3.new(8, 8, 8), CFrame.new(x, WATER_Y, z), ROCK_COLOR)
	rock.Shape = Enum.PartType.Ball
	rock.Material = Enum.Material.Slate
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
		AddRock(sceneryFolder, -9, riverStartZ + 40)
		AddRock(sceneryFolder, 9, riverStartZ + 90)
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

-- A round inflatable boat: a ring of tube with seats on top, facing the middle.
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

	local seatHeight = 0.5 + tubeRadius + 0.2
	for seatNumber = 1, seatCount do
		local angle = (seatNumber - 1) / seatCount * 2 * math.pi
		local position = Vector3.new(math.cos(angle) * ringRadius, seatHeight, math.sin(angle) * ringRadius)
		local seat = Instance.new("Seat")
		seat.Name = `Seat{seatNumber}`
		seat.Size = Vector3.new(2, 0.4, 2)
		seat.CFrame = CFrame.lookAt(position, Vector3.new(0, seatHeight, 0))
		seat.Color = color
		seat.TopSurface = Enum.SurfaceType.Smooth
		seat.Parent = model
		WeldToRoot(root, seat)
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

	local fartSoundsFolder = GetOrMakeFolder(GetOrMakeFolder(assets, "Sounds"), "Farts")
	if not fartSoundsFolder:FindFirstChildOfClass("Sound") then
		-- A built-in splash as a stand-in until real fart sounds are added.
		local placeholder = Instance.new("Sound")
		placeholder.Name = "PlaceholderSplash"
		placeholder.SoundId = "rbxasset://sounds/impact_water.mp3"
		placeholder.Parent = fartSoundsFolder
	end

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
		"[TestKit] Test world built. Walk to a dock and press E to spawn a boat, sit in it, then wait for the timer or press F to start. Fart with A / W / D."
	)
end

return TestKit
