--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.BoatService.BoatServiceShared
--
-- Names and helpers both halves of BoatService (and other services) agree on.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoatConfig = require(ReplicatedStorage.Shared.Modules.Game.BoatConfig)

export type BoatState = "Docked" | "Launched" | "Destroyed"
export type WipeReason = "Fell" | "Popped" -- fell off the river, or a hazard popped it

local BoatServiceShared = {
	SERVICE_NAME = "BoatService",
	BOATS_FOLDER_NAME = "Boats", -- Workspace.Boats holds every spawned boat
	TEMPLATES_FOLDER_NAME = "Boats", -- ReplicatedStorage.Assets.Boats holds the boat templates
	COLLISION_GROUP = "Boats", -- boats pass through each other
	RIDER_COLLISION_GROUP = "Riders", -- riders on the river don't bump into anything; only their boat does

	-- Attributes on each spawned boat model, for clients and UI
	STATE_ATTRIBUTE = "State", -- a BoatState
	LEADER_ATTRIBUTE = "LeaderUserId", -- UserId of the party leader
	DEPARTURE_TIME_ATTRIBUTE = "DepartureTime", -- server time (workspace:GetServerTimeNow()) a docked boat leaves

	-- Remotes
	NOTIFY_BOAT_WIPED = "NotifyBoatWiped", -- RemoteEvent to each crew member when their boat is out of the run (reason: WipeReason)
	REQUEST_JOIN_BOAT = "RequestJoinBoat", -- RemoteFunction (boat: Model) -> (success: boolean, message: string?)
	REQUEST_START_RUN = "RequestStartRun", -- RemoteFunction () -> (success: boolean, message: string?); party leader only
}

-- The spawned boat model a part belongs to (for example a Seat), if any.
function BoatServiceShared.GetBoatModelFromPart(part: Instance): Model?
	local boatsFolder = workspace:FindFirstChild(BoatServiceShared.BOATS_FOLDER_NAME) or workspace
	local ancestor: Instance? = part
	while ancestor and ancestor.Parent ~= boatsFolder do
		ancestor = ancestor.Parent
	end
	return if ancestor and ancestor:IsA("Model") then ancestor else nil
end

-- Which way a rider faces, flat on the water: toward the middle of the boat. A rider
-- in a middle seat (like a one-seat boat) faces the way their seat faces.
function BoatServiceShared.GetRiderFacing(boatPosition: Vector3, seatCFrame: CFrame): Vector3
	local towardMiddle = (boatPosition - seatCFrame.Position) * Vector3.new(1, 0, 1)
	if towardMiddle.Magnitude >= BoatConfig.CENTER_SEAT_RADIUS then
		return towardMiddle.Unit
	end
	local seatFacing = seatCFrame.LookVector * Vector3.new(1, 0, 1)
	return if seatFacing.Magnitude > 0 then seatFacing.Unit else -Vector3.zAxis
end

return BoatServiceShared
