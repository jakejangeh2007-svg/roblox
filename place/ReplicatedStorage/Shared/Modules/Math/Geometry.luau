--!strict
-- ModuleScript: ReplicatedStorage.Shared.Modules.Math.Geometry

local Geometry = {}

-- Whether a point is inside a part's box, taking its size and rotation into account.
function Geometry.IsPointInPart(point: Vector3, part: BasePart): boolean
	local relative = part.CFrame:PointToObjectSpace(point)
	local halfSize = part.Size / 2
	return math.abs(relative.X) <= halfSize.X
		and math.abs(relative.Y) <= halfSize.Y
		and math.abs(relative.Z) <= halfSize.Z
end

return Geometry
