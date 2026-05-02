-- MobileControls.client.lua
-- Mobile-only minimal HUD. Three things only:
--   * Top-RIGHT MENU button (60×60, Dutch Bros blue, hamburger). Tap
--     opens MobileDrawer where Tips, Holding, Active Orders, Chat, Shop,
--     Outfit, Ping, and Help live.
--   * Bottom-CENTER Smart INTERACT button (90×90, yellow). Hidden when
--     no ProximityPrompt is in range. When in range, shows the prompt's
--     ActionText as a label above the button, and a tap triggers
--     :InputHoldBegin / :InputHoldEnd on the nearest prompt.
-- Everything else (Ping, Outfit, Shop, Chat) lives inside the drawer.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
if not isMobile then return end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- Helpers
-- ============================================================
local function findNearestPrompt()
    local character = player.Character
    if not character then return nil, math.huge end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, math.huge end

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
    return nearest, nearestDist
end

local function fireNearestPrompt()
    local prompt = findNearestPrompt()
    if not prompt then return end
    prompt:InputHoldBegin()
    task.delay(prompt.HoldDuration + 0.05, function()
        prompt:InputHoldEnd()
    end)
end

-- ============================================================
-- ScreenGui
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MobileControls"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 30
screenGui.Parent = playerGui

local function makeRoundButton(props)
    local b = Instance.new("TextButton")
    b.Name = props.name
    b.Size = UDim2.fromOffset(props.size, props.size)
    b.AnchorPoint = props.anchor
    b.Position = props.pos
    b.BackgroundColor3 = props.color
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Text = ""
    b.Parent = screenGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = b
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 0, 0)
    stroke.Transparency = 0.6
    stroke.Thickness = 3
    stroke.Parent = b

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = props.label
    label.Font = Enum.Font.GothamBlack
    label.TextSize = props.textSize or 16
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0.4
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Parent = b

    local origColor = props.color
    b.MouseButton1Down:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.06), {Size = UDim2.fromOffset(props.size - 6, props.size - 6)}):Play()
        b.BackgroundColor3 = origColor:Lerp(Color3.new(1, 1, 1), 0.3)
    end)
    b.MouseButton1Up:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.1), {Size = UDim2.fromOffset(props.size, props.size)}):Play()
        b.BackgroundColor3 = origColor
    end)
    b.Activated:Connect(props.onTap)
    return b
end

-- ============================================================
-- MENU button — top-right. Tap → toggle MobileDrawer.
-- ============================================================
makeRoundButton({
    name = "MenuBtn",
    label = "≡\nMENU",
    color = Color3.fromRGB(0, 90, 171),
    size = 60,
    textSize = 11,
    anchor = Vector2.new(1, 0),
    pos = UDim2.new(1, -16, 0, 16),
    onTap = function()
        if _G.ToggleMobileDrawer then _G.ToggleMobileDrawer() end
    end,
})

-- ============================================================
-- Smart INTERACT button — bottom-center. Hidden until a ProximityPrompt
-- is in range. ActionText label sits above the button so the player
-- knows what they're about to do without needing station labels.
-- ============================================================
local INTERACT_SIZE = 90
local interactBtn = makeRoundButton({
    name = "InteractBtn",
    label = "🤝\nE",
    color = Color3.fromRGB(255, 200, 50),
    size = INTERACT_SIZE,
    textSize = 14,
    anchor = Vector2.new(0.5, 1),
    pos = UDim2.new(0.5, 0, 1, -16),
    onTap = fireNearestPrompt,
})
interactBtn.Visible = false

-- Action label — pill above the interact button. Shows e.g. "Pull
-- Shots" / "Add Vanilla" / "Hand Off".
local actionLabel = Instance.new("TextLabel")
actionLabel.AnchorPoint = Vector2.new(0.5, 1)
actionLabel.Size = UDim2.fromOffset(180, 28)
actionLabel.Position = UDim2.new(0.5, 0, 1, -16 - INTERACT_SIZE - 6)
actionLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
actionLabel.BackgroundTransparency = 0.25
actionLabel.BorderSizePixel = 0
actionLabel.Text = ""
actionLabel.Font = Enum.Font.GothamBold
actionLabel.TextSize = 14
actionLabel.TextColor3 = Color3.new(1, 1, 1)
actionLabel.TextStrokeTransparency = 0.5
actionLabel.TextTruncate = Enum.TextTruncate.AtEnd
actionLabel.Visible = false
actionLabel.Parent = screenGui
local actionLabelCorner = Instance.new("UICorner")
actionLabelCorner.CornerRadius = UDim.new(0, 14)
actionLabelCorner.Parent = actionLabel

-- Visibility tracker. Polled at ~7Hz to keep CPU light on phones.
task.spawn(function()
    while true do
        task.wait(0.15)
        local prompt = findNearestPrompt()
        if prompt then
            local actionText = prompt.ActionText
            if not actionText or actionText == "" then
                actionText = prompt.ObjectText ~= "" and prompt.ObjectText or "Interact"
            end
            actionLabel.Text = actionText
            actionLabel.Visible = true
            interactBtn.Visible = true
        else
            actionLabel.Visible = false
            interactBtn.Visible = false
        end
    end
end)
