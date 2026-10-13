--!strict
-- ModuleScript: ReplicatedStorage.Shared.Modules.Core.Remotes
--
-- Remotes are made in code, never by hand. The server half of a service creates
-- them in a "Remotes" folder inside that service's folder in
-- ReplicatedStorage.Shared.Services. The client half waits for them by name.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTES_FOLDER_NAME = "Remotes"

local Remotes = {}

local function GetOrCreateRemotesFolder(serviceName: string): Instance
	local serviceFolder = ReplicatedStorage.Shared.Services:FindFirstChild(serviceName)
	assert(serviceFolder, `ReplicatedStorage.Shared.Services has no {serviceName} folder`)
	local remotesFolder = serviceFolder:FindFirstChild(REMOTES_FOLDER_NAME)
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = REMOTES_FOLDER_NAME
		remotesFolder.Parent = serviceFolder
	end
	return remotesFolder
end

local function Create(serviceName: string, className: string, remoteName: string): Instance
	assert(RunService:IsServer(), "Only the server creates remotes")
	local remotesFolder = GetOrCreateRemotesFolder(serviceName)
	assert(not remotesFolder:FindFirstChild(remoteName), `{serviceName} already has a remote named {remoteName}`)
	local remote = Instance.new(className)
	remote.Name = remoteName
	remote.Parent = remotesFolder
	return remote
end

local function WaitFor(serviceName: string, remoteName: string): Instance
	local serviceFolder = ReplicatedStorage.Shared.Services:WaitForChild(serviceName)
	return serviceFolder:WaitForChild(REMOTES_FOLDER_NAME):WaitForChild(remoteName)
end

function Remotes.CreateEvent(serviceName: string, remoteName: string): RemoteEvent
	return Create(serviceName, "RemoteEvent", remoteName) :: RemoteEvent
end

function Remotes.CreateFunction(serviceName: string, remoteName: string): RemoteFunction
	return Create(serviceName, "RemoteFunction", remoteName) :: RemoteFunction
end

-- Waits until the server has created the remote. Use it from the client only.
function Remotes.WaitForEvent(serviceName: string, remoteName: string): RemoteEvent
	local remote = WaitFor(serviceName, remoteName)
	assert(remote:IsA("RemoteEvent"), `{serviceName}.{remoteName} is not a RemoteEvent`)
	return remote
end

-- Waits until the server has created the remote. Use it from the client only.
function Remotes.WaitForFunction(serviceName: string, remoteName: string): RemoteFunction
	local remote = WaitFor(serviceName, remoteName)
	assert(remote:IsA("RemoteFunction"), `{serviceName}.{remoteName} is not a RemoteFunction`)
	return remote
end

return Remotes
