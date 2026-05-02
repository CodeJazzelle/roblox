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
local UserInputService = game:GetService("UserInputService")

-- Mobile/tablet detection — touch device with no physical mouse. Same
-- check used by MobileControls / MobileLabelFilter so all three agree
-- on which UI mode to render.
local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local NewOrder = Remotes:WaitForChild("NewOrder")
local OrderComplete = Remotes:WaitForChild("OrderComplete")
local OrderFailed = Remotes:WaitForChild("OrderFailed")

local player = Players.LocalPlayer
local DUTCH_BLUE = Color3.fromHex("#005AAB")
local TIP_GOLD   = Color3.fromRGB(255, 200, 50)
local SECRET_GOLD = Color3.fromRGB(255, 215, 60)

-- Size badges sit to the LEFT of the drink name on each card so the
-- player can see Small/Medium/Large at a glance without reading the
-- title parenthetical.
local SIZE_COLORS = {
    Small  = Color3.fromRGB(240, 200, 60),
    Medium = Color3.fromRGB(0,   120, 215),
    Large  = Color3.fromRGB(220, 80,  80),
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "OrderQueue"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = player:WaitForChild("PlayerGui")

-- On mobile the right-side queue overlapped the action buttons. Move it
-- to a horizontal scroll strip across the TOP of the screen instead;
-- desktop keeps the original vertical right-side queue.
local container
if isMobile then
    container = Instance.new("ScrollingFrame")
    container.Size = UDim2.new(1, -16, 0, 96)
    container.Position = UDim2.new(0, 8, 0, 150)  -- below timer + tips block
    container.BackgroundTransparency = 1
    container.BorderSizePixel = 0
    container.ScrollingDirection = Enum.ScrollingDirection.X
    container.ScrollBarThickness = 4
    container.AutomaticCanvasSize = Enum.AutomaticSize.X
    container.CanvasSize = UDim2.new(0, 0, 0, 0)
else
    container = Instance.new("Frame")
    container.Size = UDim2.new(0, 320, 0.8, 0)
    container.Position = UDim2.new(1, -340, 0, 80)
    container.BackgroundTransparency = 1
end
container.Parent = screenGui

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, isMobile and 6 or 6)
layout.FillDirection = isMobile and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = container

local Cards = {} -- [orderID] = {frame}
local nextLayoutOrder = 0

local function makeCard(orderID, payload)
    nextLayoutOrder += 1

    local card = Instance.new("Frame")
    if isMobile then
        -- Compact horizontal card (180×88) for the top scroll strip
        card.Size = UDim2.new(0, 180, 1, 0)
    else
        -- Taller card (110) so wrapped two-line drink names + size badge fit cleanly
        card.Size = UDim2.new(1, 0, 0, 110)
    end
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

    -- Size badge: smaller on mobile (36×16) so it fits the 180-wide card.
    local sizeBadge = Instance.new("TextLabel")
    sizeBadge.Size = isMobile and UDim2.fromOffset(36, 16) or UDim2.fromOffset(50, 22)
    sizeBadge.Position = isMobile and UDim2.fromOffset(8, 6) or UDim2.fromOffset(12, 10)
    sizeBadge.BackgroundColor3 = SIZE_COLORS[payload.size] or Color3.fromRGB(120, 120, 120)
    sizeBadge.BorderSizePixel = 0
    sizeBadge.Text = (payload.size or "?"):upper()
    sizeBadge.Font = Enum.Font.GothamBlack
    sizeBadge.TextSize = isMobile and 9 or 12
    sizeBadge.TextColor3 = Color3.new(1, 1, 1)
    sizeBadge.Parent = card
    local sizeBadgeCorner = Instance.new("UICorner")
    sizeBadgeCorner.CornerRadius = UDim.new(0, 4)
    sizeBadgeCorner.Parent = sizeBadge

    -- Title — sized to the layout. On mobile the tip badge sits BELOW
    -- the title (no horizontal room beside it), so title gets full width.
    local title = Instance.new("TextLabel")
    if isMobile then
        title.Size = UDim2.new(1, -56, 0, 24)
        title.Position = UDim2.fromOffset(48, 4)
        title.TextSize = 12
    else
        title.Size = UDim2.new(1, -178, 0, 38)
        title.Position = UDim2.fromOffset(70, 6)
        title.TextSize = 16
    end
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextYAlignment = Enum.TextYAlignment.Top
    title.Font = Enum.Font.GothamBold
    title.Text = payload.displayName
    title.TextWrapped = true
    title.TextColor3 = payload.isSecret and Color3.new(1, 1, 1) or Color3.fromRGB(20, 20, 20)
    title.Parent = card

    -- Tip badge — top-right on desktop; bottom-right on mobile (smaller).
    local tipLabel = Instance.new("TextLabel")
    tipLabel.AnchorPoint = isMobile and Vector2.new(1, 1) or Vector2.new(1, 0)
    tipLabel.Size = isMobile and UDim2.new(0, 70, 0, 22) or UDim2.new(0, 100, 0, 26)
    tipLabel.Position = isMobile and UDim2.new(1, -6, 1, -6) or UDim2.new(1, -8, 0, 6)
    tipLabel.BackgroundTransparency = 1
    tipLabel.Font = Enum.Font.GothamBlack
    tipLabel.TextSize = isMobile and 14 or 20
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
    if isMobile then
        details.Size = UDim2.new(1, -88, 0, 60)
        details.Position = UDim2.fromOffset(8, 28)
        details.TextSize = 10
    else
        -- Shifted down to y=50 so a 2-line wrapped title (top 6→44) doesn't
        -- overlap. Card is 110 tall; details fits in 50→104.
        details.Size = UDim2.new(1, -16, 0, 54)
        details.Position = UDim2.fromOffset(12, 50)
        details.TextSize = 12
    end
    details.BackgroundTransparency = 1
    details.TextXAlignment = Enum.TextXAlignment.Left
    details.TextYAlignment = Enum.TextYAlignment.Top
    details.Font = Enum.Font.Gotham
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

-- (Old applyResponsiveContainer narrowed the right-side queue on small
-- desktop windows. The new top-level isMobile branch above handles that
-- case via a totally different layout, so the responsive-resize hook
-- isn't needed anymore.)
