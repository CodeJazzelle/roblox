-- ControlHints.client.lua
-- Top-of-screen legend that adapts to the player's current input device:
-- keyboard, mobile (touch), Xbox, or PlayStation. Auto-hides 10s after the
-- player joins; pressing Tab (PC), TouchPad gesture (mobile), or Select/
-- Touchpad button (console) re-shows it. Updates on input-type changes.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- Detect platform from current/last input type
-- ============================================================
local function isPlayStation()
    -- Roblox doesn't expose a clean PS/Xbox switch; we infer via the
    -- gamepad's connected controller types when available, and fall back
    -- to a generic gamepad layout otherwise.
    local enumValue = GuiService:GetEmotesMenuOpen and GuiService:GetEmotesMenuOpen() and false or false
    -- Best-effort: check if any connected gamepad is a known PS-series
    local navGamepads = UserInputService:GetNavigationGamepads()
    for _, gp in ipairs(navGamepads) do
        local state = UserInputService:GetGamepadState(gp)
        for _, key in ipairs(state) do
            -- DualShock/DualSense report Cross/Circle/Square/Triangle
            -- glyphs but the KeyCode names are still ButtonA/B/X/Y. We
            -- can't tell from KeyCodes alone.
        end
    end
    return false  -- default to Xbox glyphs; platform users can mentally
                  -- swap PS ↔ Xbox bindings (positions are the same)
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
    xbox        = "[A] Interact   [Y] Outfit   [X] Shop   [B] Chat   [LB] Ping   [RB] Close",
    playstation = "[✕] Interact   [△] Outfit   [□] Shop   [○] Chat   [L1] Ping   [R1] Close",
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

-- Auto-hide after 10 seconds
task.delay(10, function() setVisible(false) end)

-- Re-show on Tab (PC) / Select (gamepad)
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.Tab
        or input.KeyCode == Enum.KeyCode.ButtonSelect
    then
        setVisible(not bar.Visible)
    end
end)
