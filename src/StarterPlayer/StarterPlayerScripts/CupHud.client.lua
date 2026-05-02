-- CupHud.client.lua
-- Bottom-left HUD that shows what's in the player's current cup.
-- Subscribes to the CupUpdated remote (server fires nil when the cup is
-- cleared / trashed / submitted) and shows/hides accordingly.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- Mobile shows the holding-cup status inside the slide-in drawer (see
-- MobileDrawer.client.lua), so the persistent bottom-left HUD is hidden
-- entirely on touch devices.
local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
if isMobile then return end

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CupUpdated = Remotes:WaitForChild("CupUpdated")

local player = Players.LocalPlayer
local DUTCH_BLUE = Color3.fromRGB(0, 90, 171)
local DUTCH_ORANGE = Color3.fromRGB(255, 122, 0)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CupHud"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 5
screenGui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0, 1)
panel.Position = UDim2.new(0, 16, 1, -110)  -- sits above the tutorial bar
panel.Size = UDim2.new(0, 260, 0, 180)
panel.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = screenGui
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent = panel
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = DUTCH_BLUE
panelStroke.Thickness = 2
panelStroke.Parent = panel

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 30)
header.BackgroundColor3 = DUTCH_BLUE
header.BorderSizePixel = 0
header.Parent = panel
local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 10)
headerCorner.Parent = header

local headerLabel = Instance.new("TextLabel")
headerLabel.Size = UDim2.new(1, -16, 1, 0)
headerLabel.Position = UDim2.fromOffset(8, 0)
headerLabel.BackgroundTransparency = 1
headerLabel.Text = "Holding: — Cup"
headerLabel.Font = Enum.Font.GothamBold
headerLabel.TextSize = 14
headerLabel.TextXAlignment = Enum.TextXAlignment.Left
headerLabel.TextColor3 = Color3.new(1, 1, 1)
headerLabel.Parent = header

local function makeRow(yOffset, name)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -16, 0, 18)
    label.Position = UDim2.fromOffset(8, yOffset)
    label.BackgroundTransparency = 1
    label.Text = name
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextColor3 = Color3.fromRGB(170, 170, 180)
    label.Parent = panel

    local value = Instance.new("TextLabel")
    value.Size = UDim2.new(1, -16, 0, 18)
    value.Position = UDim2.fromOffset(8, yOffset + 16)
    value.BackgroundTransparency = 1
    value.Font = Enum.Font.Gotham
    value.TextSize = 13
    value.TextXAlignment = Enum.TextXAlignment.Left
    value.TextWrapped = true
    value.TextColor3 = Color3.new(1, 1, 1)
    value.TextTruncate = Enum.TextTruncate.AtEnd
    value.Parent = panel
    return value
end

local baseRow    = makeRow(38, "BASE")
local syrupRow   = makeRow(76, "SYRUPS")
local toppingRow = makeRow(114, "TOPPINGS")

local lidRow = Instance.new("TextLabel")
lidRow.Size = UDim2.new(1, -16, 0, 22)
lidRow.Position = UDim2.fromOffset(8, 152)
lidRow.BackgroundTransparency = 1
lidRow.Font = Enum.Font.GothamBold
lidRow.TextSize = 13
lidRow.TextXAlignment = Enum.TextXAlignment.Left
lidRow.Parent = panel

local function joinList(list, fallback)
    if not list or #list == 0 then return fallback end
    return table.concat(list, ", ")
end

CupUpdated.OnClientEvent:Connect(function(cup)
    if not cup then
        panel.Visible = false
        return
    end
    panel.Visible = true
    headerLabel.Text = ("Holding: %s Cup"):format(cup.size or "?")
    baseRow.Text = cup.base or "(empty)"
    baseRow.TextColor3 = cup.base and Color3.new(1, 1, 1) or Color3.fromRGB(150, 150, 160)
    syrupRow.Text = joinList(cup.syrups, "(none)")
    syrupRow.TextColor3 = (cup.syrups and #cup.syrups > 0) and Color3.new(1, 1, 1) or Color3.fromRGB(150, 150, 160)
    toppingRow.Text = joinList(cup.toppings, "(none)")
    toppingRow.TextColor3 = (cup.toppings and #cup.toppings > 0) and Color3.new(1, 1, 1) or Color3.fromRGB(150, 150, 160)
    if cup.hasLid then
        lidRow.Text = "✓ Lid sealed — ready to hand off"
        lidRow.TextColor3 = Color3.fromRGB(120, 220, 140)
    else
        lidRow.Text = "✗ No lid yet"
        lidRow.TextColor3 = DUTCH_ORANGE
    end
end)
