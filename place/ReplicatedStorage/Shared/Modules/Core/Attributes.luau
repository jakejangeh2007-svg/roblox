--!strict
-- ModuleScript: ReplicatedStorage.Shared.Modules.Core.Attributes
--
-- Reads settings that designers put on instances as attributes in Studio.

local Attributes = {}

-- `instance`'s number attribute `name`, or `default` if it hasn't got one. Warns (and
-- uses `default`) if it's set to something that isn't a number.
function Attributes.GetNumber(instance: Instance, name: string, default: number): number
	local value = instance:GetAttribute(name)
	if value == nil then
		return default
	end
	if typeof(value) ~= "number" then
		warn(`{instance:GetFullName()} has its {name} attribute set to a {typeof(value)}; it should be a number.`)
		return default
	end
	return value
end

return Attributes
