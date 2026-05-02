-- GamepadControls.client.lua
-- Binds Xbox / PlayStation controller buttons to game actions via
-- ContextActionService so the bindings show up in Roblox's built-in input
-- mapper UI and so the player can rebind them.
--
-- Mappings (Xbox / PlayStation). NOTE: ButtonA is intentionally NOT
-- bound — Roblox uses A / Cross as the default Jump key, and overriding
-- it would prevent the character from jumping. Interact is moved to
-- ButtonX / Square instead.
--
--   ButtonA  / Cross     → Jump (Roblox default, NOT bound here)
--   ButtonX  / Square    → Interact (fires nearest ProximityPrompt;
--                          ProximityPrompt.GamepadKeyCode is also set to
--                          ButtonX so Roblox shows the right glyph and
--                          auto-handles short-range prompts)
--   ButtonY  / Triangle  → Toggle Character Customizer (M-key equivalent)
--   ButtonB  / Circle    → Toggle Quick Chat Wheel (C-key equivalent)
--   ButtonL1 / L1        → Place Ping at character position
--   ButtonR1 / R1        → Toggle Merch Shop (B-key equivalent)
--
-- Note: ButtonB is also Roblox's default "back" button on its own menus.
-- That conflict is unavoidable without a custom menu chrome — players can
-- rebind via Settings → Controls if it's a problem.

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not UserInputService.GamepadEnabled then
    -- We still bind actions even if no gamepad is currently connected, so
    -- a controller plugged in later just works. But on devices that have
    -- no gamepad capability at all (e.g. some mobile browsers), skip.
    -- On most desktop / console environments GamepadEnabled is true even
    -- without a controller currently connected, so we proceed.
end

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PingPlacedEvent = Remotes:WaitForChild("PingPlaced")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- Helpers (mirror MobileControls so behavior stays consistent)
-- ============================================================
local function findNearestPrompt()
    local character = player.Character
    if not character then return nil end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local nearest, nearestDist = nil, math.huge
    for _, inst in ipairs(workspace:GetDescendants()) do
        if inst:IsA("ProximityPrompt") and inst.Enabled then
            local promptPart = inst.Parent
            if promptPart and promptPart:IsA("BasePart") then
                local dist = (promptPart.Position - hrp.Position).Magnitude
                local maxDist = inst.MaxActivationDistance > 0 and inst.MaxActivationDistance or 8
                if dist <= maxDist and dist < nearestDist then
                    nearest = inst
                    nearestDist = dist
                end
            end
        end
    end
    return nearest
end

local function fireNearestPrompt()
    local prompt = findNearestPrompt()
    if not prompt then return end
    prompt:InputHoldBegin()
    task.delay(prompt.HoldDuration + 0.05, function()
        prompt:InputHoldEnd()
    end)
end

local function toggleGui(name)
    local gui = playerGui:FindFirstChild(name)
    if gui then gui.Enabled = not gui.Enabled end
end

local function placePing()
    local character = player.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then PingPlacedEvent:FireServer(hrp.Position) end
end

-- ============================================================
-- ContextActionService bindings
-- ============================================================
local function onBegin(handler)
    return function(_, state)
        if state == Enum.UserInputState.Begin then
            handler()
        end
    end
end

ContextActionService:BindAction(
    "GamepadInteract",
    onBegin(fireNearestPrompt),
    false, -- no auto touch button
    Enum.KeyCode.ButtonX  -- A is reserved for Jump
)
ContextActionService:SetTitle("GamepadInteract", "Interact")

ContextActionService:BindAction(
    "GamepadCustomizer",
    onBegin(function() toggleGui("CharacterCustomizer") end),
    false,
    Enum.KeyCode.ButtonY
)
ContextActionService:SetTitle("GamepadCustomizer", "Outfit")

ContextActionService:BindAction(
    "GamepadShop",
    onBegin(function() toggleGui("MerchShop") end),
    false,
    Enum.KeyCode.ButtonR1   -- moved off X (now Interact)
)
ContextActionService:SetTitle("GamepadShop", "Shop")

ContextActionService:BindAction(
    "GamepadChat",
    onBegin(function() toggleGui("QuickChatWheel") end),
    false,
    Enum.KeyCode.ButtonB
)
ContextActionService:SetTitle("GamepadChat", "Chat")

ContextActionService:BindAction(
    "GamepadPing",
    onBegin(placePing),
    false,
    Enum.KeyCode.ButtonL1
)
ContextActionService:SetTitle("GamepadPing", "Ping")

-- (No Cancel binding — R1 is now Shop. Players can close menus by
-- pressing the same button that opened them, or via in-menu close
-- buttons. Roblox's own ButtonB back behavior still works on the
-- engine's standard menus.)
