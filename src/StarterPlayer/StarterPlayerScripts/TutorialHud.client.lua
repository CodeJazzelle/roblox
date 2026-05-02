-- TutorialHud.client.lua
-- Persistent helper bar at the bottom of the screen that walks first-time
-- players through the drink-making loop. The "current step" is derived from
-- the last CupUpdated payload — so the bar reacts as the player builds a
-- drink. The bar dismisses itself the first time OrderComplete fires for
-- this client (their first successful handoff).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- The 940-wide bottom bar overflows phone screens. Skip it on mobile —
-- the InstructionsScreen on first join already covers the same ground.
local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
if isMobile then return end

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CupUpdated = Remotes:WaitForChild("CupUpdated")
local OrderComplete = Remotes:WaitForChild("OrderComplete")

local player = Players.LocalPlayer
local DUTCH_BLUE = Color3.fromRGB(0, 90, 171)
local DUTCH_ORANGE = Color3.fromRGB(255, 122, 0)

local STEPS = {
    {key = "cup",     title = "1. Grab a Cup",   detail = "Walk to a cup tower"},
    {key = "base",    title = "2. Add a Base",   detail = "Espresso, Rebel, Tea, etc."},
    {key = "syrup",   title = "3. Add Syrups",   detail = "Match the order ticket"},
    {key = "topping", title = "4. Add Toppings", detail = "Whip, drizzle, etc."},
    {key = "lid",     title = "5. Add a Lid",    detail = "Seal it up"},
    {key = "handoff", title = "6. Hand Off",     detail = "Drive-thru window"},
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TutorialHud"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 10
screenGui.Parent = player:WaitForChild("PlayerGui")

local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -16)
bar.Size = UDim2.new(0, 940, 0, 78)
bar.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
bar.BorderSizePixel = 0
bar.Parent = screenGui
local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 10)
barCorner.Parent = bar
local barStroke = Instance.new("UIStroke")
barStroke.Color = DUTCH_ORANGE
barStroke.Thickness = 2
barStroke.Parent = bar

local heading = Instance.new("TextLabel")
heading.Size = UDim2.new(1, -16, 0, 18)
heading.Position = UDim2.fromOffset(8, 4)
heading.BackgroundTransparency = 1
heading.Text = "How to make a drink"
heading.Font = Enum.Font.GothamBold
heading.TextSize = 13
heading.TextXAlignment = Enum.TextXAlignment.Left
heading.TextColor3 = DUTCH_ORANGE
heading.Parent = bar

local row = Instance.new("Frame")
row.Size = UDim2.new(1, -16, 0, 52)
row.Position = UDim2.fromOffset(8, 22)
row.BackgroundTransparency = 1
row.Parent = bar

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 6)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = row

local stepUI = {}  -- index -> {frame, title, detail}
for i, step in ipairs(STEPS) do
    local cell = Instance.new("Frame")
    cell.Size = UDim2.new(1/#STEPS, -6, 1, 0)
    cell.BackgroundColor3 = Color3.fromRGB(40, 42, 50)
    cell.LayoutOrder = i
    cell.Parent = row
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = cell

    local titleL = Instance.new("TextLabel")
    titleL.Size = UDim2.new(1, -8, 0, 22)
    titleL.Position = UDim2.fromOffset(4, 4)
    titleL.BackgroundTransparency = 1
    titleL.Text = step.title
    titleL.Font = Enum.Font.GothamBold
    titleL.TextSize = 14
    titleL.TextXAlignment = Enum.TextXAlignment.Left
    titleL.TextColor3 = Color3.fromRGB(200, 200, 210)
    titleL.Parent = cell

    local detailL = Instance.new("TextLabel")
    detailL.Size = UDim2.new(1, -8, 0, 20)
    detailL.Position = UDim2.fromOffset(4, 26)
    detailL.BackgroundTransparency = 1
    detailL.Text = step.detail
    detailL.Font = Enum.Font.Gotham
    detailL.TextSize = 11
    detailL.TextXAlignment = Enum.TextXAlignment.Left
    detailL.TextColor3 = Color3.fromRGB(160, 160, 170)
    detailL.TextTruncate = Enum.TextTruncate.AtEnd
    detailL.Parent = cell

    stepUI[i] = {frame = cell, title = titleL, detail = detailL}
end

local function deriveStep(cup)
    if not cup then return 1 end
    if not cup.base then return 2 end
    if cup.hasLid then return 6 end
    if cup.toppings and #cup.toppings > 0 then return 5 end
    if cup.syrups and #cup.syrups > 0 then return 4 end
    return 3
end

local function applyStep(activeIndex)
    for i, ui in ipairs(stepUI) do
        if i < activeIndex then
            ui.frame.BackgroundColor3 = Color3.fromRGB(20, 80, 50)
            ui.title.TextColor3 = Color3.fromRGB(200, 255, 220)
            ui.detail.TextColor3 = Color3.fromRGB(150, 220, 180)
            ui.title.Text = STEPS[i].title:gsub("^%d+%. ", function(s) return s end) .. " ✓"
        elseif i == activeIndex then
            ui.frame.BackgroundColor3 = DUTCH_ORANGE
            ui.title.TextColor3 = Color3.new(1, 1, 1)
            ui.detail.TextColor3 = Color3.fromRGB(255, 240, 220)
            ui.title.Text = "→ " .. STEPS[i].title
        else
            ui.frame.BackgroundColor3 = Color3.fromRGB(40, 42, 50)
            ui.title.TextColor3 = Color3.fromRGB(200, 200, 210)
            ui.detail.TextColor3 = Color3.fromRGB(160, 160, 170)
            ui.title.Text = STEPS[i].title
        end
    end
end

applyStep(1)

CupUpdated.OnClientEvent:Connect(function(cupData)
    applyStep(deriveStep(cupData))
end)

local dismissed = false
OrderComplete.OnClientEvent:Connect(function()
    if dismissed then return end
    dismissed = true
    -- Slide-out fade
    bar:TweenPosition(
        UDim2.new(0.5, 0, 1, 100),
        Enum.EasingDirection.In,
        Enum.EasingStyle.Quad,
        0.5,
        true,
        function() screenGui:Destroy() end
    )
end)
