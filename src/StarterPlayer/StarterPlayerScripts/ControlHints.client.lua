-- ControlHints.client.lua
-- Top-of-screen legend that adapts to the player's current input device:
-- keyboard, mobile (touch), Xbox, or PlayStation. Auto-hides 10s after the
-- player joins; pressing Tab (PC), TouchPad gesture (mobile), or Select/
-- Touchpad button (console) re-shows it. Updates on input-type changes.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- Detect platform from current/last input type
-- ============================================================
local function isPlayStation()
    -- Roblox's KeyCode names are unified (ButtonA/B/X/Y) regardless of
    -- whether a Sony or Microsoft controller is connected, and there's
    -- no public API that distinguishes them. Default to Xbox glyphs;
    -- the button positions are identical so a PlayStation player still
    -- presses the correct physical button.
    return false
end

local function getInputType()
    if UserInputService.GamepadEnabled and UserInputService:GetGamepadConnected(Enum.UserInputType.Gamepad1) then
        return isPlayStation() and "playstation" or "xbox"
    elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        return "mobile"
    end
    return "keyboard"
end

-- ============================================================
-- Hint text per platform
-- ============================================================
local HINT_TEXT = {
    keyboard    = "[E] Interact   [M] Outfit   [B] Shop   [C] Chat   [G] Ping   [WASD] Move",
    mobile      = "Tap the corner buttons: 🤝 Interact   👕 Outfit   🛒 Shop   💬 Chat   📍 Ping",
    -- A / Cross is reserved for Jump (Roblox default), so Interact moved
    -- to X / Square and Shop moved to RB / R1.
    xbox        = "[X] Interact   [Y] Outfit   [RB] Shop   [B] Chat   [LB] Ping   [A] Jump",
    playstation = "[□] Interact   [△] Outfit   [R1] Shop   [○] Chat   [L1] Ping   [✕] Jump",
}

-- ============================================================
-- UI build
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ControlHints"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 20
screenGui.Parent = playerGui

local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 0)
bar.Position = UDim2.new(0.5, 0, 0, 60)  -- below round timer
bar.Size = UDim2.new(0, 760, 0, 36)
bar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
bar.BackgroundTransparency = 0.4
bar.BorderSizePixel = 0
bar.Parent = screenGui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = bar
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 200, 50)
stroke.Thickness = 1
stroke.Transparency = 0.4
stroke.Parent = bar

local hintLabel = Instance.new("TextLabel")
hintLabel.Size = UDim2.new(1, -16, 1, 0)
hintLabel.Position = UDim2.fromOffset(8, 0)
hintLabel.BackgroundTransparency = 1
hintLabel.Text = HINT_TEXT.keyboard
hintLabel.Font = Enum.Font.GothamBold
hintLabel.TextSize = 13
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.TextXAlignment = Enum.TextXAlignment.Center
hintLabel.TextTruncate = Enum.TextTruncate.AtEnd
hintLabel.Parent = bar

local hintReshow = Instance.new("TextLabel")
hintReshow.AnchorPoint = Vector2.new(0.5, 0)
hintReshow.Size = UDim2.new(0, 220, 0, 16)
hintReshow.Position = UDim2.new(0.5, 0, 0, 100)
hintReshow.BackgroundTransparency = 1
hintReshow.Text = ""
hintReshow.Font = Enum.Font.Gotham
hintReshow.TextSize = 11
hintReshow.TextColor3 = Color3.fromRGB(180, 180, 190)
hintReshow.Parent = screenGui

-- ============================================================
-- Behavior: refresh on input-type change, auto-hide after 10s,
-- re-show on Tab (PC) / Select (gamepad) / Touchpad gesture
-- ============================================================
local function applyForCurrent()
    local kind = getInputType()
    hintLabel.Text = HINT_TEXT[kind] or HINT_TEXT.keyboard
    -- Re-show hint differs per platform
    if kind == "keyboard" then
        hintReshow.Text = "[Tab] show controls"
    elseif kind == "mobile" then
        hintReshow.Text = "(controls always visible at corners)"
    else
        hintReshow.Text = "[Select] show controls"
    end
end

local function setVisible(v)
    bar.Visible = v
    hintReshow.Visible = (not v)
end

applyForCurrent()
setVisible(true)

UserInputService.LastInputTypeChanged:Connect(applyForCurrent)

-- Mobile: tighten the auto-hide and never show the "[Tab] show controls"
-- reshow hint (mobile players have the corner buttons already, no need
-- for persistent text taking up screen space).
local isMobileForHints = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
local autoHideDelay = isMobileForHints and 5 or 10
if isMobileForHints then
    hintReshow.Visible = false
end

task.delay(autoHideDelay, function()
    setVisible(false)
    if isMobileForHints then
        hintReshow.Visible = false  -- keep it hidden even after main hide
    end
end)

-- Re-show on Tab (PC) / Select (gamepad)
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.Tab
        or input.KeyCode == Enum.KeyCode.ButtonSelect
    then
        setVisible(not bar.Visible)
    end
end)
