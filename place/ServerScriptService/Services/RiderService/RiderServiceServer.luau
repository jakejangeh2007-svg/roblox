--!strict
-- ModuleScript: ServerScriptService.Services.RiderService.RiderServiceServer
--
-- Slides riders round the edge of their boat. A client asks to slide left or right, or
-- to stop (RequestSlide); the server moves them at a set speed (RiderConfig.SLIDE_SPEED),
-- easing in and out, and never past the ends of their own stretch of the edge (the rules
-- are in RiderSpots). Where a rider is, and so where their farts push from, is always the
-- server's call; the sliding player's client shows their slide straight away with the
-- same rules, then settles onto the server's answer. Works the same at the dock and on
-- the river.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local BoatServiceServer = require(ServerScriptService.Services.BoatService.BoatServiceServer)
local Remotes = require(ReplicatedStorage.Shared.Modules.Core.Remotes)
local RiderServiceShared = require(ReplicatedStorage.Shared.Services.RiderService.RiderServiceShared)
local RiderSpots = require(ReplicatedStorage.Shared.Services.RiderService.RiderSpots)

local MIN_SLIDE_SPEED = 0.01 -- a slide that has eased below this (studs/s) has stopped

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

	for player in sliders do
		local boat, seat = BoatServiceServer:GetRiddenSeat(player)
		local spot = if boat and seat then boat:GetRiderSpot(seat) else nil
		if not boat or not seat or not spot then
			self:ForgetRider(player)
			continue
		end
		local angle, speed = RiderSpots.StepSlide(
			spot,
			boat:GetRiderSlide(seat),
			self.SlideSpeeds[player] or 0,
			self.SlideInputs[player] or 0,
			deltaTime
		)
		if self.SlideInputs[player] or math.abs(speed) >= MIN_SLIDE_SPEED then
			self.SlideSpeeds[player] = speed
		else
			self.SlideSpeeds[player] = nil
		end
		boat:SetRiderSlide(seat, angle)
	end
end

return RiderServiceServer :: RiderServiceServer
