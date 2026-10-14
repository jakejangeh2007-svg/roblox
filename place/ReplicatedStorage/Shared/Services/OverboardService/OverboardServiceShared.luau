--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.OverboardService.OverboardServiceShared
--
-- Names and helpers both halves of OverboardService (and other services) agree on.

export type OverboardState = "KnockedOut" | "Swimming" -- limp in the water, or swimming back to their boat
export type LeftBehindReason = "TooLong" | "Fell" -- ran out of time to get back aboard, or fell off the river

local OverboardServiceShared = {
	SERVICE_NAME = "OverboardService",
	COLLISION_GROUP = "Swimmers", -- overboard players bump into the map and obstacles, but not boats or each other

	-- Attributes on each Player, kept up to date by the server, for clients and UI
	STATE_ATTRIBUTE = "Overboard", -- an OverboardState while they're off their boat (missing = aboard, or not on the river)
	WAKE_TIME_ATTRIBUTE = "WakeTime", -- server time (workspace:GetServerTimeNow()) a knocked-out player comes round
	GIVE_UP_TIME_ATTRIBUTE = "GiveUpTime", -- server time a swimmer is sent back to their checkpoint if they're not aboard

	-- Remotes
	REQUEST_SWIM_TURN = "RequestSwimTurn", -- RemoteEvent client -> server (direction: number): -1 turn left, 1 turn right, 0 stop turning
	NOTIFY_LEFT_BEHIND = "NotifyLeftBehind", -- RemoteEvent to a swimmer sent back to their checkpoint (reason: LeftBehindReason)
}

-- Whether `player` is overboard right now, and how.
function OverboardServiceShared.GetState(player: Player): OverboardState?
	local state = player:GetAttribute(OverboardServiceShared.STATE_ATTRIBUTE)
	if state == "KnockedOut" then
		return "KnockedOut"
	elseif state == "Swimming" then
		return "Swimming"
	end
	return nil
end

return OverboardServiceShared
