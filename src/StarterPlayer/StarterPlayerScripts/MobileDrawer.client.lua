-- MobileDrawer.client.lua
-- Mobile-only slide-in drawer that owns ALL of the moved-from-HUD UI:
-- tips, holding-cup status, active orders, and the action buttons that
-- used to clutter the screen (Chat / Shop / Outfit / Ping / Help).
--
-- The drawer is the master mobile UI hub. CupHud, OrderUI, and the
-- TipsCounter early-return on mobile and let this script subscribe to
-- their remotes directly so we own the rendering.
--
-- Open via _G.OpenMobileDrawer() (called from MobileControls' MENU
-- button). Close via the X, the backdrop tap, or _G.CloseMobileDrawer.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
if not isMobile then return end

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local TipsUpdated  = Remotes:WaitForChild("TipsUpdated")
local CupUpdated   = Remotes:WaitForChild("CupUpdated")
local NewOrder     = Remotes:WaitForChild("NewOrder")
local OrderComplete = Remotes:WaitForChild("OrderComplete")
local OrderFailed  = Remotes:WaitForChild("OrderFailed")
local PingPlaced   = Remotes:WaitForChild("PingPlaced")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DUTCH_BLUE  = Color3.fromRGB(0,   90,  171)
local DUTCH_ORANGE = Color3.fromRGB(255, 122,  0)
local TIP_GOLD    = Color3.fromRGB(255, 200, 50)
local SECRET_GOLD = Color3.fromRGB(255, 215, 60)
local WHITE       = Color3.new(1, 1, 1)
local BLACK       = Color3.fromRGB(20, 20, 20)
local SIZE_COLORS = {
    Small  = Color3.fromRGB(240, 200, 60),
    Medium = Color3.fromRGB(0,   120, 215),
    Large  = Color3.fromRGB(220, 80,  80),
}

-- ============================================================
-- ScreenGui + drawer geometry
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MobileDrawer"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 40
screenGui.Enabled = true   -- always Enabled; visibility controlled by drawer position
screenGui.Parent = playerGui

-- Backdrop: tap-anywhere-outside-drawer to close. Sits BEHIND drawer.
local backdrop = Instance.new("TextButton")
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = BLACK
backdrop.BackgroundTransparency = 1   -- invisible until drawer opens
backdrop.Text = ""
backdrop.AutoButtonColor = false
backdrop.Visible = false
backdrop.ZIndex = 1
backdrop.Parent = screenGui

local DRAWER_HIDDEN_X = 1.0    -- AnchorPoint(0,0): left edge at screen-right (off-screen)
local DRAWER_VISIBLE_X = 0.4   -- left edge at 40% of screen-width

local drawer = Instance.new("Frame")
drawer.Size = UDim2.new(0.6, 0, 1, 0)
drawer.AnchorPoint = Vector2.new(0, 0)
drawer.Position = UDim2.new(DRAWER_HIDDEN_X, 0, 0, 0)
drawer.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
drawer.BorderSizePixel = 0
drawer.ZIndex = 5
drawer.Parent = screenGui
local drawerStroke = Instance.new("UIStroke")
drawerStroke.Color = DUTCH_BLUE
drawerStroke.Thickness = 2
drawerStroke.Transparency = 0.4
drawerStroke.Parent = drawer

-- Close X button at top-right of drawer
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(40, 40)
closeBtn.AnchorPoint = Vector2.new(1, 0)
closeBtn.Position = UDim2.new(1, -8, 0, 8)
closeBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
closeBtn.Text = "✕"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 22
closeBtn.TextColor3 = WHITE
closeBtn.AutoButtonColor = true
closeBtn.ZIndex = 7
closeBtn.Parent = drawer
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(1, 0)
closeCorner.Parent = closeBtn

-- Scrollable content area
local content = Instance.new("ScrollingFrame")
content.Size = UDim2.new(1, -16, 1, -56)
content.Position = UDim2.fromOffset(8, 56)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollingDirection = Enum.ScrollingDirection.Y
content.ScrollBarThickness = 4
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.CanvasSize = UDim2.new(0, 0, 0, 0)
content.ZIndex = 6
content.Parent = drawer

local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 10)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Parent = content

-- ============================================================
-- Section helpers
-- ============================================================
local function makeSectionFrame(layoutOrder, height)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, height)
    f.BackgroundColor3 = Color3.fromRGB(34, 36, 44)
    f.BorderSizePixel = 0
    f.LayoutOrder = layoutOrder
    f.ZIndex = 6
    f.Parent = content
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = f
    return f
end

local function makeLabel(parent, text, font, size, color, position, size2)
    local l = Instance.new("TextLabel")
    l.Size = size2 or UDim2.new(1, -16, 0, 24)
    l.Position = position or UDim2.fromOffset(8, 4)
    l.BackgroundTransparency = 1
    l.Text = text
    l.Font = font or Enum.Font.GothamBold
    l.TextSize = size or 14
    l.TextColor3 = color or WHITE
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextYAlignment = Enum.TextYAlignment.Top
    l.ZIndex = 7
    l.Parent = parent
    return l
end

-- ============================================================
-- Section: Tips
-- ============================================================
local tipsSection = makeSectionFrame(1, 64)
makeLabel(tipsSection, "TIPS THIS SHIFT", Enum.Font.GothamSemibold, 11, Color3.fromRGB(180, 180, 200), UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 14))
local tipsValue = makeLabel(tipsSection, "$0", Enum.Font.GothamBlack, 28, TIP_GOLD, UDim2.fromOffset(12, 22), UDim2.new(1, -24, 0, 36))

TipsUpdated.OnClientEvent:Connect(function(total)
    tipsValue.Text = "$" .. tostring(total or 0)
end)

-- ============================================================
-- Section: Holding (current cup)
-- ============================================================
local holdSection = makeSectionFrame(2, 150)
makeLabel(holdSection, "CURRENT CUP", Enum.Font.GothamSemibold, 11, Color3.fromRGB(180, 180, 200), UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 14))
local holdHeader = makeLabel(holdSection, "Walk to a cup tower to start", Enum.Font.GothamBold, 16, WHITE, UDim2.fromOffset(12, 22), UDim2.new(1, -24, 0, 24))
local holdBaseLine = makeLabel(holdSection, "", Enum.Font.Gotham, 13, Color3.fromRGB(220, 220, 230), UDim2.fromOffset(12, 50), UDim2.new(1, -24, 0, 18))
local holdSyrupLine = makeLabel(holdSection, "", Enum.Font.Gotham, 13, Color3.fromRGB(220, 220, 230), UDim2.fromOffset(12, 70), UDim2.new(1, -24, 0, 18))
local holdToppingLine = makeLabel(holdSection, "", Enum.Font.Gotham, 13, Color3.fromRGB(220, 220, 230), UDim2.fromOffset(12, 90), UDim2.new(1, -24, 0, 18))
local holdLidLine = makeLabel(holdSection, "", Enum.Font.GothamBold, 13, DUTCH_ORANGE, UDim2.fromOffset(12, 116), UDim2.new(1, -24, 0, 22))

local function joinList(list, fallback)
    if not list or #list == 0 then return fallback end
    return table.concat(list, ", ")
end

CupUpdated.OnClientEvent:Connect(function(cup)
    if not cup then
        holdHeader.Text = "Walk to a cup tower to start"
        holdBaseLine.Text = ""
        holdSyrupLine.Text = ""
        holdToppingLine.Text = ""
        holdLidLine.Text = ""
        return
    end
    holdHeader.Text = ("Holding: %s Cup"):format(cup.size or "?")
    holdBaseLine.Text = "Base: " .. (cup.base or "(empty)")
    holdSyrupLine.Text = "Syrups: " .. joinList(cup.syrups, "(none)")
    holdToppingLine.Text = "Toppings: " .. joinList(cup.toppings, "(none)")
    if cup.hasLid then
        holdLidLine.Text = "✓ Lidded — ready to hand off"
        holdLidLine.TextColor3 = Color3.fromRGB(120, 220, 140)
    else
        holdLidLine.Text = "✗ No lid"
        holdLidLine.TextColor3 = DUTCH_ORANGE
    end
end)

-- ============================================================
-- Section: Active Orders
-- ============================================================
local ordersSection = makeSectionFrame(3, 280)
makeLabel(ordersSection, "ACTIVE ORDERS", Enum.Font.GothamSemibold, 11, Color3.fromRGB(180, 180, 200), UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 14))

local ordersList = Instance.new("ScrollingFrame")
ordersList.Size = UDim2.new(1, -16, 1, -32)
ordersList.Position = UDim2.fromOffset(8, 26)
ordersList.BackgroundTransparency = 1
ordersList.BorderSizePixel = 0
ordersList.ScrollingDirection = Enum.ScrollingDirection.Y
ordersList.ScrollBarThickness = 3
ordersList.AutomaticCanvasSize = Enum.AutomaticSize.Y
ordersList.CanvasSize = UDim2.new(0, 0, 0, 0)
ordersList.ZIndex = 7
ordersList.Parent = ordersSection
local ordersLayout = Instance.new("UIListLayout")
ordersLayout.Padding = UDim.new(0, 6)
ordersLayout.SortOrder = Enum.SortOrder.LayoutOrder
ordersLayout.Parent = ordersList

local OrderCards = {}   -- [orderID] = Frame
local nextOrderLayout = 0

local function makeOrderCard(orderID, payload)
    nextOrderLayout += 1
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 70)
    card.BackgroundColor3 = payload.isSecret and Color3.fromRGB(80, 30, 120) or Color3.fromRGB(255, 255, 255)
    card.BorderSizePixel = 0
    card.LayoutOrder = nextOrderLayout
    card.ZIndex = 8
    card.Parent = ordersList
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = card

    -- Size badge
    local sizeBadge = Instance.new("TextLabel")
    sizeBadge.Size = UDim2.fromOffset(48, 18)
    sizeBadge.Position = UDim2.fromOffset(8, 6)
    sizeBadge.BackgroundColor3 = SIZE_COLORS[payload.size] or Color3.fromRGB(120, 120, 120)
    sizeBadge.BorderSizePixel = 0
    sizeBadge.Text = (payload.size or "?"):upper()
    sizeBadge.Font = Enum.Font.GothamBlack
    sizeBadge.TextSize = 10
    sizeBadge.TextColor3 = WHITE
    sizeBadge.ZIndex = 9
    sizeBadge.Parent = card
    local sbc = Instance.new("UICorner")
    sbc.CornerRadius = UDim.new(0, 4)
    sbc.Parent = sizeBadge

    -- Tip
    local tipLbl = Instance.new("TextLabel")
    tipLbl.AnchorPoint = Vector2.new(1, 0)
    tipLbl.Size = UDim2.new(0, 84, 0, 18)
    tipLbl.Position = UDim2.new(1, -8, 0, 6)
    tipLbl.BackgroundTransparency = 1
    tipLbl.Font = Enum.Font.GothamBlack
    tipLbl.TextSize = 14
    tipLbl.TextXAlignment = Enum.TextXAlignment.Right
    tipLbl.Text = payload.isSecret and "★ $15" or ("$" .. tostring(payload.tip or 0))
    tipLbl.TextColor3 = payload.isSecret and SECRET_GOLD or TIP_GOLD
    tipLbl.ZIndex = 9
    tipLbl.Parent = card

    -- Drink name
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, -16, 0, 18)
    nameLbl.Position = UDim2.fromOffset(8, 26)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = payload.displayName
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 13
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.TextColor3 = payload.isSecret and WHITE or Color3.fromRGB(20, 20, 20)
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
    nameLbl.ZIndex = 9
    nameLbl.Parent = card

    -- Ingredient line (1-line summary)
    local ingLbl = Instance.new("TextLabel")
    ingLbl.Size = UDim2.new(1, -16, 0, 16)
    ingLbl.Position = UDim2.fromOffset(8, 46)
    ingLbl.BackgroundTransparency = 1
    local detail = ("%s base"):format(payload.base or "?")
    if payload.syrups and #payload.syrups > 0 then
        detail = detail .. " · " .. table.concat(payload.syrups, ", ")
    end
    ingLbl.Text = detail
    ingLbl.Font = Enum.Font.Gotham
    ingLbl.TextSize = 10
    ingLbl.TextXAlignment = Enum.TextXAlignment.Left
    ingLbl.TextColor3 = payload.isSecret and Color3.fromRGB(220, 200, 255) or Color3.fromRGB(80, 80, 90)
    ingLbl.TextTruncate = Enum.TextTruncate.AtEnd
    ingLbl.ZIndex = 9
    ingLbl.Parent = card

    OrderCards[orderID] = card
end

local function removeOrderCard(orderID)
    local c = OrderCards[orderID]
    if c then
        c:Destroy()
        OrderCards[orderID] = nil
    end
end

NewOrder.OnClientEvent:Connect(makeOrderCard)
OrderComplete.OnClientEvent:Connect(function(orderID) removeOrderCard(orderID) end)
OrderFailed.OnClientEvent:Connect(function(orderID) removeOrderCard(orderID) end)

-- ============================================================
-- Section: Action buttons
-- ============================================================
local actionsSection = makeSectionFrame(4, 296)
makeLabel(actionsSection, "ACTIONS", Enum.Font.GothamSemibold, 11, Color3.fromRGB(180, 180, 200), UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 14))

local function toggleGui(name)
    local gui = playerGui:FindFirstChild(name)
    if gui then gui.Enabled = not gui.Enabled end
end

local function placePing()
    local character = player.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then PingPlaced:FireServer(hrp.Position) end
end

local closeDrawer  -- forward decl

local function makeActionButton(index, emoji, label, color, onTap)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -16, 0, 50)
    b.Position = UDim2.fromOffset(8, 28 + (index - 1) * 56)
    b.BackgroundColor3 = color
    b.BackgroundTransparency = 0.05
    b.Text = emoji .. "  " .. label
    b.Font = Enum.Font.GothamBold
    b.TextSize = 16
    b.TextColor3 = WHITE
    b.TextStrokeTransparency = 0.5
    b.AutoButtonColor = true
    b.ZIndex = 8
    b.Parent = actionsSection
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 8)
    bc.Parent = b
    b.MouseButton1Click:Connect(function()
        onTap()
        if closeDrawer then closeDrawer() end
    end)
end

makeActionButton(1, "💬", "CHAT",        Color3.fromRGB(60,  130, 220), function() toggleGui("QuickChatWheel") end)
makeActionButton(2, "🛒", "SHOP",        Color3.fromRGB(60,  180, 100), function() toggleGui("MerchShop") end)
makeActionButton(3, "👕", "OUTFIT",      Color3.fromRGB(170, 90,  200), function() toggleGui("CharacterCustomizer") end)
makeActionButton(4, "📍", "PLACE PING",  DUTCH_ORANGE,                  placePing)
makeActionButton(5, "❓", "HOW TO PLAY", Color3.fromRGB(80,  80,  100), function() toggleGui("InstructionsScreen") end)

-- ============================================================
-- Open / close
-- ============================================================
local isOpen = false
local function openDrawer()
    if isOpen then return end
    isOpen = true
    backdrop.Visible = true
    TweenService:Create(backdrop, TweenInfo.new(0.18), {BackgroundTransparency = 0.5}):Play()
    TweenService:Create(drawer, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(DRAWER_VISIBLE_X, 0, 0, 0)
    }):Play()
end

closeDrawer = function()
    if not isOpen then return end
    isOpen = false
    TweenService:Create(backdrop, TweenInfo.new(0.18), {BackgroundTransparency = 1}):Play()
    TweenService:Create(drawer, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.new(DRAWER_HIDDEN_X, 0, 0, 0)
    }):Play()
    task.delay(0.2, function()
        if not isOpen then backdrop.Visible = false end
    end)
end

backdrop.MouseButton1Click:Connect(closeDrawer)
closeBtn.MouseButton1Click:Connect(closeDrawer)

-- Public hooks for MobileControls' MENU button
_G.OpenMobileDrawer = openDrawer
_G.CloseMobileDrawer = closeDrawer
_G.ToggleMobileDrawer = function()
    if isOpen then closeDrawer() else openDrawer() end
end
