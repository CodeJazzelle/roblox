-- OrderUI.client.lua
-- Displays the queue of active customer orders. Subscribes to NewOrder /
-- OrderComplete / OrderFailed and shows each order as a card with a draining timer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local NewOrder = Remotes:WaitForChild("NewOrder")
local OrderComplete = Remotes:WaitForChild("OrderComplete")
local OrderFailed = Remotes:WaitForChild("OrderFailed")

local player = Players.LocalPlayer
local DUTCH_BLUE = Color3.fromHex("#005AAB")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "OrderQueue"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = player:WaitForChild("PlayerGui")

local container = Instance.new("Frame")
container.Size = UDim2.new(0, 320, 0.8, 0)
container.Position = UDim2.new(1, -340, 0, 80)
container.BackgroundTransparency = 1
container.Parent = screenGui

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = container

local Cards = {} -- [orderID] = {frame, expiresAt, patience, timerBar}
local nextLayoutOrder = 0

local function makeCard(orderID, payload)
    nextLayoutOrder += 1

    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 100)
    card.BackgroundColor3 = payload.isSecret and Color3.fromRGB(80, 30, 120) or Color3.fromRGB(255, 255, 255)
    card.LayoutOrder = nextLayoutOrder
    card.Parent = container
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = card

    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(0, 6, 1, 0)
    accent.BackgroundColor3 = DUTCH_BLUE
    accent.BorderSizePixel = 0
    accent.Parent = card

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -16, 0, 28)
    title.Position = UDim2.fromOffset(12, 4)
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.Text = payload.displayName .. " (" .. payload.size .. ")"
    title.TextColor3 = payload.isSecret and Color3.new(1, 1, 1) or Color3.fromRGB(20, 20, 20)
    title.TextTruncate = Enum.TextTruncate.AtEnd
    title.Parent = card

    local details = Instance.new("TextLabel")
    details.Size = UDim2.new(1, -16, 0, 50)
    details.Position = UDim2.fromOffset(12, 32)
    details.BackgroundTransparency = 1
    details.TextXAlignment = Enum.TextXAlignment.Left
    details.TextYAlignment = Enum.TextYAlignment.Top
    details.Font = Enum.Font.Gotham
    details.TextSize = 12
    details.TextWrapped = true
    local detail = ("%s base"):format(payload.base)
    if payload.syrups and #payload.syrups > 0 then
        detail = detail .. " · " .. table.concat(payload.syrups, ", ")
    end
    if payload.toppings and #payload.toppings > 0 then
        detail = detail .. "\n+ " .. table.concat(payload.toppings, ", ")
    end
    details.Text = detail
    details.TextColor3 = payload.isSecret and Color3.fromRGB(220, 200, 255) or Color3.fromRGB(60, 60, 60)
    details.Parent = card

    local timerBar = Instance.new("Frame")
    timerBar.Size = UDim2.new(1, -16, 0, 6)
    timerBar.Position = UDim2.new(0, 12, 1, -10)
    timerBar.BackgroundColor3 = DUTCH_BLUE
    timerBar.BorderSizePixel = 0
    timerBar.Parent = card

    Cards[orderID] = {
        frame = card,
        expiresAt = tick() + (payload.patience or 60),
        patience = payload.patience or 60,
        timerBar = timerBar,
    }
end

local function removeCard(orderID)
    local entry = Cards[orderID]
    if entry then
        entry.frame:Destroy()
        Cards[orderID] = nil
    end
end

NewOrder.OnClientEvent:Connect(makeCard)
OrderComplete.OnClientEvent:Connect(function(orderID) removeCard(orderID) end)
OrderFailed.OnClientEvent:Connect(function(orderID) removeCard(orderID) end)

RunService.RenderStepped:Connect(function()
    for _, entry in pairs(Cards) do
        local remaining = math.max(0, entry.expiresAt - tick())
        local pct = remaining / entry.patience
        entry.timerBar.Size = UDim2.new(pct, -16, 0, 6)
        if pct < 0.3 then
            entry.timerBar.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
        else
            entry.timerBar.BackgroundColor3 = DUTCH_BLUE
        end
    end
end)
