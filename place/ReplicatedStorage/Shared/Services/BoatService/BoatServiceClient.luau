--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.BoatService.BoatServiceClient
--
-- The client half of BoatService. While the local player sits in a boat that has
-- left the dock, jumping is switched off so they don't fall out by accident.
-- (The server still handles anyone who does leave.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BoatServiceShared = require(ReplicatedStorage.Shared.Services.BoatService.BoatServiceShared)

local BoatServiceClient = {}

type BoatServiceClientMembers = {
	LockedHumanoid: Humanoid?, -- the humanoid whose jumping is currently switched off
}

export type BoatServiceClient = typeof(BoatServiceClient) & BoatServiceClientMembers

-- The spawned boat model a seat belongs to, if any.
local function FindBoatModel(seat: BasePart): Model?
	local boatsFolder = workspace:FindFirstChild(BoatServiceShared.BOATS_FOLDER_NAME) or workspace
	local ancestor: Instance? = seat
	while ancestor and ancestor.Parent ~= boatsFolder do
		ancestor = ancestor.Parent
	end
	return if ancestor and ancestor:IsA("Model") then ancestor else nil
end

function BoatServiceClient.Init(self: BoatServiceClient)
	self.LockedHumanoid = nil
	RunService.Heartbeat:Connect(function()
		self:UpdateJumpLock()
	end)
end

function BoatServiceClient.UpdateJumpLock(self: BoatServiceClient)
	local character = Players.LocalPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local seat = if humanoid then humanoid.SeatPart else nil
	local boatModel = if seat then FindBoatModel(seat) else nil
	local isOnRiver = boatModel ~= nil and boatModel:GetAttribute(BoatServiceShared.STATE_ATTRIBUTE) == "Launched"
	local humanoidToLock = if isOnRiver then humanoid else nil

	if humanoidToLock == self.LockedHumanoid then
		return
	end
	local previousHumanoid = self.LockedHumanoid
	if previousHumanoid then
		previousHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end
	if humanoidToLock then
		humanoidToLock:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	end
	self.LockedHumanoid = humanoidToLock
end

return BoatServiceClient :: BoatServiceClient
