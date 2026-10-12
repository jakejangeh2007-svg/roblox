--!strict
-- Client entry point: set up the HUD, camera, controls and effects.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoatCamera = require(script.BoatCamera)
local FartFX = require(script.FartFX)
local FartInput = require(script.FartInput)
local Hud = require(script.Hud)
local Seating = require(script.Seating)

local Remotes = ReplicatedStorage.Remotes

Hud.start()
BoatCamera.start()
FartInput.start()
Seating.start()

-- Someone else on the server farted
Remotes.FartFX.OnClientEvent:Connect(function(farter: Player?, direction: string, power: number, isMega: boolean)
	if farter then -- nil if they left before this arrived
		FartFX.play(farter, direction, power, isMega)
	end
end)

-- RIP, FINISH!, FARTQUAKE! and so on
Remotes.Notice.OnClientEvent:Connect(function(text: string, color: Color3, shake: number)
	Hud.notice(text, color)
	if shake > 0 then
		BoatCamera.shake(shake)
	end
end)
