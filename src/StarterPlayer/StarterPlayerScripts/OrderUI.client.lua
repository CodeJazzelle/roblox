-- OrderUI.client.lua
-- Displays the queue of active customer orders. Subscribes to NewOrder /
-- OrderComplete / OrderFailed and shows each order as a card with the
-- drink, ingredients, and the tip-tier price the player will earn.
--
-- Per-card timers are intentionally absent — the only timer that matters
-- is the main round timer at the top center. Orders persist for the whole
-- shift until the player completes them or the round ends.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local NewOrder = Remotes:WaitForChild("NewOrder")
local OrderComplete = Remotes:WaitForChild("OrderComplete")
local OrderFailed = Remotes:WaitForChild("OrderFailed")

local player = Players.LocalPlayer
local DUTCH_BLUE = Color3.fromHex("#005AAB")
local TIP_GOLD   = Color3.fromRGB(255, 200, 50)
local SECRET_GOLD = Color3.fromRGB(255, 215, 60)

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

local Cards = {} -- [orderID] = {frame}
local nextLayoutOrder = 0

local function makeCard(orderID, payload)
    nextLayoutOrder += 1

    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 92)
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
    -- Leaves room on the right for the tip badge
    title.Size = UDim2.new(1, -120, 0, 28)
    title.Position = UDim2.fromOffset(12, 6)
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.Text = payload.displayName .. " (" .. payload.size .. ")"
    title.TextColor3 = payload.isSecret and Color3.new(1, 1, 1) or Color3.fromRGB(20, 20, 20)
    title.TextTruncate = Enum.TextTruncate.AtEnd
    title.Parent = card

    -- Tip badge in the top-right corner — yellow/gold so it pops.
    local tipLabel = Instance.new("TextLabel")
    tipLabel.AnchorPoint = Vector2.new(1, 0)
    tipLabel.Size = UDim2.new(0, 100, 0, 26)
    tipLabel.Position = UDim2.new(1, -8, 0, 6)
    tipLabel.BackgroundTransparency = 1
    tipLabel.Font = Enum.Font.GothamBlack
    tipLabel.TextSize = 20
    tipLabel.TextXAlignment = Enum.TextXAlignment.Right
    tipLabel.TextStrokeTransparency = 0.5
    tipLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    if payload.isSecret then
        tipLabel.Text = "★ $15"
        tipLabel.TextColor3 = SECRET_GOLD
    else
        tipLabel.Text = "$" .. tostring(payload.tip or 0) .. " TIP"
        tipLabel.TextColor3 = TIP_GOLD
    end
    tipLabel.Parent = card

    -- Sub-tag under tip for secret-menu drinks
    if payload.isSecret then
        local secretTag = Instance.new("TextLabel")
        secretTag.AnchorPoint = Vector2.new(1, 0)
        secretTag.Size = UDim2.new(0, 110, 0, 14)
        secretTag.Position = UDim2.new(1, -8, 0, 30)
        secretTag.BackgroundTransparency = 1
        secretTag.Font = Enum.Font.GothamSemibold
        secretTag.TextSize = 11
        secretTag.TextXAlignment = Enum.TextXAlignment.Right
        secretTag.Text = "SECRET MENU"
        secretTag.TextColor3 = SECRET_GOLD
        secretTag.Parent = card
    end

    local details = Instance.new("TextLabel")
    -- More vertical space now that the timer bar is gone
    details.Size = UDim2.new(1, -16, 0, 56)
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
    if payload.extraShots and payload.extraShots > 0 then
        detail = detail .. ("\n+ %d extra shot%s"):format(payload.extraShots, payload.extraShots == 1 and "" or "s")
    end
    details.Text = detail
    details.TextColor3 = payload.isSecret and Color3.fromRGB(220, 200, 255) or Color3.fromRGB(60, 60, 60)
    details.Parent = card

    Cards[orderID] = {frame = card}
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
