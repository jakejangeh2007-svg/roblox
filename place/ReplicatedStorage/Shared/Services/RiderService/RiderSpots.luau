--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.RiderService.RiderSpots
--
-- Where riders hang on round a boat, and how they slide round its edge. Pure math, shared
-- by the server (which decides where every rider is) and the client (which shows its own
-- player's slide straight away, without waiting for the server, using the same rules).
--
-- Each seat's rider hangs at RiderConfig.HANG_OFFSET from it and slides round a circle
-- about the boat's PrimaryPart. The edge is shared out between the seats: each rider
-- gets from their seat halfway to the next seat each way, less RIDER_SPACING so
-- neighbours never overlap. A lone seat's rider can go all the way round. Slide angles
-- are in radians round from the seat; positive is to the rider's right as they face the
-- middle of the boat.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RiderConfig = require(ReplicatedStorage.Shared.Modules.Game.RiderConfig)

-- Where a rider hangs on from one seat, and how far round the edge they can slide.
export type RiderSpot = {
	SeatCFrame: CFrame, -- the seat, in the PrimaryPart's space
	HangCFrame: CFrame, -- the rider's HumanoidRootPart right at the seat, in the PrimaryPart's space
	Radius: number, -- how far that is from the PrimaryPart, flat (studs)
	MinAngle: number?, -- how far they can slide to their left (negative)...
	MaxAngle: number?, -- ...and to their right. Both nil: all the way round.
}

local FULL_TURN = 2 * math.pi
local MIN_SLIDE_RADIUS = 1 -- a rider this close to the middle (studs) turns on the spot as if this far out

local RiderSpots = {}

-- The spot for each of `seats` on a boat whose PrimaryPart is at `primaryCFrame`.
function RiderSpots.GetSpots(primaryCFrame: CFrame, seats: { BasePart }): { [BasePart]: RiderSpot }
	local spots: { [BasePart]: RiderSpot } = {}
	local angles: { [BasePart]: number } = {}
	for _, seat in seats do
		local seatCFrame = primaryCFrame:ToObjectSpace(seat.CFrame)
		local hangCFrame = seatCFrame * RiderConfig.HANG_OFFSET
		spots[seat] = {
			SeatCFrame = seatCFrame,
			HangCFrame = hangCFrame,
			Radius = Vector3.new(hangCFrame.X, 0, hangCFrame.Z).Magnitude,
			MinAngle = nil,
			MaxAngle = nil,
		}
		-- Measured the way CFrame.Angles(0, angle, 0) turns things: from +Z toward +X.
		angles[seat] = math.atan2(hangCFrame.X, hangCFrame.Z)
	end
	if #seats < 2 then
		return spots
	end

	local seatsInOrder = table.clone(seats)
	table.sort(seatsInOrder, function(first, second)
		return angles[first] < angles[second]
	end)
	for index, seat in seatsInOrder do
		local previousSeat = seatsInOrder[(index - 2) % #seatsInOrder + 1]
		local nextSeat = seatsInOrder[index % #seatsInOrder + 1]
		local gapBefore = (angles[seat] - angles[previousSeat]) % FULL_TURN
		local gapAfter = (angles[nextSeat] - angles[seat]) % FULL_TURN
		local spot = spots[seat]
		local spacing = if spot.Radius > 0 then RiderConfig.RIDER_SPACING / 2 / spot.Radius else 0
		spot.MinAngle = -math.max(0, gapBefore / 2 - spacing)
		spot.MaxAngle = math.max(0, gapAfter / 2 - spacing)
	end
	return spots
end

-- The SeatWeld C0 that hangs a rider `angle` round the edge from `spot`'s seat (with C1
-- left at identity). Roblox's own weld would sit them on the seat.
function RiderSpots.GetSeatWeldC0(spot: RiderSpot, angle: number): CFrame
	return spot.SeatCFrame:Inverse() * CFrame.Angles(0, angle, 0) * spot.HangCFrame
end

-- The slide angle along `spot`'s stretch of the edge that hangs a rider closest to
-- `position` (in the PrimaryPart's space), and how far (studs) `position` is from where
-- that would hang them. Used to grab back on after being knocked off.
function RiderSpots.GetClosestSlide(spot: RiderSpot, position: Vector3): (number, number)
	local seatAngle = math.atan2(spot.HangCFrame.X, spot.HangCFrame.Z)
	local angle = RiderSpots.GetAngleDifference(seatAngle, math.atan2(position.X, position.Z))
	local minAngle, maxAngle = spot.MinAngle, spot.MaxAngle
	if minAngle and maxAngle then
		angle = math.clamp(angle, minAngle, maxAngle)
	end
	local hangPosition = (CFrame.Angles(0, angle, 0) * spot.HangCFrame).Position
	return angle, (position - hangPosition).Magnitude
end

-- The shortest way round from angle `from` to angle `to` (radians, -pi to pi).
function RiderSpots.GetAngleDifference(from: number, to: number): number
	return (to - from + math.pi) % FULL_TURN - math.pi
end

-- One step of a rider sliding round the edge from `spot`'s seat: `angle` (radians) and
-- `speed` (studs/s, positive to their right) `deltaTime` seconds later, while they slide
-- `direction` (-1 left, 1 right, 0 not at all). Speeds up and slows down smoothly, eases
-- into the blockers at the ends of their stretch, and never goes past them.
function RiderSpots.StepSlide(
	spot: RiderSpot,
	angle: number,
	speed: number,
	direction: number,
	deltaTime: number
): (number, number)
	local radius = math.max(spot.Radius, MIN_SLIDE_RADIUS)
	local minAngle, maxAngle = spot.MinAngle, spot.MaxAngle

	local targetSpeed = direction * RiderConfig.SLIDE_SPEED
	if minAngle and maxAngle and RiderConfig.SLIDE_SOFT_END > 0 and targetSpeed ~= 0 then
		-- Slow down near the blocker ahead (but still reach it).
		local studsToEnd = if targetSpeed > 0 then (maxAngle - angle) * radius else (angle - minAngle) * radius
		local slowdown = math.clamp(studsToEnd / RiderConfig.SLIDE_SOFT_END, RiderConfig.SLIDE_END_SPEED, 1)
		targetSpeed *= slowdown
	end
	local blend = if RiderConfig.SLIDE_RESPONSE_TIME > 0
		then 1 - math.exp(-deltaTime / RiderConfig.SLIDE_RESPONSE_TIME)
		else 1
	speed += (targetSpeed - speed) * blend
	angle += speed / radius * deltaTime

	if minAngle and maxAngle then
		if angle <= minAngle or angle >= maxAngle then
			angle = math.clamp(angle, minAngle, maxAngle)
			speed = 0
		end
	else
		angle = RiderSpots.GetAngleDifference(0, angle)
	end
	return angle, speed
end

return RiderSpots
