--[[
	PROJECT SETUP: run this once in Roblox Studio.

	1. Open your place in Studio.
	2. Open the Command Bar: View tab -> Command Bar.
	3. Paste this whole script into the Command Bar and press Enter.

	It creates the project's folder structure, the Server and Client startup
	scripts, and the UI initializer module. Anything that already exists is left
	alone, so running it twice is safe. Ctrl+Z undoes it.

	The three scripts below are copies of Server.luau, Client.luau and UI.luau
	in this folder of the repo.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local SERVER_SOURCE = [==[
--!strict
-- Script: ServerScriptService.Server
--
-- Server startup. Requires the server half of every service and calls its Init.
-- A service is a folder in ServerScriptService.Services named <X>Service, and its
-- server half is the ModuleScript <X>ServiceServer inside that folder. Services
-- with no server half are skipped.
--
-- Services start in alphabetical order. To start one before the rest, add its
-- folder name to START_FIRST. If its Init takes parameters, add its folder name
-- to START_MANUALLY and call its Init by hand at the bottom of this script.

local ServerScriptService = game:GetService("ServerScriptService")

local START_FIRST: { string } = {}
local START_MANUALLY: { string } = {}

local servicesFolder = ServerScriptService.Services

local function StartService(serviceFolder: Instance)
	local serverModule = serviceFolder:FindFirstChild(serviceFolder.Name .. "Server")
	if not serverModule or not serverModule:IsA("ModuleScript") then
		return
	end
	local service = require(serverModule) :: any
	if type(service) == "table" and type(service.Init) == "function" then
		service.Init(service)
	end
end

local function StartServices()
	for _, serviceName in START_FIRST do
		local serviceFolder = servicesFolder:FindFirstChild(serviceName)
		assert(
			serviceFolder,
			`START_FIRST has "{serviceName}", but ServerScriptService.Services has no folder by that name`
		)
		StartService(serviceFolder)
	end

	local serviceFolders = servicesFolder:GetChildren()
	table.sort(serviceFolders, function(first, second)
		return first.Name < second.Name
	end)
	for _, serviceFolder in serviceFolders do
		local serviceName = serviceFolder.Name
		if not table.find(START_FIRST, serviceName) and not table.find(START_MANUALLY, serviceName) then
			StartService(serviceFolder)
		end
	end
end

StartServices()

-- Services listed in START_MANUALLY start here, in order. For example:
-- local ExampleServiceServer = require(servicesFolder.ExampleService.ExampleServiceServer)
-- ExampleServiceServer.Init(ExampleServiceServer, someParameter)
]==]

local CLIENT_SOURCE = [==[
--!strict
-- LocalScript: StarterPlayer.StarterPlayerScripts.Client
--
-- Client startup. Waits for the game to finish loading, requires the client half
-- of every service and calls its Init, then starts the UI. A service is a folder in
-- ReplicatedStorage.Shared.Services named <X>Service, and its client half is the
-- ModuleScript <X>ServiceClient inside that folder. Services with no client half
-- are skipped.
--
-- Services start in alphabetical order. To start one before the rest, add its
-- folder name to START_FIRST. If its Init takes parameters, add its folder name
-- to START_MANUALLY and call its Init by hand near the bottom of this script.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local START_FIRST: { string } = {}
local START_MANUALLY: { string } = {}

local servicesFolder = ReplicatedStorage.Shared.Services

local function StartService(serviceFolder: Instance)
	local clientModule = serviceFolder:FindFirstChild(serviceFolder.Name .. "Client")
	if not clientModule or not clientModule:IsA("ModuleScript") then
		return
	end
	local service = require(clientModule) :: any
	if type(service) == "table" and type(service.Init) == "function" then
		service.Init(service)
	end
end

local function StartServices()
	for _, serviceName in START_FIRST do
		local serviceFolder = servicesFolder:FindFirstChild(serviceName)
		assert(
			serviceFolder,
			`START_FIRST has "{serviceName}", but ReplicatedStorage.Shared.Services has no folder by that name`
		)
		StartService(serviceFolder)
	end

	local serviceFolders = servicesFolder:GetChildren()
	table.sort(serviceFolders, function(first, second)
		return first.Name < second.Name
	end)
	for _, serviceFolder in serviceFolders do
		local serviceName = serviceFolder.Name
		if not table.find(START_FIRST, serviceName) and not table.find(START_MANUALLY, serviceName) then
			StartService(serviceFolder)
		end
	end
end

StartServices()

-- Services listed in START_MANUALLY start here, in order. For example:
-- local ExampleServiceClient = require(servicesFolder.ExampleService.ExampleServiceClient)
-- ExampleServiceClient.Init(ExampleServiceClient, someParameter)

-- The UI starts last, once every client service is ready.
local UI = require(ReplicatedStorage.UI)
UI.Init(UI)
]==]

local UI_SOURCE = [==[
--!strict
-- ModuleScript: ReplicatedStorage.UI
--
-- Top-level UI initializer. The Client startup script calls UI.Init after every
-- client service has started. UI.Init requires each feature module inside the
-- interface folders under this module (HUD, Menus, ...) and calls its Init if it
-- has one.
--
-- All UI is built by hand in Studio. Feature modules only wire up what's already there.

local UI = {}

-- Member variables go here.
type UIMembers = {}

export type UI = typeof(UI) & UIMembers

local function SortedChildren(parent: Instance): { Instance }
	local children = parent:GetChildren()
	table.sort(children, function(first, second)
		return first.Name < second.Name
	end)
	return children
end

local function StartFeature(featureModule: ModuleScript)
	local feature = require(featureModule) :: any
	if type(feature) == "table" and type(feature.Init) == "function" then
		feature.Init(feature)
	end
end

function UI.Init(self: UI)
	for _, interfaceFolder in SortedChildren(script) do
		for _, featureModule in SortedChildren(interfaceFolder) do
			if featureModule:IsA("ModuleScript") then
				StartFeature(featureModule)
			end
		end
	end
end

return UI :: UI
]==]

local createdPaths: { string } = {}
local existingPaths: { string } = {}

-- Returns the child called `name`, creating it first if it doesn't exist.
local function GetOrCreate(parent: Instance, className: string, name: string, source: string?): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		local existingPath = existing:GetFullName()
		if existing.ClassName ~= className then
			warn(`{existingPath} is a {existing.ClassName}, expected a {className}. Left it as it is.`)
		end
		table.insert(existingPaths, existingPath)
		return existing
	end
	local instance = Instance.new(className)
	instance.Name = name
	if source then
		(instance :: any).Source = source
	end
	instance.Parent = parent
	table.insert(createdPaths, instance:GetFullName())
	return instance
end

local recording = ChangeHistoryService:TryBeginRecording("Create project structure")

-- ReplicatedStorage
local shared = GetOrCreate(ReplicatedStorage, "Folder", "Shared")
GetOrCreate(shared, "Folder", "Services")
GetOrCreate(shared, "Folder", "Classes")
local modules = GetOrCreate(shared, "Folder", "Modules")
for _, folderName in { "Core", "Game", "Math", "Platform" } do
	GetOrCreate(modules, "Folder", folderName)
end
GetOrCreate(ReplicatedStorage, "Folder", "Assets")
local userInterface = GetOrCreate(ReplicatedStorage, "ModuleScript", "UI", UI_SOURCE)
GetOrCreate(userInterface, "Folder", "HUD")
GetOrCreate(userInterface, "Folder", "Menus")
GetOrCreate(ReplicatedStorage, "Folder", "Packages")

-- ServerScriptService
GetOrCreate(ServerScriptService, "Script", "Server", SERVER_SOURCE)
GetOrCreate(ServerScriptService, "Folder", "Services")
GetOrCreate(ServerScriptService, "Folder", "Classes")

-- StarterPlayerScripts
local starterPlayerScripts = StarterPlayer:FindFirstChildOfClass("StarterPlayerScripts")
	or GetOrCreate(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts")
GetOrCreate(starterPlayerScripts, "LocalScript", "Client", CLIENT_SOURCE)

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end

print(`Project setup done: created {#createdPaths}, already existed {#existingPaths}.`)
for _, path in createdPaths do
	print(`  + {path}`)
end
for _, path in existingPaths do
	print(`  = {path} (already existed, not changed)`)
end
