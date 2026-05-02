-- MerchShopUI.client.lua
-- Shop browser for Dutch Bros merch. Toggle with B.
-- Reads MerchCatalog directly (it's in ReplicatedStorage). Purchases route through
-- the BuyMerch RemoteEvent so the server validates ownership + balance.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MerchCatalog = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MerchCatalog"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BuyMerch = Remotes:WaitForChild("BuyMerch")
local PurchaseResult = Remotes:WaitForChild("PurchaseResult")
local ProfileLoaded = Remotes:WaitForChild("ProfileLoaded")
local BroBucksUpdated = Remotes:WaitForChild("BroBucksUpdated")

local player = Players.LocalPlayer
local DUTCH_BLUE = Color3.fromHex("#005AAB")

local profile = nil

local RarityColors = {
    Common    = Color3.fromRGB(180, 180, 180),
    Uncommon  = Color3.fromRGB(80, 200, 120),
    Rare      = Color3.fromRGB(80, 150, 240),
    Epic      = Color3.fromRGB(180, 80, 220),
    Legendary = Color3.fromRGB(240, 180, 60),
}

-- ===== UI =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MerchShop"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromScale(0.78, 0.85)
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
frame.Parent = screenGui
local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 12)
frameCorner.Parent = frame

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 56)
header.BackgroundColor3 = DUTCH_BLUE
header.Parent = frame
local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 12)
headerCorner.Parent = header

local title = Instance.new("TextLabel")
title.Size = UDim2.new(0.6, 0, 1, 0)
title.BackgroundTransparency = 1
title.Text = "Dutch Bros Merch"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 22
title.TextXAlignment = Enum.TextXAlignment.Left
title.Position = UDim2.fromOffset(20, 0)
title.Parent = header

local balanceLabel = Instance.new("TextLabel")
balanceLabel.Size = UDim2.new(0.4, -20, 1, 0)
balanceLabel.Position = UDim2.new(0.6, 0, 0, 0)
balanceLabel.BackgroundTransparency = 1
balanceLabel.Text = "Bro Bucks: ?"
balanceLabel.TextColor3 = Color3.new(1, 1, 1)
balanceLabel.Font = Enum.Font.GothamMedium
balanceLabel.TextSize = 18
balanceLabel.TextXAlignment = Enum.TextXAlignment.Right
balanceLabel.Parent = header

local function setBalance(amount)
    balanceLabel.Text = ("Bro Bucks: %d"):format(amount or 0)
end

local CATEGORIES = {"Tops", "Headwear", "Bottoms", "Footwear", "Accessories", "Seasonal"}
local activeCategory = "Tops"

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -16, 0, 36)
tabBar.Position = UDim2.fromOffset(8, 64)
tabBar.BackgroundTransparency = 1
tabBar.Parent = frame

local grid = Instance.new("ScrollingFrame")
grid.Size = UDim2.new(1, -16, 1, -116)
grid.Position = UDim2.fromOffset(8, 108)
grid.BackgroundTransparency = 1
grid.BorderSizePixel = 0
grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
grid.CanvasSize = UDim2.new(0, 0, 0, 0)
grid.ScrollBarThickness = 6
grid.Parent = frame

local gridLayout = Instance.new("UIGridLayout")
-- Taller cells (240) to fit the 140-tall image header on top of the
-- existing text + buy area.
gridLayout.CellSize = UDim2.fromOffset(190, 240)
gridLayout.CellPadding = UDim2.fromOffset(10, 10)
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
gridLayout.Parent = grid

local cardRefreshers = {}

-- ============================================================
-- Try-on preview popup — opened when a card with image data is clicked.
-- Modal overlay with character mockup + name/rarity/desc + Cancel/Buy.
-- ============================================================
local activePopup = nil
local function showTryOnPopup(item)
    if activePopup then activePopup:Destroy() end

    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.4
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 30
    overlay.Parent = screenGui
    activePopup = overlay

    -- Tap-outside backdrop closes
    local backdrop = Instance.new("TextButton")
    backdrop.Size = UDim2.fromScale(1, 1)
    backdrop.BackgroundTransparency = 1
    backdrop.Text = ""
    backdrop.AutoButtonColor = false
    backdrop.ZIndex = 30
    backdrop.Parent = overlay
    backdrop.MouseButton1Click:Connect(function()
        if activePopup == overlay then activePopup = nil end
        overlay:Destroy()
    end)

    local panel = Instance.new("Frame")
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.5)
    panel.Size = UDim2.fromOffset(500, 600)
    panel.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
    panel.BorderSizePixel = 0
    panel.ZIndex = 32
    panel.Parent = overlay
    -- Mobile-responsive shrink: 500×600 is desktop; phones get a UIScale
    -- that fits the panel into ~90% of the viewport width.
    local panelScale = Instance.new("UIScale")
    panelScale.Parent = panel
    local function applyPanelScale()
        local width = screenGui.AbsoluteSize.X
        if width < 800 then
            panelScale.Scale = math.clamp(width * 0.95 / 500, 0.5, 0.9)
        else
            panelScale.Scale = 1
        end
    end
    applyPanelScale()
    screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyPanelScale)
    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 12)
    panelCorner.Parent = panel
    local panelStroke = Instance.new("UIStroke")
    panelStroke.Color = RarityColors[item.rarity] or DUTCH_BLUE
    panelStroke.Thickness = 3
    panelStroke.Parent = panel

    -- Flat-lay product detail (popup is the "tell me about this item" view;
    -- the card already showed the character wearing it). Falls back to the
    -- character mockup if the product shot is missing.
    local img = Instance.new("ImageLabel")
    img.Size = UDim2.fromOffset(460, 380)
    img.Position = UDim2.fromOffset(20, 20)
    img.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
    img.BorderSizePixel = 0
    img.Image = item.productImage or item.characterImage or ""
    img.ScaleType = Enum.ScaleType.Fit
    img.ZIndex = 33
    img.Parent = panel
    local imgCorner = Instance.new("UICorner")
    imgCorner.CornerRadius = UDim.new(0, 8)
    imgCorner.Parent = img

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, -40, 0, 30)
    nameLbl.Position = UDim2.fromOffset(20, 410)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = item.name
    nameLbl.Font = Enum.Font.GothamBlack
    nameLbl.TextSize = 22
    nameLbl.TextColor3 = Color3.new(1, 1, 1)
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.ZIndex = 33
    nameLbl.Parent = panel

    local rarityLbl = Instance.new("TextLabel")
    rarityLbl.Size = UDim2.new(1, -40, 0, 18)
    rarityLbl.Position = UDim2.fromOffset(20, 442)
    rarityLbl.BackgroundTransparency = 1
    rarityLbl.Text = item.rarity:upper()
    rarityLbl.Font = Enum.Font.GothamBold
    rarityLbl.TextSize = 13
    rarityLbl.TextColor3 = RarityColors[item.rarity] or Color3.fromRGB(180, 180, 180)
    rarityLbl.TextXAlignment = Enum.TextXAlignment.Left
    rarityLbl.ZIndex = 33
    rarityLbl.Parent = panel

    local descLbl = Instance.new("TextLabel")
    descLbl.Size = UDim2.new(1, -40, 0, 60)
    descLbl.Position = UDim2.fromOffset(20, 466)
    descLbl.BackgroundTransparency = 1
    descLbl.Text = item.description or ""
    descLbl.Font = Enum.Font.Gotham
    descLbl.TextSize = 14
    descLbl.TextColor3 = Color3.fromRGB(200, 200, 210)
    descLbl.TextXAlignment = Enum.TextXAlignment.Left
    descLbl.TextYAlignment = Enum.TextYAlignment.Top
    descLbl.TextWrapped = true
    descLbl.ZIndex = 33
    descLbl.Parent = panel

    -- Cancel + Buy
    local function makePopupButton(text, color, posX, onTap)
        local b = Instance.new("TextButton")
        b.Size = UDim2.fromOffset(220, 50)
        b.Position = UDim2.fromOffset(posX, 530)
        b.BackgroundColor3 = color
        b.BorderSizePixel = 0
        b.Text = text
        b.Font = Enum.Font.GothamBold
        b.TextSize = 18
        b.TextColor3 = Color3.new(1, 1, 1)
        b.AutoButtonColor = true
        b.ZIndex = 33
        b.Parent = panel
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 8)
        c.Parent = b
        b.MouseButton1Click:Connect(onTap)
        return b
    end

    makePopupButton("CANCEL", Color3.fromRGB(80, 80, 90), 20, function()
        if activePopup == overlay then activePopup = nil end
        overlay:Destroy()
    end)

    local owned = profile and profile.ownedMerch and profile.ownedMerch[item.id]
    local buyText = owned and "OWNED" or ("BUY · %d BB"):format(item.price)
    local buyColor = owned and Color3.fromRGB(60, 60, 70) or DUTCH_BLUE
    local buyBtn = makePopupButton(buyText, buyColor, 260, function()
        if owned then return end
        BuyMerch:FireServer(item.id)
        if activePopup == overlay then activePopup = nil end
        overlay:Destroy()
    end)
    if owned then buyBtn.AutoButtonColor = false end
end

local function makeItemCard(item)
    local card = Instance.new("Frame")
    card.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
    card.ClipsDescendants = true
    card.Parent = grid
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = card

    -- Image header (top 140px). Shows the character mockup ("look") so
    -- players see the item being worn. Falls back to the flat-lay
    -- product image when the character mockup is missing, then to a
    -- solid Dutch Bros blue BackgroundColor3 placeholder.
    local image = Instance.new("ImageLabel")
    image.Size = UDim2.new(1, 0, 0, 140)
    image.Position = UDim2.fromOffset(0, 0)
    image.BackgroundColor3 = DUTCH_BLUE
    image.BorderSizePixel = 0
    image.Image = item.characterImage or item.productImage or ""
    image.ScaleType = Enum.ScaleType.Crop
    image.Parent = card

    -- Rarity strip sits at the bottom of the image / top of text area.
    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(1, 0, 0, 4)
    accent.Position = UDim2.fromOffset(0, 140)
    accent.BackgroundColor3 = RarityColors[item.rarity] or Color3.fromRGB(180, 180, 180)
    accent.BorderSizePixel = 0
    accent.Parent = card

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -12, 0, 22)
    nameLabel.Position = UDim2.fromOffset(8, 148)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = item.name
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 14
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Parent = card

    local rarity = Instance.new("TextLabel")
    rarity.Size = UDim2.new(1, -12, 0, 14)
    rarity.Position = UDim2.fromOffset(8, 170)
    rarity.BackgroundTransparency = 1
    rarity.Text = item.rarity
    rarity.TextColor3 = RarityColors[item.rarity] or Color3.fromRGB(180, 180, 180)
    rarity.Font = Enum.Font.Gotham
    rarity.TextSize = 11
    rarity.TextXAlignment = Enum.TextXAlignment.Left
    rarity.Parent = card

    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -12, 0, 26)
    desc.Position = UDim2.fromOffset(8, 186)
    desc.BackgroundTransparency = 1
    desc.Text = item.description or ""
    desc.TextColor3 = Color3.fromRGB(200, 200, 200)
    desc.Font = Enum.Font.Gotham
    desc.TextSize = 10
    desc.TextWrapped = true
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.TextYAlignment = Enum.TextYAlignment.Top
    desc.Parent = card

    local buyBtn = Instance.new("TextButton")
    buyBtn.Size = UDim2.new(1, -16, 0, 28)
    buyBtn.Position = UDim2.new(0, 8, 1, -32)
    buyBtn.BackgroundColor3 = DUTCH_BLUE
    buyBtn.TextColor3 = Color3.new(1, 1, 1)
    buyBtn.Font = Enum.Font.GothamBold
    buyBtn.TextSize = 13
    buyBtn.Parent = card
    local buyCorner = Instance.new("UICorner")
    buyCorner.CornerRadius = UDim.new(0, 6)
    buyCorner.Parent = buyBtn

    local function refresh()
        if profile and profile.ownedMerch and profile.ownedMerch[item.id] then
            buyBtn.Text = "Owned"
            buyBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
            buyBtn.AutoButtonColor = false
        else
            buyBtn.Text = ("Buy · %d BB"):format(item.price)
            buyBtn.BackgroundColor3 = DUTCH_BLUE
            buyBtn.AutoButtonColor = true
        end
    end
    refresh()

    -- If the item has any preview image, route the buy button through
    -- the try-on popup. Otherwise (most existing items) keep the old
    -- one-tap buy behavior.
    local hasPreview = (item.productImage and item.productImage ~= "")
        or (item.characterImage and item.characterImage ~= "")
    buyBtn.MouseButton1Click:Connect(function()
        if profile and profile.ownedMerch and profile.ownedMerch[item.id] then return end
        if hasPreview then
            showTryOnPopup(item)
        else
            BuyMerch:FireServer(item.id)
        end
    end)

    return refresh
end

local function refreshGrid()
    for _, child in ipairs(grid:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end
    cardRefreshers = {}
    for _, item in ipairs(MerchCatalog.GetByCategory(activeCategory)) do
        local refresh = makeItemCard(item)
        table.insert(cardRefreshers, refresh)
    end
end

for i, cat in ipairs(CATEGORIES) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1/#CATEGORIES, -4, 1, 0)
    btn.Position = UDim2.new((i-1)/#CATEGORIES, 2, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 14
    btn.Text = cat
    btn.AutoButtonColor = true
    btn.Parent = tabBar
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    btn.MouseButton1Click:Connect(function()
        activeCategory = cat
        refreshGrid()
    end)
end

refreshGrid()

ProfileLoaded.OnClientEvent:Connect(function(p)
    profile = p
    setBalance(p.broBucks)
    for _, refresh in ipairs(cardRefreshers) do refresh() end
end)
BroBucksUpdated.OnClientEvent:Connect(function(amount)
    if profile then profile.broBucks = amount end
    setBalance(amount)
end)
PurchaseResult.OnClientEvent:Connect(function(success, itemId, payload)
    if success and profile then
        profile.ownedMerch[itemId] = true
        for _, refresh in ipairs(cardRefreshers) do refresh() end
    elseif not success then
        warn(("[MerchShop] Purchase failed: %s"):format(tostring(payload)))
    end
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.B then
        screenGui.Enabled = not screenGui.Enabled
    end
end)

-- ===== Mobile / small-screen scaling =====
local merchScale = Instance.new("UIScale")
merchScale.Parent = frame
local function applyMerchResponsiveSize()
    local width = screenGui.AbsoluteSize.X
    if width < 800 then
        frame.Size = UDim2.fromScale(0.96, 0.92)
        merchScale.Scale = math.clamp(width / 1280, 0.55, 0.85)
    else
        frame.Size = UDim2.fromScale(0.78, 0.85)
        merchScale.Scale = 1
    end
end
applyMerchResponsiveSize()
screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyMerchResponsiveSize)
