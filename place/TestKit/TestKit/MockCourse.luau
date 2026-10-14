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
