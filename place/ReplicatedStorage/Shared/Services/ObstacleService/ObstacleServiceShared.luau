--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.ObstacleService.ObstacleServiceShared
--
-- Names the obstacle system and the map agree on (see ObstacleServiceServer for how to
-- build obstacles).

export type ObstacleType = "Spinner" | "Swinger" | "Slider" | "WindFan"

local ObstacleServiceShared = {
	OBSTACLES_FOLDER_NAME = "Obstacles", -- Workspace.Map.Obstacles holds every obstacle, or a marker for one
	TEMPLATES_FOLDER_NAME = "Obstacles", -- ReplicatedStorage.Assets.Obstacles holds obstacle templates
	COLLISION_GROUP = "Obstacles", -- obstacles' fixed and moving parts: they hit boats and nothing else

	-- Attributes
	TYPE_ATTRIBUTE = "Obstacle", -- on an obstacle Model: an ObstacleType
	TEMPLATE_ATTRIBUTE = "ObstacleTemplate", -- on a marker: the template in Assets.Obstacles to put there
	HAZARD_ATTRIBUTE = "Hazard", -- true on any part in the map that pops a boat that touches it
	BLOWING_ATTRIBUTE = "Blowing", -- on a WindFan, kept up to date by the server: true while it blows

	-- Parts inside an obstacle Model
	BASE_NAME = "Base", -- the fixed part it moves around or along
	MOVING_NAME = "Moving", -- the part that moves; everything else that moves is welded to it
	WIND_NAME = "Wind", -- a WindFan's wind zone
}

-- Whether `value` is the name of a kind of obstacle.
function ObstacleServiceShared.IsObstacleType(value: unknown): boolean
	return value == "Spinner" or value == "Swinger" or value == "Slider" or value == "WindFan"
end

return ObstacleServiceShared
