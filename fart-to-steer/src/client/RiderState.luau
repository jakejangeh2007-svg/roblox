--!strict
-- Answers "is the local player sitting on a boat, and where?"

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local RiderState = {}

-- Returns the boat's root part and this player's seat attachment, or nil while
-- the player isn't seated (or the boat hasn't streamed in yet).
function RiderState.get(): (BasePart?, Attachment?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local boatValue = character:FindFirstChild("RiderBoat")
	local seatIndex = character:GetAttribute("SeatIndex")
	if not (boatValue and boatValue:IsA("ObjectValue") and typeof(seatIndex) == "number") then
		return nil, nil
	end
	local boat = boatValue.Value
	if not (boat and boat:IsA("Model")) then
		return nil, nil
	end
	local root = boat.PrimaryPart
	if not root then
		return nil, nil
	end
	local seat = root:FindFirstChild(`Seat{seatIndex}`)
	if not (seat and seat:IsA("Attachment")) then
		return nil, nil
	end
	return root, seat
end

function RiderState.isSeated(): boolean
	local root = RiderState.get()
	return root ~= nil
end

return RiderState
