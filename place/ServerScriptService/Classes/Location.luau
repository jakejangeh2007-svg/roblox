--!strict
-- ModuleScript: ServerScriptService.Classes.Location
--
-- A place players can be: the lobby, or one of the checkpoints. It reads its
-- pieces from the map. Pieces that aren't built yet are nil, and a warning in
-- Output says what's missing.
--
-- Map contract (a Folder or Model: Workspace.Map.Lobby, or Workspace.Map.Checkpoints.<Id>):
--   Spawn   BasePart   where players appear when they teleport here or respawn
--   Launch  BasePart   where boats from these docks appear in the river (they take its position and rotation)
--   Docks   Folder     one Model per dock (see the Dock class)
--   Zone    BasePart   checkpoints only: a launched boat whose middle is inside it has reached the checkpoint

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CheckpointConfig = require(ReplicatedStorage.Shared.Modules.Game.CheckpointConfig)
local DockServiceShared = require(ReplicatedStorage.Shared.Services.DockService.DockServiceShared)
local Geometry = require(ReplicatedStorage.Shared.Modules.Math.Geometry)

local Location = {}
Location.__index = Location

type LocationMembers = {
	Id: string,
	DisplayName: string,
	Index: number, -- 0 for the lobby, then 1, 2, 3... in the order the river reaches them
	Spawn: BasePart?,
	Launch: BasePart?,
	Zone: BasePart?,
	DockModels: { Model },
}

export type Location = typeof(setmetatable({} :: LocationMembers, Location))

local function FindPart(folder: Instance, name: string, path: string): BasePart?
	local part = folder:FindFirstChild(name)
	if part and part:IsA("BasePart") then
		return part
	end
	warn(`Map piece missing: {path}.{name} (a Part)`)
	return nil
end

local function FindDockModels(folder: Instance, path: string): { Model }
	local dockModels = {}
	local docksFolder = folder:FindFirstChild(DockServiceShared.DOCKS_FOLDER_NAME)
	if not docksFolder then
		warn(`Map piece missing: {path}.{DockServiceShared.DOCKS_FOLDER_NAME} (a Folder of dock Models)`)
		return dockModels
	end
	for _, child in docksFolder:GetChildren() do
		if child:IsA("Model") then
			table.insert(dockModels, child)
		end
	end
	return dockModels
end

-- `folder` is the location's folder in the map, or nil if it hasn't been built yet.
-- `path` is where it should be, for warning messages.
function Location.new(id: string, displayName: string, index: number, folder: Instance?, path: string): Location
	local spawnPart, launchPart, zonePart = nil, nil, nil
	local dockModels = {}
	if folder then
		spawnPart = FindPart(folder, "Spawn", path)
		launchPart = FindPart(folder, "Launch", path)
		zonePart = if index > 0 then FindPart(folder, "Zone", path) else nil
		dockModels = FindDockModels(folder, path)
	else
		warn(`Map piece missing: {path} (a Folder)`)
	end

	return setmetatable(
		{
			Id = id,
			DisplayName = displayName,
			Index = index,
			Spawn = spawnPart,
			Launch = launchPart,
			Zone = zonePart,
			DockModels = dockModels,
		} :: LocationMembers,
		Location
	)
end

-- Where a player should stand when they arrive here, or nil if Spawn isn't built.
function Location.GetSpawnCFrame(self: Location): CFrame?
	local spawnPart = self.Spawn
	if not spawnPart then
		return nil
	end
	return spawnPart.CFrame + Vector3.new(0, CheckpointConfig.SPAWN_HEIGHT, 0)
end

-- Whether a point is inside this checkpoint's Zone. Always false for the lobby.
function Location.IsInZone(self: Location, point: Vector3): boolean
	local zonePart = self.Zone
	return zonePart ~= nil and Geometry.IsPointInPart(point, zonePart)
end

return Location
