--!strict
-- ModuleScript: ServerScriptService.Services.RiderService.RiderServiceServer
--
-- Slides riders round the edge of their boat. A client asks to slide left or right, or
-- to stop (RequestSlide); the server moves them at a set speed (RiderConfig.SLIDE_SPEED),
-- easing in and out, and never past the ends of their own stretch of the edge (see the
-- Boat class). Where a rider is, and so where their farts push from, is always the
-- server's call. Works the same at the dock and on the river.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local BoatServiceServer = require(ServerScriptService.Services.BoatService.BoatServiceServer)
local Remotes = require(ReplicatedStorage.Shared.Modules.Core.Remotes)
local RiderConfig = require(ReplicatedStorage.Shared.Modules.Game.RiderConfig)
local RiderServiceShared = require(ReplicatedStorage.Shared.Services.RiderService.RiderServiceShared)

local MIN_SLIDE_SPEED = 0.01 -- a slide that has eased below this (studs/s) has stopped
local MIN_TURN_RADIUS = 1 -- a rider this close to the middle (studs) turns on the spot as if this far out

local RiderServiceServer = {}

type RiderServiceServerMembers = {
	SlideInputs: { [Player]: number }, -- -1 for each rider asking to slide left, 1 for right (missing = neither)
	SlideSpeeds: { [Player]: number }, -- how fast each rider is sliding (studs/s, positive is to their right)
}

export type RiderServiceServer = typeof(RiderServiceServer) & RiderServiceServerMembers

function RiderServiceServer.Init(self: RiderServiceServer)
	self.SlideInputs = {}
	self.SlideSpeeds = {}

	Remotes.CreateEvent(RiderServiceShared.SERVICE_NAME, RiderServiceShared.REQUEST_SLIDE).OnServerEvent
		:Connect(function(player: Player, direction: unknown)
			self:HandleSlideRequest(player, direction)
		end)
	Players.PlayerRemoving:Connect(function(player)
		self:ForgetRider(player)
	end)
	RunService.Heartbeat:Connect(function(deltaTime)
		self:Update(deltaTime)
	end)
end

-- Client request: slide left (-1), right (1) or stop (0).
function RiderServiceServer.HandleSlideRequest(self: RiderServiceServer, player: Player, direction: unknown)
	if direction == 0 then
		self.SlideInputs[player] = nil
	elseif direction == -1 or direction == 1 then
		self.SlideInputs[player] = direction :: number
	end
end

function RiderServiceServer.ForgetRider(self: RiderServiceServer, player: Player)
	self.SlideInputs[player] = nil
	self.SlideSpeeds[player] = nil
end

function RiderServiceServer.Update(self: RiderServiceServer, deltaTime: number)
	local sliders: { [Player]: boolean } = {}
	for player in self.SlideInputs do
		sliders[player] = true
	end
	for player in self.SlideSpeeds do
		sliders[player] = true
	end

	local blend = if RiderConfig.SLIDE_RESPONSE_TIME > 0
		then 1 - math.exp(-deltaTime / RiderConfig.SLIDE_RESPONSE_TIME)
		else 1
	for player in sliders do
		local boat, seat = BoatServiceServer:GetRiddenSeat(player)
		if not boat or not seat then
			self:ForgetRider(player)
			continue
		end
		local speed = self.SlideSpeeds[player] or 0
		speed += ((self.SlideInputs[player] or 0) * RiderConfig.SLIDE_SPEED - speed) * blend
		local radius = math.max(boat:GetRiderRadius(seat), MIN_TURN_RADIUS)
		local angle = boat:GetRiderSlide(seat) + speed / radius * deltaTime

		local minAngle, maxAngle = boat:GetSlideRange(seat)
		if minAngle and maxAngle then
			-- Stopped by the blockers at the ends of their stretch
			if angle <= minAngle or angle >= maxAngle then
				angle = math.clamp(angle, minAngle, maxAngle)
				speed = 0
			end
		else
			-- All the way round: keep the angle between -pi and pi.
			angle = (angle + math.pi) % (2 * math.pi) - math.pi
		end

		if self.SlideInputs[player] or math.abs(speed) >= MIN_SLIDE_SPEED then
			self.SlideSpeeds[player] = speed
		else
			self.SlideSpeeds[player] = nil
		end
		boat:SetRiderSlide(seat, angle)
	end
end

return RiderServiceServer :: RiderServiceServer
