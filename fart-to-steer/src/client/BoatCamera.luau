--!strict
-- Seat Cam: sits behind your own seat and looks across the boat, so Straight
-- always pushes the boat up your screen and Left always turns your view left.
-- Press V (or the CAM button) to switch to the normal Roblox camera and back.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local RiderState = require(script.Parent.RiderState)

local BoatCamera = {}

local seatCamOn = true
local shakeAmount = 0
local smoothed: CFrame? = nil
local random = Random.new()

function BoatCamera.shake(amount: number)
	shakeAmount = math.max(shakeAmount, amount)
end

local function update(dt: number)
	local camera = workspace.CurrentCamera
	local root, seat = RiderState.get()
	if not (seatCamOn and root and seat) then
		if camera.CameraType == Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Custom
		end
		smoothed = nil
		return
	end

	local center = root.Position
	local seatPosition = seat.WorldPosition
	local toCenter = (center - seatPosition) * Vector3.new(1, 0, 1)
	if toCenter.Magnitude < 1e-3 then
		return
	end
	local facing = toCenter.Unit
	local eye = seatPosition - facing * Config.CAMERA_BACK + Vector3.yAxis * Config.CAMERA_UP
	local goal = CFrame.lookAt(eye, center + facing * Config.CAMERA_LOOK_AHEAD)

	local current = (smoothed or goal):Lerp(goal, 1 - math.exp(-Config.CAMERA_SMOOTHING * dt))
	smoothed = current

	if shakeAmount > 0.01 then
		current *= CFrame.new(random:NextNumber(-1, 1) * shakeAmount, random:NextNumber(-1, 1) * shakeAmount, 0)
		shakeAmount *= math.exp(-8 * dt)
	end

	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = current
end

local function onToggle(_actionName: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		seatCamOn = not seatCamOn
	end
	return Enum.ContextActionResult.Sink
end

function BoatCamera.start()
	RunService:BindToRenderStep("FartBoatCamera", Enum.RenderPriority.Camera.Value + 1, update)
	ContextActionService:BindAction("ToggleCamera", onToggle, true, Enum.KeyCode.V, Enum.KeyCode.ButtonY)
	ContextActionService:SetTitle("ToggleCamera", "CAM")
end

return BoatCamera
