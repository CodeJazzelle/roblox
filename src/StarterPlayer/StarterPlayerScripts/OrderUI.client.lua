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
-- Mobile shows orders inside the slide-in drawer (MobileDrawer.client.lua),
-- so the persistent right-side queue is hidden entirely.
if isMobile then return end

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

-- On mobile the queue lives on the LEFT EDGE of the screen as a vertical
-- 27%-wide strip — keeps the bottom of the screen free for action
-- buttons and the right side free for the menu button. Desktop keeps
-- the original vertical right-side queue.
local container
if isMobile then
    container = Instance.new("ScrollingFrame")
    container.AnchorPoint = Vector2.new(0, 0)
    container.Size = UDim2.new(0.27, 0, 0.6, 0)
    container.Position = UDim2.new(0, 8, 0, 130)   -- below shrunk timer + tips block
    container.BackgroundTransparency = 1
    container.BorderSizePixel = 0
    container.ScrollingDirection = Enum.ScrollingDirection.Y
    container.ScrollBarThickness = 4
    container.AutomaticCanvasSize = Enum.AutomaticSize.Y
    container.CanvasSize = UDim2.new(0, 0, 0, 0)
else
    container = Instance.new("Frame")
    container.Size = UDim2.new(0, 320, 0.8, 0)
    container.Position = UDim2.new(1, -340, 0, 80)
    container.BackgroundTransparency = 1
end
container.Parent = screenGui

-- Both layouts are vertical now (the previous mobile horizontal strip
-- is gone). Keeping the same instance keeps card LayoutOrder semantics.
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.FillDirection = Enum.FillDirection.Vertical
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = container

local Cards = {} -- [orderID] = {frame}
local nextLayoutOrder = 0

-- ============================================================
-- Mobile-only recipe popup
-- ============================================================
-- The compact mobile card hides the ingredient list to save space; tap
-- the card to open this popup with the full recipe. A full-screen
-- transparent backdrop button below the popup closes it on tap-outside.
local activePopup = nil
local function showRecipePopup(payload)
    if activePopup then activePopup:Destroy() end

    local overlay = Instance.new("Frame")
    overlay.Name = "RecipeOverlay"
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.45
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 20
    overlay.Parent = screenGui
    activePopup = overlay

    local backdrop = Instance.new("TextButton")
    backdrop.Size = UDim2.fromScale(1, 1)
    backdrop.BackgroundTransparency = 1
    backdrop.Text = ""
    backdrop.AutoButtonColor = false
    backdrop.ZIndex = 20
    backdrop.Parent = overlay
    backdrop.MouseButton1Click:Connect(function()
        if activePopup == overlay then activePopup = nil end
        overlay:Destroy()
    end)

    local popup = Instance.new("Frame")
    popup.AnchorPoint = Vector2.new(0.5, 0.5)
    popup.Position = UDim2.fromScale(0.5, 0.5)
    popup.Size = UDim2.new(0.78, 0, 0, 260)
    popup.BackgroundColor3 = payload.isSecret and Color3.fromRGB(80, 30, 120) or Color3.fromRGB(255, 255, 255)
    popup.BorderSizePixel = 0
    popup.ZIndex = 22
    popup.Parent = overlay
    local popupCorner = Instance.new("UICorner")
    popupCorner.CornerRadius = UDim.new(0, 12)
    popupCorner.Parent = popup
    local popupStroke = Instance.new("UIStroke")
    popupStroke.Color = TIP_GOLD
    popupStroke.Thickness = 2
    popupStroke.Parent = popup

    -- Size badge top-left of popup
    local sizeBadge = Instance.new("TextLabel")
    sizeBadge.Size = UDim2.fromOffset(64, 26)
    sizeBadge.Position = UDim2.fromOffset(12, 12)
    sizeBadge.BackgroundColor3 = SIZE_COLORS[payload.size] or Color3.fromRGB(120, 120, 120)
    sizeBadge.BorderSizePixel = 0
    sizeBadge.Text = (payload.size or "?"):upper()
    sizeBadge.Font = Enum.Font.GothamBlack
    sizeBadge.TextSize = 14
    sizeBadge.TextColor3 = Color3.new(1, 1, 1)
    sizeBadge.ZIndex = 23
    sizeBadge.Parent = popup
    local sizeBadgeCorner = Instance.new("UICorner")
    sizeBadgeCorner.CornerRadius = UDim.new(0, 4)
    sizeBadgeCorner.Parent = sizeBadge

    -- Tip top-right
    local tipLbl = Instance.new("TextLabel")
    tipLbl.AnchorPoint = Vector2.new(1, 0)
    tipLbl.Size = UDim2.new(0, 120, 0, 26)
    tipLbl.Position = UDim2.new(1, -12, 0, 12)
    tipLbl.BackgroundTransparency = 1
    tipLbl.Font = Enum.Font.GothamBlack
    tipLbl.TextSize = 18
    tipLbl.TextXAlignment = Enum.TextXAlignment.Right
    tipLbl.Text = payload.isSecret and "★ $15" or ("$" .. tostring(payload.tip or 0) .. " TIP")
    tipLbl.TextColor3 = payload.isSecret and SECRET_GOLD or TIP_GOLD
    tipLbl.ZIndex = 23
    tipLbl.Parent = popup

    -- Title (drink name)
    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -24, 0, 32)
    titleLbl.Position = UDim2.fromOffset(12, 50)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = payload.displayName
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 18
    titleLbl.TextWrapped = true
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.TextYAlignment = Enum.TextYAlignment.Top
    titleLbl.TextColor3 = payload.isSecret and Color3.new(1, 1, 1) or Color3.fromRGB(20, 20, 20)
    titleLbl.ZIndex = 23
    titleLbl.Parent = popup

    -- Recipe details
    local detailLbl = Instance.new("TextLabel")
    detailLbl.Size = UDim2.new(1, -24, 0, 130)
    detailLbl.Position = UDim2.fromOffset(12, 92)
    detailLbl.BackgroundTransparency = 1
    detailLbl.Font = Enum.Font.Gotham
    detailLbl.TextSize = 14
    detailLbl.TextWrapped = true
    detailLbl.TextXAlignment = Enum.TextXAlignment.Left
    detailLbl.TextYAlignment = Enum.TextYAlignment.Top
    detailLbl.TextColor3 = payload.isSecret and Color3.fromRGB(220, 200, 255) or Color3.fromRGB(60, 60, 60)
    local detail = ("Base: %s"):format(payload.base)
    if payload.syrups and #payload.syrups > 0 then
        detail = detail .. "\nSyrups: " .. table.concat(payload.syrups, ", ")
    end
    if payload.toppings and #payload.toppings > 0 then
        detail = detail .. "\nToppings: " .. table.concat(payload.toppings, ", ")
    end
    if payload.extraShots and payload.extraShots > 0 then
        detail = detail .. ("\n+ %d extra shot%s"):format(payload.extraShots, payload.extraShots == 1 and "" or "s")
    end
    detail = detail .. "\n\nTap anywhere to close"
    detailLbl.Text = detail
    detailLbl.ZIndex = 23
    detailLbl.Parent = popup
end

local function makeCard(orderID, payload)
    nextLayoutOrder += 1

    -- On mobile cards are TextButtons so a tap pops the recipe expansion.
    -- On desktop cards remain plain Frames.
    local card
    if isMobile then
        card = Instance.new("TextButton")
        card.Text = ""
        card.AutoButtonColor = false
        card.Size = UDim2.new(1, 0, 0, 80)   -- full strip width, compact
        card.MouseButton1Click:Connect(function() showRecipePopup(payload) end)
    else
        card = Instance.new("Frame")
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

    -- Size badge — top of card on mobile (full-strip width), top-left on desktop.
    local sizeBadge = Instance.new("TextLabel")
    if isMobile then
        sizeBadge.Size = UDim2.new(1, -12, 0, 14)
        sizeBadge.Position = UDim2.fromOffset(6, 5)
        sizeBadge.TextSize = 9
    else
        sizeBadge.Size = UDim2.fromOffset(50, 22)
        sizeBadge.Position = UDim2.fromOffset(12, 10)
        sizeBadge.TextSize = 12
    end
    sizeBadge.BackgroundColor3 = SIZE_COLORS[payload.size] or Color3.fromRGB(120, 120, 120)
    sizeBadge.BorderSizePixel = 0
    sizeBadge.Text = (payload.size or "?"):upper()
    sizeBadge.Font = Enum.Font.GothamBlack
    sizeBadge.TextColor3 = Color3.new(1, 1, 1)
    sizeBadge.Parent = card
    local sizeBadgeCorner = Instance.new("UICorner")
    sizeBadgeCorner.CornerRadius = UDim.new(0, 4)
    sizeBadgeCorner.Parent = sizeBadge

    -- Title — middle of card on mobile (2-line wrap), beside size on desktop.
    local title = Instance.new("TextLabel")
    if isMobile then
        title.Size = UDim2.new(1, -12, 0, 32)
        title.Position = UDim2.fromOffset(6, 22)
        title.TextSize = 11
        title.TextXAlignment = Enum.TextXAlignment.Center
    else
        title.Size = UDim2.new(1, -178, 0, 38)
        title.Position = UDim2.fromOffset(70, 6)
        title.TextSize = 16
        title.TextXAlignment = Enum.TextXAlignment.Left
    end
    title.BackgroundTransparency = 1
    title.TextYAlignment = Enum.TextYAlignment.Top
    title.Font = Enum.Font.GothamBold
    title.Text = payload.displayName
    title.TextWrapped = true
    title.TextColor3 = payload.isSecret and Color3.new(1, 1, 1) or Color3.fromRGB(20, 20, 20)
    title.Parent = card

    -- Tip badge — top-right on desktop; bottom strip on mobile.
    local tipLabel = Instance.new("TextLabel")
    if isMobile then
        tipLabel.AnchorPoint = Vector2.new(1, 1)
        tipLabel.Size = UDim2.new(1, -12, 0, 18)
        tipLabel.Position = UDim2.new(1, -6, 1, -5)
        tipLabel.TextSize = 12
        tipLabel.TextXAlignment = Enum.TextXAlignment.Right
    else
        tipLabel.AnchorPoint = Vector2.new(1, 0)
        tipLabel.Size = UDim2.new(0, 100, 0, 26)
        tipLabel.Position = UDim2.new(1, -8, 0, 6)
        tipLabel.TextSize = 20
        tipLabel.TextXAlignment = Enum.TextXAlignment.Right
    end
    tipLabel.BackgroundTransparency = 1
    tipLabel.Font = Enum.Font.GothamBlack
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

    -- Sub-tag under tip for secret-menu drinks (desktop only — mobile
    -- card is too small; secret status is shown via card background +
    -- the ★ in the tip badge).
    if payload.isSecret and not isMobile then
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

    -- Ingredient details are desktop-only; mobile cards are too compact
    -- and surface ingredients via the tap-to-expand recipe popup instead.
    if not isMobile then
        local details = Instance.new("TextLabel")
        details.Size = UDim2.new(1, -16, 0, 54)
        details.Position = UDim2.fromOffset(12, 50)
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
    end

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
