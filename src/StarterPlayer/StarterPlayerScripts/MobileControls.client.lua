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

-- Layout:
--   * INTERACT — bottom-CENTER, 80×80 (primary action, biggest target)
--   * PING     — bottom-LEFT,   60×60
--   * MENU     — top-RIGHT,     60×60. Tap to slide out CHAT / SHOP /
--                 OUTFIT options below it. Tap-outside backdrop closes.
local BTN_SIZE = 60

makeButton({
    name = "InteractBtn",
    label = "🤝\nINTERACT",
    color = Color3.fromRGB(255, 200, 50),
    size = 80,
    textSize = 13,
    anchor = Vector2.new(0.5, 1),
    pos = UDim2.new(0.5, 0, 1, -16),
    onTap = fireNearestPrompt,
})

makeButton({
    name = "PingBtn",
    label = "📍\nPING",
    color = Color3.fromRGB(255, 122, 0),
    size = BTN_SIZE,
    textSize = 11,
    anchor = Vector2.new(0, 1),
    pos = UDim2.new(0, 16, 1, -16),
    onTap = placePing,
})

-- ============================================================
-- Collapsed MENU (top-right) — replaces the 3 separate Chat/Shop/Outfit
-- buttons. Tap-to-toggle, slides options in below with a 0.1s stagger,
-- backdrop-tap or option-tap closes.
-- ============================================================
local MENU_TOP, MENU_RIGHT = 16, 16
local MENU_BTN_SIZE = 60
local OPTION_W, OPTION_H, OPTION_GAP = 160, 50, 8

local menuOpen = false
local menuOptions = {}
local menuBackdrop = nil
local closeMenu  -- forward decl (openMenu refers to it)

local function optionFinalY(index)
    return MENU_TOP + MENU_BTN_SIZE + 12 + (index - 1) * (OPTION_H + OPTION_GAP)
end

local function makeOptionButton(index, emoji, label, color, onActivate)
    local b = Instance.new("TextButton")
    b.Name = "MenuOption_" .. label
    b.Size = UDim2.fromOffset(OPTION_W, OPTION_H)
    b.AnchorPoint = Vector2.new(1, 0)
    -- Start hidden behind the menu button (slides DOWN to its target).
    b.Position = UDim2.new(1, -MENU_RIGHT, 0, MENU_TOP)
    b.BackgroundColor3 = color
    b.BackgroundTransparency = 0.05
    b.AutoButtonColor = true
    b.Text = emoji .. "  " .. label
    b.Font = Enum.Font.GothamBold
    b.TextSize = 18
    b.TextColor3 = Color3.new(1, 1, 1)
    b.TextStrokeTransparency = 0.5
    b.ZIndex = 5
    b.Parent = screenGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = b
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.new(1, 1, 1)
    stroke.Thickness = 2
    stroke.Transparency = 0.4
    stroke.Parent = b
    b.MouseButton1Click:Connect(function()
        onActivate()
        if closeMenu then closeMenu() end
    end)

    -- Slide-in tween with 0.1s stagger
    task.delay((index - 1) * 0.1, function()
        TweenService:Create(b, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(1, -MENU_RIGHT, 0, optionFinalY(index)),
        }):Play()
    end)
    return b
end

local function openMenu()
    if menuOpen then return end
    menuOpen = true

    -- Full-screen invisible button BEHIND the options — catches tap-outside.
    menuBackdrop = Instance.new("TextButton")
    menuBackdrop.Name = "MenuBackdrop"
    menuBackdrop.Size = UDim2.fromScale(1, 1)
    menuBackdrop.BackgroundTransparency = 1
    menuBackdrop.Text = ""
    menuBackdrop.AutoButtonColor = false
    menuBackdrop.ZIndex = 1
    menuBackdrop.Parent = screenGui
    menuBackdrop.MouseButton1Click:Connect(function()
        if closeMenu then closeMenu() end
    end)

    menuOptions = {
        makeOptionButton(1, "💬", "CHAT",   Color3.fromRGB(60,  130, 220), function() toggleGui("QuickChatWheel") end),
        makeOptionButton(2, "🛒", "SHOP",   Color3.fromRGB(60,  180, 100), function() toggleGui("MerchShop") end),
        makeOptionButton(3, "👕", "OUTFIT", Color3.fromRGB(170, 90,  200), function() toggleGui("CharacterCustomizer") end),
    }
end

closeMenu = function()
    if not menuOpen then return end
    menuOpen = false
    if menuBackdrop then
        menuBackdrop:Destroy()
        menuBackdrop = nil
    end
    -- Tween options back up under the menu button, then destroy.
    local toCleanup = menuOptions
    menuOptions = {}
    for _, b in ipairs(toCleanup) do
        TweenService:Create(b, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(1, -MENU_RIGHT, 0, MENU_TOP),
        }):Play()
    end
    task.delay(0.2, function()
        for _, b in ipairs(toCleanup) do
            if b and b.Parent then b:Destroy() end
        end
    end)
end

makeButton({
    name = "MenuBtn",
    label = "≡\nMENU",
    color = Color3.fromRGB(0, 90, 171),  -- Dutch Bros blue
    size = MENU_BTN_SIZE,
    textSize = 11,
    anchor = Vector2.new(1, 0),
    pos = UDim2.new(1, -MENU_RIGHT, 0, MENU_TOP),
    onTap = function()
        if menuOpen then closeMenu() else openMenu() end
    end,
})
