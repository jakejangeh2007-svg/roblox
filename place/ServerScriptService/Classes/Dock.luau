--!strict
-- ModuleScript: ServerScriptService.Classes.Dock
--
-- One dock that players spawn boats from. It belongs to a Location (the lobby or a checkpoint).
--
-- Map contract (a Model inside a location's Docks folder):
--   BoatSpawn         BasePart          where a spawned boat waits while players get in.
--                                       The boat takes this part's position and rotation.
--   SpawnBoatPrompt   ProximityPrompt   anywhere inside the dock model; players use it to
--                                       open the boat menu

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Boat = require(ServerScriptService.Classes.Boat)
local DockServiceShared = require(ReplicatedStorage.Shared.Services.DockService.DockServiceShared)
local Location = require(ServerScriptService.Classes.Location)

local Dock = {}
Dock.__index = Dock

type DockMembers = {
	Model: Model,
	Location: Location.Location,
	BoatSpawn: BasePart?,
	Boat: Boat.Boat?, -- the boat that most recently spawned here
}

export type Dock = typeof(setmetatable({} :: DockMembers, Dock))

function Dock.new(model: Model, location: Location.Location): Dock
	local path = model:GetFullName()
	local boatSpawn = model:FindFirstChild("BoatSpawn")
	if not boatSpawn or not boatSpawn:IsA("BasePart") then
		warn(`Map piece missing: {path}.BoatSpawn (a Part)`)
		boatSpawn = nil
	end
	local prompt = model:FindFirstChild(DockServiceShared.SPAWN_BOAT_PROMPT_NAME, true)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		warn(`Map piece missing: a ProximityPrompt named {DockServiceShared.SPAWN_BOAT_PROMPT_NAME} inside {path}`)
	end

	return setmetatable(
		{
			Model = model,
			Location = location,
			BoatSpawn = boatSpawn,
			Boat = nil,
		} :: DockMembers,
		Dock
	)
end

-- A dock is free when no boat is waiting at it.
function Dock.IsFree(self: Dock): boolean
	local boat = self.Boat
	return boat == nil or not boat:IsAtDock()
end

return Dock
