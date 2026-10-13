--!strict
-- ModuleScript: ReplicatedStorage.UI.HUD.GasMeter
--
-- Fills the gas meter from the local player's Gas attribute (see FartService). It only
-- updates the fill's width; the meter itself is built by hand in Studio.
--
-- UI contract (built by hand in StarterGui, sized with Scale only):
--   HUD        ScreenGui
--     GasMeter   Frame   the meter's background
--       Fill       Frame   the part that shrinks as gas runs out. Its width (Size X Scale)
--                          is set to the gas left: 1 when full, 0 when empty.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FartConfig = require(ReplicatedStorage.Shared.Modules.Game.FartConfig)
local FartServiceShared = require(ReplicatedStorage.Shared.Services.FartService.FartServiceShared)

local GasMeter = {
	HUD_NAME = "HUD",
	GAS_METER_NAME = "GasMeter",
	FILL_NAME = "Fill",
}

type GasMeterMembers = {}

export type GasMeter = typeof(GasMeter) & GasMeterMembers

-- The Fill frame in the local player's HUD, if it's there.
local function FindFill(): GuiObject?
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local hud = if playerGui then playerGui:FindFirstChild(GasMeter.HUD_NAME) else nil
	local gasMeter = if hud then hud:FindFirstChild(GasMeter.GAS_METER_NAME) else nil
	local fill = if gasMeter then gasMeter:FindFirstChild(GasMeter.FILL_NAME) else nil
	return if fill and fill:IsA("GuiObject") then fill else nil
end

function GasMeter.Init(self: GasMeter)
	local localPlayer = Players.LocalPlayer

	local function Refresh()
		local fill = FindFill()
		if not fill then
			return
		end
		local gas = localPlayer:GetAttribute(FartServiceShared.GAS_ATTRIBUTE)
		local fraction = if typeof(gas) == "number" then math.clamp(gas / FartConfig.GAS_MAX, 0, 1) else 0
		fill.Size = UDim2.fromScale(fraction, fill.Size.Y.Scale)
	end

	localPlayer:GetAttributeChangedSignal(FartServiceShared.GAS_ATTRIBUTE):Connect(Refresh)
	-- The HUD is copied into PlayerGui when the character spawns, so refresh when it arrives.
	task.spawn(function()
		localPlayer:WaitForChild("PlayerGui").ChildAdded:Connect(Refresh)
		Refresh()
	end)
end

return GasMeter :: GasMeter
