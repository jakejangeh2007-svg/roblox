--!strict
-- ModuleScript: ReplicatedStorage.Shared.Services.CameraService.CameraServiceClient
--
-- Seat Cam: while the local player rides a boat on the river, the camera sits behind
-- their own seat and looks across the boat. That way Straight always pushes the boat
-- up the screen and Left always turns the view left. Press V (or Y on a controller)
-- to switch to the normal Roblox camera and back.
--
-- The camera rides at the height of the boat's middle, so it bobs gently with the
-- waves but doesn't swing up and down as the boat rocks. A hard bump or a big splash
-- shakes it.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BoatServiceShared = require(ReplicatedStorage.Shared.Services.BoatService.BoatServiceShared)
local CameraConfig = require(ReplicatedStorage.Shared.Modules.Game.CameraConfig)

local localPlayer = Players.LocalPlayer

local CameraServiceClient = {}

type CameraServiceClientMembers = {
	SeatCamEnabled: boolean,
	ShakeAmount: number,
	SmoothedCFrame: CFrame?,
	Random: Random,
	LastBoatModel: Model?, -- the boat the Seat Cam followed last frame...
	LastBoatVelocity: Vector3?, -- ...and how fast it was going, to notice bumps
}

export type CameraServiceClient = typeof(CameraServiceClient) & CameraServiceClientMembers

-- The boat model and seat the local player is riding on the river, if any.
local function GetRiddenSeat(): (Model?, BasePart?)
	local character = localPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local seat = if humanoid then humanoid.SeatPart else nil
	local boatModel = if seat then BoatServiceShared.GetBoatModelFromPart(seat) else nil
	if not seat or not boatModel or boatModel:GetAttribute(BoatServiceShared.STATE_ATTRIBUTE) ~= "Launched" then
		return nil, nil
	end
	return boatModel, seat
end

function CameraServiceClient.Init(self: CameraServiceClient)
	self.SeatCamEnabled = true
	self.ShakeAmount = 0
	self.SmoothedCFrame = nil
	self.Random = Random.new()
	self.LastBoatModel = nil
	self.LastBoatVelocity = nil

	RunService:BindToRenderStep("SeatCam", Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
		self:Update(deltaTime)
	end)
	ContextActionService:BindAction("ToggleSeatCam", function(_actionName, inputState, _input)
		if inputState == Enum.UserInputState.Begin then
			self.SeatCamEnabled = not self.SeatCamEnabled
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.V, Enum.KeyCode.ButtonY)
end

-- Shakes the camera. Bigger numbers shake harder; it dies down by itself.
function CameraServiceClient.Shake(self: CameraServiceClient, amount: number)
	self.ShakeAmount = math.max(self.ShakeAmount, amount)
end

-- Shakes the camera if `boatModel`'s speed changed sharply since last frame.
function CameraServiceClient.ShakeOnImpact(self: CameraServiceClient, boatModel: Model)
	local primaryPart = boatModel.PrimaryPart
	if not primaryPart then
		return
	end
	local velocity = primaryPart.AssemblyLinearVelocity
	local lastVelocity = self.LastBoatVelocity
	if lastVelocity and self.LastBoatModel == boatModel then
		local speedChange = (velocity - lastVelocity).Magnitude
		if speedChange >= CameraConfig.IMPACT_SPEED_CHANGE then
			self:Shake(math.min(CameraConfig.MAX_IMPACT_SHAKE, speedChange * CameraConfig.IMPACT_SHAKE_PER_SPEED))
		end
	end
	self.LastBoatModel = boatModel
	self.LastBoatVelocity = velocity
end

function CameraServiceClient.Update(self: CameraServiceClient, deltaTime: number)
	local camera = workspace.CurrentCamera
	local boatModel, seat = GetRiddenSeat()
	if not self.SeatCamEnabled or not boatModel or not seat then
		if camera.CameraType == Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Custom
		end
		self.SmoothedCFrame = nil
		self.LastBoatModel = nil
		self.LastBoatVelocity = nil
		return
	end
	self:ShakeOnImpact(boatModel)

	local boatPosition = boatModel:GetPivot().Position
	local facing = BoatServiceShared.GetRiderFacing(boatPosition, seat.CFrame)
	local seatPosition = Vector3.new(seat.Position.X, boatPosition.Y, seat.Position.Z)
	local eye = seatPosition - facing * CameraConfig.SEAT_CAM_BACK + Vector3.yAxis * CameraConfig.SEAT_CAM_UP
	local goal = CFrame.lookAt(eye, boatPosition + facing * CameraConfig.SEAT_CAM_LOOK_AHEAD)

	local smoothing = 1 - math.exp(-CameraConfig.SEAT_CAM_SMOOTHING * deltaTime)
	local current = (self.SmoothedCFrame or goal):Lerp(goal, smoothing)
	self.SmoothedCFrame = current

	if self.ShakeAmount > 0 then
		local offsetX = self.Random:NextNumber(-1, 1) * self.ShakeAmount
		local offsetY = self.Random:NextNumber(-1, 1) * self.ShakeAmount
		current *= CFrame.new(offsetX, offsetY, 0)
		self.ShakeAmount *= math.exp(-CameraConfig.SHAKE_DECAY * deltaTime)
	end

	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = current
end

return CameraServiceClient :: CameraServiceClient
