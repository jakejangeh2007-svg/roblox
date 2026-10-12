--!strict
-- Turns key presses, controller buttons and touch buttons into farts.
-- Tap = toot. Hold, then let go = Mega Fart.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local FartFX = require(script.Parent.FartFX)
local FartPhysics = require(ReplicatedStorage.Shared.FartPhysics)
local Hud = require(script.Parent.Hud)
local RiderState = require(script.Parent.RiderState)

local player = Players.LocalPlayer
local FartRemote = ReplicatedStorage.Remotes.Fart

local FartInput = {}

local ACTIONS: { [string]: FartPhysics.Direction } = {
	FartLeft = "Left",
	FartStraight = "Straight",
	FartRight = "Right",
}

local pressedAt: { [string]: number } = {}
local lastFart = 0

local function release(direction: FartPhysics.Direction, heldTime: number)
	local now = os.clock()
	if now - lastFart < Config.TOOT_COOLDOWN then
		return
	end
	local gas = player:GetAttribute("Gas")
	if typeof(gas) ~= "number" or gas < FartPhysics.getCost(heldTime) then
		FartFX.dud(player)
		return
	end
	lastFart = now
	FartFX.play(player, direction, FartPhysics.getPower(heldTime), FartPhysics.isMega(heldTime))
	FartRemote:FireServer(direction, heldTime)
end

local function onAction(actionName: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	local direction = ACTIONS[actionName]
	if not direction or not RiderState.isSeated() then
		-- not on a boat: let the keys do their normal job (like walking)
		return Enum.ContextActionResult.Pass
	end

	if state == Enum.UserInputState.Begin then
		pressedAt[direction] = os.clock()
		Hud.startCharge()
	elseif state == Enum.UserInputState.End then
		local startedAt = pressedAt[direction]
		pressedAt[direction] = nil
		Hud.stopCharge()
		if startedAt then
			release(direction, math.min(os.clock() - startedAt, Config.MEGA_CHARGE_TIME))
		end
	elseif state == Enum.UserInputState.Cancel then
		pressedAt[direction] = nil
		Hud.stopCharge()
	end
	return Enum.ContextActionResult.Sink
end

function FartInput.start()
	-- `true` also makes an on-screen button for touch devices
	ContextActionService:BindAction(
		"FartLeft",
		onAction,
		true,
		Enum.KeyCode.A,
		Enum.KeyCode.Left,
		Enum.KeyCode.Q,
		Enum.KeyCode.ButtonL1
	)
	ContextActionService:BindAction(
		"FartStraight",
		onAction,
		true,
		Enum.KeyCode.W,
		Enum.KeyCode.Up,
		Enum.KeyCode.Space,
		Enum.KeyCode.ButtonR2
	)
	ContextActionService:BindAction(
		"FartRight",
		onAction,
		true,
		Enum.KeyCode.D,
		Enum.KeyCode.Right,
		Enum.KeyCode.E,
		Enum.KeyCode.ButtonR1
	)
	ContextActionService:SetTitle("FartLeft", "LEFT")
	ContextActionService:SetTitle("FartStraight", "FART")
	ContextActionService:SetTitle("FartRight", "RIGHT")
end

return FartInput
