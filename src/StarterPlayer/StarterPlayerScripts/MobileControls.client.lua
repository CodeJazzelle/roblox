-- MobileControls.client.lua
-- On-screen action buttons for touch-only devices. Mirrors the keyboard
-- shortcuts:
--   [E] interact (yellow, bottom-right top of cluster) — finds the nearest
--                ProximityPrompt and fires InputHoldBegin / InputHoldEnd
--   [M] outfit  (purple) — toggles CharacterCustomizer ScreenGui.Enabled
--   [B] shop    (green)  — toggles MerchShop ScreenGui.Enabled
--   [C] chat    (blue)   — toggles QuickChatWheel ScreenGui.Enabled
--   [G] ping    (orange, bottom-LEFT, away from the right cluster) — fires
--                PingPlaced at the player's character position
--
-- Hidden on non-touch devices. Roblox already handles WASD → thumbstick
-- and tap-to-move automatically, so we only deal with the action keys.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
if not isMobile then return end

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PingPlacedEvent = Remotes:WaitForChild("PingPlaced")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- Helpers
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
-- UI build
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MobileControls"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 30
screenGui.Parent = playerGui

local function makeButton(opts)
    local btn = Instance.new("TextButton")
    btn.Name = opts.name
    btn.Size = UDim2.fromOffset(opts.size or 80, opts.size or 80)
    btn.AnchorPoint = opts.anchor or Vector2.new(0, 0)
    btn.Position = opts.pos
    btn.BackgroundColor3 = opts.color
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Text = ""
    btn.Parent = screenGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)  -- full circle
    corner.Parent = btn
    -- "Drop shadow" via a darker UIStroke
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 0, 0)
    stroke.Transparency = 0.6
    stroke.Thickness = 3
    stroke.Parent = btn

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = opts.label
    label.Font = Enum.Font.GothamBlack
    label.TextSize = opts.textSize or 16
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0.4
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Parent = btn

    -- Press feedback: scale down briefly + tint flash
    local origColor = opts.color
    btn.MouseButton1Down:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.06), {Size = UDim2.fromOffset((opts.size or 80) - 6, (opts.size or 80) - 6)}):Play()
        btn.BackgroundColor3 = origColor:Lerp(Color3.new(1, 1, 1), 0.3)
    end)
    btn.MouseButton1Up:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {Size = UDim2.fromOffset(opts.size or 80, opts.size or 80)}):Play()
        btn.BackgroundColor3 = origColor
    end)
    btn.Activated:Connect(opts.onTap)

    return btn
end

-- Bottom-right cluster: stacked vertically
local CLUSTER_X = -16   -- right margin
local CLUSTER_Y = -16   -- bottom margin
local BTN_SIZE  = 80
local SPACING   = 12

makeButton({
    name = "InteractBtn",
    label = "🤝\nINTERACT",
    color = Color3.fromRGB(255, 200, 50),
    anchor = Vector2.new(1, 1),
    pos = UDim2.new(1, CLUSTER_X, 1, CLUSTER_Y),
    onTap = fireNearestPrompt,
})
makeButton({
    name = "OutfitBtn",
    label = "👕\nOUTFIT",
    color = Color3.fromRGB(170, 90, 200),
    anchor = Vector2.new(1, 1),
    pos = UDim2.new(1, CLUSTER_X, 1, CLUSTER_Y - (BTN_SIZE + SPACING)),
    onTap = function() toggleGui("CharacterCustomizer") end,
})
makeButton({
    name = "ShopBtn",
    label = "🛒\nSHOP",
    color = Color3.fromRGB(60, 180, 100),
    anchor = Vector2.new(1, 1),
    pos = UDim2.new(1, CLUSTER_X, 1, CLUSTER_Y - 2 * (BTN_SIZE + SPACING)),
    onTap = function() toggleGui("MerchShop") end,
})
makeButton({
    name = "ChatBtn",
    label = "💬\nCHAT",
    color = Color3.fromRGB(60, 130, 220),
    size = 70,
    textSize = 14,
    anchor = Vector2.new(1, 1),
    pos = UDim2.new(1, CLUSTER_X - 5, 1, CLUSTER_Y - 3 * (BTN_SIZE + SPACING)),
    onTap = function() toggleGui("QuickChatWheel") end,
})

-- Bottom-LEFT (separate from right cluster; doesn't conflict with thumbstick
-- which is also on the left, but we sit above it)
makeButton({
    name = "PingBtn",
    label = "📍\nPING",
    color = Color3.fromRGB(255, 122, 0),
    anchor = Vector2.new(0, 1),
    pos = UDim2.new(0, 16, 1, -200),  -- well above the thumbstick area
    onTap = placePing,
})
