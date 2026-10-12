--!strict
-- While the local player is on a boat: walking and jumping are switched off
-- and the character holds its sit pose.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local RiderState = require(script.Parent.RiderState)

local player = Players.LocalPlayer

local Seating = {}

local sitTrack: AnimationTrack? = nil

-- Plays the character's own sit animation (from its Animate script), so it
-- works for R6, R15 and custom animation packs.
local function holdSitPose(character: Model, humanoid: Humanoid)
	local animate = character:FindFirstChild("Animate")
	local sitFolder = animate and animate:FindFirstChild("sit")
	local animation = sitFolder and sitFolder:FindFirstChildOfClass("Animation")
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not (animation and animator) then
		return
	end
	if sitTrack then
		sitTrack:Stop()
	end
	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	track:Play()
	sitTrack = track
end

function Seating.start()
	local playerModule = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript
	local controls = (require :: any)(playerModule):GetControls()
	local wasSeated = false

	RunService.Heartbeat:Connect(function()
		local seated = RiderState.isSeated()
		if seated == wasSeated then
			return
		end
		wasSeated = seated

		if seated then
			controls:Disable()
		else
			controls:Enable()
		end

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if character and humanoid then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, not seated)
			if seated then
				holdSitPose(character, humanoid)
			end
		end
	end)
end

return Seating
