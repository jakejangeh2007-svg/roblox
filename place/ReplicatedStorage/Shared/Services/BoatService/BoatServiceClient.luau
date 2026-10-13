--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.BoatService.BoatServiceClient
--
-- The client half of BoatService.
--   - While the local player sits in a boat on the river, jumping is switched off so
--     they don't fall out by accident. (The server still handles anyone who leaves.)
--   - BoatWiped fires when their boat falls off the river, for the UI (a RIP screen).
--   - RequestJoinBoat, RequestStartRun, IsLeaderOf and GetSecondsUntilDeparture are for
--     the joining UI (to be built): a Join button, the leader's Start button and the timer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BoatServiceShared = require(ReplicatedStorage.Shared.Services.BoatService.BoatServiceShared)
local Remotes = require(ReplicatedStorage.Shared.Modules.Core.Remotes)
local Signal = require(ReplicatedStorage.Packages.Signal)

local BoatServiceClient = {}

type BoatServiceClientMembers = {
	LockedHumanoid: Humanoid?, -- the humanoid whose jumping is currently switched off
	BoatWiped: Signal.Signal, -- fires () when the local player's boat falls off the river
}

export type BoatServiceClient = typeof(BoatServiceClient) & BoatServiceClientMembers

function BoatServiceClient.Init(self: BoatServiceClient)
	self.LockedHumanoid = nil
	self.BoatWiped = Signal.new()

	RunService.Heartbeat:Connect(function()
		self:UpdateJumpLock()
	end)

	-- Remotes are waited for in a separate thread so Init never yields.
	task.spawn(function()
		Remotes.WaitForEvent(BoatServiceShared.SERVICE_NAME, BoatServiceShared.NOTIFY_BOAT_WIPED).OnClientEvent
			:Connect(function()
				self.BoatWiped:Fire()
			end)
	end)
end

function BoatServiceClient.UpdateJumpLock(self: BoatServiceClient)
	local character = Players.LocalPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local seat = if humanoid then humanoid.SeatPart else nil
	local boatModel = if seat then BoatServiceShared.GetBoatModelFromPart(seat) else nil
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

-- Asks to sit in a free seat of `boatModel`, a boat waiting at a dock.
-- Returns whether it worked and, if not, a message to show the player.
function BoatServiceClient.RequestJoinBoat(self: BoatServiceClient, boatModel: Model): (boolean, string?)
	local remote = Remotes.WaitForFunction(BoatServiceShared.SERVICE_NAME, BoatServiceShared.REQUEST_JOIN_BOAT)
	local success, message = remote:InvokeServer(boatModel)
	return success == true, if type(message) == "string" then message else nil
end

-- Party leader only: start the run now instead of waiting for the join timer.
-- Returns whether it worked and, if not, a message to show the player.
function BoatServiceClient.RequestStartRun(self: BoatServiceClient): (boolean, string?)
	local remote = Remotes.WaitForFunction(BoatServiceShared.SERVICE_NAME, BoatServiceShared.REQUEST_START_RUN)
	local success, message = remote:InvokeServer()
	return success == true, if type(message) == "string" then message else nil
end

-- Whether the local player leads `boatModel`.
function BoatServiceClient.IsLeaderOf(self: BoatServiceClient, boatModel: Model): boolean
	return boatModel:GetAttribute(BoatServiceShared.LEADER_ATTRIBUTE) == Players.LocalPlayer.UserId
end

-- Seconds until `boatModel` leaves its dock, or nil once it has left.
function BoatServiceClient.GetSecondsUntilDeparture(self: BoatServiceClient, boatModel: Model): number?
	local departureTime = boatModel:GetAttribute(BoatServiceShared.DEPARTURE_TIME_ATTRIBUTE)
	if typeof(departureTime) ~= "number" then
		return nil
	end
	return math.max(0, departureTime - workspace:GetServerTimeNow())
end

return BoatServiceClient :: BoatServiceClient
