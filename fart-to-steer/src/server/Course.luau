--!strict
-- Finds the course in Workspace, or builds a grey-box test course if there isn't one.
--
-- To use your own course, make a Folder named "Course" in Workspace with:
--   Water   Folder of parts. The TOP face of each part is the water surface.
--           Give a part a Vector3 attribute named "Current" to make its water flow.
--   Spawns  Folder of parts where boats start (named Spawn1, Spawn2, ...).
--           Make them Anchored, CanCollide off and Transparency 1.
--   Finish  (optional) a part; a boat whose middle gets inside it has finished.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Course = {
	water: Folder,
	spawns: { CFrame },
	finish: BasePart?,
}

local Course = {}

local WATER_COLOR = Color3.fromRGB(70, 160, 230)
local CURRENT_COLOR = Color3.fromRGB(120, 200, 250)
local WALL_COLOR = Color3.fromRGB(150, 110, 75)
local ROCK_COLOR = Color3.fromRGB(110, 110, 115)
local LOG_COLOR = Color3.fromRGB(120, 80, 45)

local function makePart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
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

local function makeFolder(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

-- A rectangle of water from (x0, z0) to (x1, z1), optionally flowing at `current` studs/s.
local function addWater(parent: Folder, name: string, x0: number, z0: number, x1: number, z1: number, current: Vector3?)
	local size = Vector3.new(x1 - x0, 2, z1 - z0)
	local center = Vector3.new((x0 + x1) / 2, Config.WATER_Y - 1, (z0 + z1) / 2)
	local water = makePart(parent, name, size, CFrame.new(center), if current then CURRENT_COLOR else WATER_COLOR)
	water.Material = Enum.Material.Glass
	water.Transparency = 0.25
	water.CanCollide = false
	water.CanTouch = false
	if current then
		water:SetAttribute("Current", current)
	end
end

-- A straight wall from (x0, z0) to (x1, z1) that sticks 4 studs out of the water.
local function addWall(parent: Folder, x0: number, z0: number, x1: number, z1: number)
	local thickness = 2
	local height = 6
	local size = Vector3.new(math.max(math.abs(x1 - x0), thickness), height, math.max(math.abs(z1 - z0), thickness))
	local center = Vector3.new((x0 + x1) / 2, Config.WATER_Y + height / 2 - 2, (z0 + z1) / 2)
	makePart(parent, "Wall", size, CFrame.new(center), WALL_COLOR)
end

local function addRock(parent: Folder, x: number, z: number)
	local rock = makePart(parent, "Rock", Vector3.new(10, 10, 10), CFrame.new(x, Config.WATER_Y, z), ROCK_COLOR)
	rock.Shape = Enum.PartType.Ball
	rock.Material = Enum.Material.Slate
end

-- A log lying across the river (along X), centered at (x, z).
local function addLog(parent: Folder, x: number, z: number, length: number)
	local log = makePart(parent, "Log", Vector3.new(length, 3, 3), CFrame.new(x, Config.WATER_Y + 0.5, z), LOG_COLOR)
	log.Shape = Enum.PartType.Cylinder
	log.Material = Enum.Material.Wood
end

local function addSign(parent: Folder, position: Vector3, text: string)
	local anchor = makePart(parent, "Sign", Vector3.one, CFrame.new(position), Color3.new(1, 1, 1))
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(320, 70)
	billboard.MaxDistance = 250
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Parent = billboard
end

-- The M0 "fun test" course: a start pond, a rock slalom, a log gate, a sky river
-- with no walls (fall off and you respawn) and a finish pond.
local function build(): Course
	local folder = Instance.new("Folder")
	folder.Name = "TestCourse"
	local water = makeFolder(folder, "Water")
	local walls = makeFolder(folder, "Walls")
	local obstacles = makeFolder(folder, "Obstacles")
	local signs = makeFolder(folder, "Signs")
	local y = Config.WATER_Y

	-- 1. Start pond, open on the far side
	addWater(water, "StartPond", -60, 0, 60, 120)
	addWall(walls, -62, 0, 62, 0)
	addWall(walls, -60, 0, -60, 120)
	addWall(walls, 60, 0, 60, 120)
	addWall(walls, -62, 120, -25, 120)
	addWall(walls, 25, 120, 62, 120)
	addSign(signs, Vector3.new(0, y + 14, 100), "Only the BACK of the boat should fart Straight!")

	-- 2. Rock slalom, then a log gate with a 24-stud gap
	addWater(water, "Slalom", -25, 120, 25, 300)
	addWall(walls, -25, 120, -25, 300)
	addWall(walls, 25, 120, 25, 300)
	addRock(obstacles, -10, 160)
	addRock(obstacles, 10, 195)
	addRock(obstacles, -10, 230)
	addLog(obstacles, -18.5, 275, 13)
	addLog(obstacles, 18.5, 275, 13)
	addSign(signs, Vector3.new(0, y + 10, 265), "Squeeze through the gate!")

	-- 3. Sky river with no walls: it flows forward, then a crosswind pushes you toward the edge
	addWater(water, "SkyRiver", -20, 300, 20, 360, Vector3.new(0, 0, 4))
	addWater(water, "Bend", -20, 360, 20, 400)
	addWater(water, "Crosswind", 20, 360, 150, 400, Vector3.new(3, 0, -2))
	addSign(signs, Vector3.new(0, y + 10, 310), "No walls! Don't fall off")
	addSign(signs, Vector3.new(85, y + 10, 400), "Crosswind!")

	-- 4. Finish pond
	addWater(water, "FinishPond", 150, 330, 230, 430)
	addWall(walls, 150, 330, 230, 330)
	addWall(walls, 150, 430, 230, 430)
	addWall(walls, 230, 330, 230, 430)
	addWall(walls, 150, 330, 150, 360)
	addWall(walls, 150, 400, 150, 430)
	local finish = makePart(folder, "Finish", Vector3.new(16, 14, 16), CFrame.new(200, y + 5, 380), Color3.fromRGB(80, 255, 120))
	finish.Material = Enum.Material.Neon
	finish.Transparency = 0.7
	finish.CanCollide = false
	finish.CanQuery = false
	finish.CanTouch = false
	addSign(signs, Vector3.new(200, y + 16, 380), "FINISH")

	folder.Parent = workspace

	local spawns = {}
	for _, offset in { Vector3.new(0, 0, 25), Vector3.new(-30, 0, 25), Vector3.new(30, 0, 25), Vector3.new(0, 0, 60) } do
		table.insert(spawns, CFrame.new(offset + Vector3.new(0, y + Config.FLOAT_HEIGHT, 0)))
	end
	return { water = water, spawns = spawns, finish = finish }
end

local function fromFolder(folder: Folder, water: Folder): Course
	local spawnParts: { BasePart } = {}
	local spawnFolder = folder:FindFirstChild("Spawns")
	if spawnFolder then
		for _, child in spawnFolder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(spawnParts, child)
			end
		end
	end
	table.sort(spawnParts, function(a, b)
		return a.Name < b.Name
	end)

	local spawns = {}
	for _, part in spawnParts do
		table.insert(spawns, CFrame.new(part.Position))
	end
	if #spawns == 0 then
		-- no spawns: start in the middle of the first water part
		local first = water:FindFirstChildWhichIsA("BasePart", true)
		assert(first, "Workspace.Course.Water has no parts in it")
		table.insert(spawns, CFrame.new(first.Position + Vector3.new(0, first.Size.Y / 2 + Config.FLOAT_HEIGHT, 0)))
	end

	local finish = folder:FindFirstChild("Finish")
	return {
		water = water,
		spawns = spawns,
		finish = if finish and finish:IsA("BasePart") then finish else nil,
	}
end

function Course.get(): Course
	local folder = workspace:FindFirstChild("Course")
	if folder and folder:IsA("Folder") then
		local water = folder:FindFirstChild("Water")
		if water and water:IsA("Folder") then
			return fromFolder(folder, water)
		end
		warn("Workspace.Course has no Water folder, so the grey-box test course was built instead")
	end
	return build()
end

return Course
