-- LeaderboardUI.client.lua
-- Slide-in leaderboard panel showing top 100 players across 3
-- categories (Tips / Combos / Drinks). Opens via:
--   * L key on PC
--   * Mobile drawer "🏆 LEADERBOARD" entry (calls _G.OpenLeaderboard)
--   * D-Pad Up on controller (handled in GamepadControls)
--
-- Data comes from the server via the LeaderboardQuery RemoteFunction,
-- which falls back to MOCK_DATA in Studio so the UI is testable
-- without a published place.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local LeaderboardQuery = Remotes:WaitForChild("LeaderboardQuery")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DUTCH_BLUE  = Color3.fromRGB(0,   90,  171)
local DUTCH_ORANGE = Color3.fromRGB(255, 122,  0)
local TIP_GOLD    = Color3.fromRGB(255, 200, 50)
local WHITE       = Color3.new(1, 1, 1)
local BLACK       = Color3.fromRGB(20, 20, 20)
local CARD_BG     = Color3.fromRGB(255, 255, 255)
local ROW_BG      = Color3.fromRGB(245, 247, 250)
local ROW_ALT     = Color3.fromRGB(232, 236, 242)
local ME_HIGHLIGHT = DUTCH_BLUE
local RANK_GOLD   = Color3.fromRGB(255, 200, 50)
local RANK_SILVER = Color3.fromRGB(190, 200, 215)
local RANK_BRONZE = Color3.fromRGB(190, 130, 70)

local CATEGORIES = {
    {key = "Tips",   label = "Top Tips",    suffix = " BB"},
    {key = "Combo",  label = "Top Combos",  suffix = "x"},
    {key = "Drinks", label = "Top Drinks",  suffix = ""},
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LeaderboardUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 45
screenGui.Enabled = false
screenGui.Parent = playerGui

-- Backdrop tap-out
local backdrop = Instance.new("TextButton")
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = BLACK
backdrop.BackgroundTransparency = 0.5
backdrop.Text = ""
backdrop.AutoButtonColor = false
backdrop.ZIndex = 1
backdrop.Parent = screenGui

-- Main panel slides in from the right.
local PANEL_VISIBLE_X = UDim2.new(1, -16, 0.5, 0)   -- right edge with 16px margin
local PANEL_HIDDEN_X  = UDim2.new(1.5, 0, 0.5, 0)   -- off-screen right
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = PANEL_HIDDEN_X
panel.Size = UDim2.fromOffset(600, 700)
panel.BackgroundColor3 = CARD_BG
panel.BorderSizePixel = 0
panel.ZIndex = 5
panel.Parent = screenGui
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = panel
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = DUTCH_BLUE
panelStroke.Thickness = 2
panelStroke.Parent = panel

-- Header
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 64)
header.BackgroundColor3 = DUTCH_BLUE
header.BorderSizePixel = 0
header.ZIndex = 6
header.Parent = panel
local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 12)
headerCorner.Parent = header

local headerTitle = Instance.new("TextLabel")
headerTitle.Size = UDim2.new(1, -180, 1, 0)
headerTitle.Position = UDim2.fromOffset(20, 0)
headerTitle.BackgroundTransparency = 1
headerTitle.Text = "🏆  LEADERBOARDS"
headerTitle.Font = Enum.Font.GothamBlack
headerTitle.TextSize = 24
headerTitle.TextColor3 = WHITE
headerTitle.TextXAlignment = Enum.TextXAlignment.Left
headerTitle.ZIndex = 7
headerTitle.Parent = header

local function makeHeaderButton(name, posOffset, label, color, onClick)
    local b = Instance.new("TextButton")
    b.Name = name
    b.Size = UDim2.fromOffset(72, 36)
    b.AnchorPoint = Vector2.new(1, 0.5)
    b.Position = UDim2.new(1, posOffset, 0.5, 0)
    b.BackgroundColor3 = color
    b.BorderSizePixel = 0
    b.Text = label
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.TextColor3 = WHITE
    b.AutoButtonColor = true
    b.ZIndex = 7
    b.Parent = header
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = b
    b.MouseButton1Click:Connect(onClick)
    return b
end

local closeBtn = makeHeaderButton("CloseBtn", -12, "✕  CLOSE", Color3.fromRGB(60, 60, 70), function()
    if _G.CloseLeaderboard then _G.CloseLeaderboard() end
end)
local refreshBtn  -- defined after refreshList below

-- Tab bar
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -24, 0, 40)
tabBar.Position = UDim2.fromOffset(12, 76)
tabBar.BackgroundTransparency = 1
tabBar.ZIndex = 6
tabBar.Parent = panel
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 6)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabBar

local tabButtons = {}

-- Scrollable list area
local listFrame = Instance.new("ScrollingFrame")
listFrame.Size = UDim2.new(1, -24, 1, -204)
listFrame.Position = UDim2.fromOffset(12, 124)
listFrame.BackgroundColor3 = Color3.fromRGB(248, 250, 253)
listFrame.BorderSizePixel = 0
listFrame.ScrollingDirection = Enum.ScrollingDirection.Y
listFrame.ScrollBarThickness = 6
listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
listFrame.ZIndex = 6
listFrame.Parent = panel
local listCorner = Instance.new("UICorner")
listCorner.CornerRadius = UDim.new(0, 8)
listCorner.Parent = listFrame
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 2)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = listFrame

-- "Your Rank" footer
local meFooter = Instance.new("Frame")
meFooter.Size = UDim2.new(1, -24, 0, 56)
meFooter.Position = UDim2.new(0, 12, 1, -68)
meFooter.BackgroundColor3 = DUTCH_BLUE
meFooter.BorderSizePixel = 0
meFooter.ZIndex = 6
meFooter.Parent = panel
local meCorner = Instance.new("UICorner")
meCorner.CornerRadius = UDim.new(0, 8)
meCorner.Parent = meFooter
local meRankLbl = Instance.new("TextLabel")
meRankLbl.Size = UDim2.new(0, 80, 1, 0)
meRankLbl.Position = UDim2.fromOffset(12, 0)
meRankLbl.BackgroundTransparency = 1
meRankLbl.Text = "—"
meRankLbl.Font = Enum.Font.GothamBlack
meRankLbl.TextSize = 22
meRankLbl.TextColor3 = TIP_GOLD
meRankLbl.TextXAlignment = Enum.TextXAlignment.Left
meRankLbl.ZIndex = 7
meRankLbl.Parent = meFooter
local meNameLbl = Instance.new("TextLabel")
meNameLbl.Size = UDim2.new(1, -240, 1, 0)
meNameLbl.Position = UDim2.fromOffset(96, 0)
meNameLbl.BackgroundTransparency = 1
meNameLbl.Text = "You · " .. player.Name
meNameLbl.Font = Enum.Font.GothamBold
meNameLbl.TextSize = 16
meNameLbl.TextColor3 = WHITE
meNameLbl.TextXAlignment = Enum.TextXAlignment.Left
meNameLbl.ZIndex = 7
meNameLbl.Parent = meFooter
local meScoreLbl = Instance.new("TextLabel")
meScoreLbl.AnchorPoint = Vector2.new(1, 0)
meScoreLbl.Size = UDim2.new(0, 140, 1, 0)
meScoreLbl.Position = UDim2.new(1, -12, 0, 0)
meScoreLbl.BackgroundTransparency = 1
meScoreLbl.Text = "—"
meScoreLbl.Font = Enum.Font.GothamBlack
meScoreLbl.TextSize = 18
meScoreLbl.TextColor3 = WHITE
meScoreLbl.TextXAlignment = Enum.TextXAlignment.Right
meScoreLbl.ZIndex = 7
meScoreLbl.Parent = meFooter

-- ============================================================
-- Render helpers
-- ============================================================
local activeCategory = "Tips"

local function rankColor(rank)
    if rank == 1 then return RANK_GOLD end
    if rank == 2 then return RANK_SILVER end
    if rank == 3 then return RANK_BRONZE end
    return Color3.fromRGB(120, 120, 130)
end

local function clearList()
    for _, child in ipairs(listFrame:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end
end

local function makeRow(entry, suffix, idx)
    local isMe = entry.userId == player.UserId
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundColor3 = isMe and ME_HIGHLIGHT or (idx % 2 == 0 and ROW_ALT or ROW_BG)
    row.BorderSizePixel = 0
    row.LayoutOrder = idx
    row.ZIndex = 7
    row.Parent = listFrame

    local rankLbl = Instance.new("TextLabel")
    rankLbl.Size = UDim2.fromOffset(60, 1)
    rankLbl.Size = UDim2.new(0, 60, 1, 0)
    rankLbl.Position = UDim2.fromOffset(8, 0)
    rankLbl.BackgroundTransparency = 1
    rankLbl.Text = "#" .. tostring(entry.rank)
    rankLbl.Font = Enum.Font.GothamBlack
    rankLbl.TextSize = 16
    rankLbl.TextColor3 = isMe and WHITE or rankColor(entry.rank)
    rankLbl.TextXAlignment = Enum.TextXAlignment.Left
    rankLbl.ZIndex = 8
    rankLbl.Parent = row

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, -200, 1, 0)
    nameLbl.Position = UDim2.fromOffset(72, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = entry.username .. (isMe and "  (you)" or "")
    nameLbl.Font = isMe and Enum.Font.GothamBlack or Enum.Font.GothamSemibold
    nameLbl.TextSize = 14
    nameLbl.TextColor3 = isMe and WHITE or BLACK
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
    nameLbl.ZIndex = 8
    nameLbl.Parent = row

    local scoreLbl = Instance.new("TextLabel")
    scoreLbl.AnchorPoint = Vector2.new(1, 0)
    scoreLbl.Size = UDim2.new(0, 120, 1, 0)
    scoreLbl.Position = UDim2.new(1, -10, 0, 0)
    scoreLbl.BackgroundTransparency = 1
    scoreLbl.Text = tostring(entry.score) .. (suffix or "")
    scoreLbl.Font = Enum.Font.GothamBold
    scoreLbl.TextSize = 14
    scoreLbl.TextColor3 = isMe and WHITE or BLACK
    scoreLbl.TextXAlignment = Enum.TextXAlignment.Right
    scoreLbl.ZIndex = 8
    scoreLbl.Parent = row
end

local function refreshList()
    clearList()
    local categoryDef
    for _, def in ipairs(CATEGORIES) do
        if def.key == activeCategory then categoryDef = def; break end
    end
    if not categoryDef then return end

    local ok, top = pcall(function() return LeaderboardQuery:InvokeServer("top", activeCategory, 100) end)
    if not ok or type(top) ~= "table" then top = {} end
    for i, entry in ipairs(top) do makeRow(entry, categoryDef.suffix, i) end

    local rankOk, rankInfo = pcall(function() return LeaderboardQuery:InvokeServer("rank", activeCategory) end)
    if rankOk and type(rankInfo) == "table" then
        local rank, score = rankInfo.rank or -1, rankInfo.score or 0
        meRankLbl.Text = (rank > 0) and ("#" .. rank) or "100+"
        meScoreLbl.Text = tostring(score) .. (categoryDef.suffix or "")
    else
        meRankLbl.Text = "—"
        meScoreLbl.Text = "—"
    end
end

local function makeTabButton(idx, def)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1/#CATEGORIES, -4, 1, 0)
    b.LayoutOrder = idx
    b.BackgroundColor3 = (def.key == activeCategory) and DUTCH_BLUE or Color3.fromRGB(220, 222, 230)
    b.BorderSizePixel = 0
    b.Text = def.label
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    b.TextColor3 = (def.key == activeCategory) and WHITE or Color3.fromRGB(80, 80, 90)
    b.AutoButtonColor = true
    b.ZIndex = 7
    b.Parent = tabBar
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = b
    b.MouseButton1Click:Connect(function()
        activeCategory = def.key
        for _, btn in ipairs(tabButtons) do
            local matches = (btn.LayoutOrder == idx)
            btn.BackgroundColor3 = matches and DUTCH_BLUE or Color3.fromRGB(220, 222, 230)
            btn.TextColor3 = matches and WHITE or Color3.fromRGB(80, 80, 90)
        end
        refreshList()
    end)
    return b
end

for i, def in ipairs(CATEGORIES) do
    table.insert(tabButtons, makeTabButton(i, def))
end

refreshBtn = makeHeaderButton("RefreshBtn", -92, "↻  REFRESH", DUTCH_ORANGE, refreshList)

-- ============================================================
-- Open / close
-- ============================================================
local isOpen = false
local function openLeaderboard()
    if isOpen then return end
    isOpen = true
    screenGui.Enabled = true
    panel.Position = PANEL_HIDDEN_X
    backdrop.BackgroundTransparency = 1
    TweenService:Create(backdrop, TweenInfo.new(0.18), {BackgroundTransparency = 0.5}):Play()
    TweenService:Create(panel, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = PANEL_VISIBLE_X}):Play()
    refreshList()
end

local function closeLeaderboard()
    if not isOpen then return end
    isOpen = false
    TweenService:Create(backdrop, TweenInfo.new(0.18), {BackgroundTransparency = 1}):Play()
    TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = PANEL_HIDDEN_X}):Play()
    task.delay(0.2, function()
        if not isOpen then screenGui.Enabled = false end
    end)
end

backdrop.MouseButton1Click:Connect(closeLeaderboard)

_G.OpenLeaderboard = openLeaderboard
_G.CloseLeaderboard = closeLeaderboard
_G.ToggleLeaderboard = function()
    if isOpen then closeLeaderboard() else openLeaderboard() end
end

-- L key on PC
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.L then
        _G.ToggleLeaderboard()
    end
end)
