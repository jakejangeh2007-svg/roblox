--!strict
-- Keeps boats floating on the course's water parts, slows them down and
-- applies currents. With no water under it, nothing holds a boat up and it
-- falls off the river.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BoatService = require(script.Parent.BoatService)
local Config = require(ReplicatedStorage.Shared.Config)
local Course = require(script.Parent.Course)

local WaterService = {}

function WaterService.start(course: Course.Course)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { course.water }

	RunService.Heartbeat:Connect(function(dt)
		for _, boat in BoatService.boats do
			local root = boat.root
			if root.Anchored then
				continue
			end
			local hit = workspace:Raycast(root.Position + Vector3.new(0, 4, 0), Vector3.new(0, -12, 0), params)
			if not hit then
				continue -- no water underneath: gravity takes over
			end

			-- Spring the boat onto the surface, and cancel gravity while it floats
			local velocity = root.AssemblyLinearVelocity
			local depth = (hit.Position.Y + Config.FLOAT_HEIGHT) - root.Position.Y
			local vy = velocity.Y
				+ (workspace.Gravity + depth * Config.FLOAT_STIFFNESS - velocity.Y * Config.FLOAT_DAMPING) * dt

			-- Slow down toward the speed of the water's current
			local current = hit.Instance:GetAttribute("Current")
			if typeof(current) ~= "Vector3" then
				current = Vector3.zero
			end
			local drag = math.exp(-Config.WATER_DRAG * dt)
			local flat = Vector3.new(velocity.X, 0, velocity.Z) * drag + current * (1 - drag)
			root.AssemblyLinearVelocity = Vector3.new(flat.X, vy, flat.Z)

			local spin = root.AssemblyAngularVelocity
			local tilt = math.exp(-Config.TILT_DRAG * dt)
			root.AssemblyAngularVelocity =
				Vector3.new(spin.X * tilt, spin.Y * math.exp(-Config.SPIN_DRAG * dt), spin.Z * tilt)
		end
	end)
end

return WaterService
