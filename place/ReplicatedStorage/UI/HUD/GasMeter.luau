--!strict
-- ModuleScript: ReplicatedStorage.UI.HUD.GasMeter
--
-- Fills the gas meter from the local player's Gas attribute (see FartService). The
-- fill glides to each new value instead of jumping. It only changes the fill's width;
-- the meter itself is built by hand in Studio.
--
-- UI contract (built by hand in StarterGui, sized with Scale only):
--   HUD        ScreenGui
--     GasMeter   Frame   the meter's background
--       Fill       Frame   the part that shrinks as gas runs out. Its width (Size X Scale)
--                          is set to the gas left: 1 when full, 0 when empty.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FartConfig = require(ReplicatedStorage.Shared.Modules.Game.FartConfig)
local FartServiceShared = require(ReplicatedStorage.Shared.Services.FartService.FartServiceShared)

local GasMeter = {
	HUD_NAME = "HUD",
	GAS_METER_NAME = "GasMeter",
	FILL_NAME = "Fill",
	FILL_SMOOTHING = 12, -- how quickly the fill catches up to the gas left (higher = snappier)
}

type GasMeterMembers = {
	ShownFraction: number?, -- how full the meter is showing right now
}

export type GasMeter = typeof(GasMeter) & GasMeterMembers

-- The Fill frame in the local player's HUD, if it's there.
local function FindFill(): GuiObject?
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local hud = if playerGui then playerGui:FindFirstChild(GasMeter.HUD_NAME) else nil
	local gasMeter = if hud then hud:FindFirstChild(GasMeter.GAS_METER_NAME) else nil
	local fill = if gasMeter then gasMeter:FindFirstChild(GasMeter.FILL_NAME) else nil
	return if fill and fill:IsA("GuiObject") then fill else nil
end

local function GetGasFraction(): number
	local gas = Players.LocalPlayer:GetAttribute(FartServiceShared.GAS_ATTRIBUTE)
	return if typeof(gas) == "number" then math.clamp(gas / FartConfig.GAS_MAX, 0, 1) else 0
end

function GasMeter.Init(self: GasMeter)
	self.ShownFraction = nil
	RunService.RenderStepped:Connect(function(deltaTime)
		self:Update(deltaTime)
	end)
end

function GasMeter.Update(self: GasMeter, deltaTime: number)
	local fill = FindFill()
	if not fill then
		self.ShownFraction = nil
		return
	end
	local targetFraction = GetGasFraction()
	local shownFraction = self.ShownFraction or targetFraction
	shownFraction += (targetFraction - shownFraction) * (1 - math.exp(-GasMeter.FILL_SMOOTHING * deltaTime))
	if math.abs(targetFraction - shownFraction) < 0.001 then
		shownFraction = targetFraction
	end
	self.ShownFraction = shownFraction
	if fill.Size.X.Scale ~= shownFraction then
		fill.Size = UDim2.fromScale(shownFraction, fill.Size.Y.Scale)
	end
end

return GasMeter :: GasMeter
