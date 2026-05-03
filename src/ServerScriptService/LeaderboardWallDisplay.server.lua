-- LeaderboardWallDisplay.server.lua
-- Physical chalkboard-style leaderboard mounted on the back wall, above
-- the cup tower / base machines area. Shows the top 10 Tips earners,
-- refreshes every 30 seconds. Self-contained: builds its own part and
-- SurfaceGui, then polls LeaderboardManager.

local Workspace = game:GetService("Workspace")
local Players   = game:GetService("Players")

local LeaderboardManager = require(script.Parent:WaitForChild("LeaderboardManager"))

local DUTCH_BLUE   = Color3.fromRGB(0,   90,  171)
local DUTCH_ORANGE = Color3.fromRGB(255, 122, 0)
local DUTCH_YELLOW = Color3.fromRGB(255, 200, 50)
local CHALK_GREEN  = Color3.fromRGB(25,  35,  25)
local CREAM        = Color3.fromRGB(255, 244, 222)
local WHITE        = Color3.new(1, 1, 1)

-- ============================================================
-- Build the board (waits for BuildStand to finish so the back wall
-- exists and we can mount our part flush against it).
-- ============================================================
local stand = Workspace:WaitForChild("DutchBrosStand", 15)
if not stand then
    warn("[LeaderboardWall] DutchBrosStand not found — wall will not be built.")
    return
end

local board = Instance.new("Part")
board.Name = "LeaderboardWall"
board.Anchored = true
board.CanCollide = false
board.Size = Vector3.new(12, 8, 0.4)
-- Mount on the back wall (z = -BLD_D/2 = -20), centered on the bases area
-- (x = -15), well above eye level (y = 11) so it doesn't block the syrup
-- pumps or counter stations.
board.CFrame = CFrame.new(-15, 11, -19.2)
board.Color = CHALK_GREEN
board.Material = Enum.Material.Slate
board.TopSurface = Enum.SurfaceType.Smooth
board.BottomSurface = Enum.SurfaceType.Smooth
board.Parent = stand

local sg = Instance.new("SurfaceGui")
sg.Face = Enum.NormalId.Front
sg.LightInfluence = 0
sg.PixelsPerStud = 60
sg.Parent = board

local pad = Instance.new("Frame")
pad.Size = UDim2.fromScale(1, 1)
pad.BackgroundTransparency = 1
pad.Parent = sg

-- Header band
local header = Instance.new("TextLabel")
header.Size = UDim2.new(1, 0, 0.16, 0)
header.BackgroundTransparency = 1
header.Text = "🏆  LEGENDARY BROISTAS"
header.Font = Enum.Font.GothamBlack
header.TextScaled = true
header.TextColor3 = DUTCH_YELLOW
header.TextStrokeTransparency = 0.5
header.TextStrokeColor3 = DUTCH_BLUE
header.Parent = pad

-- Subtitle
local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, 0, 0.06, 0)
subtitle.Position = UDim2.new(0, 0, 0.16, 0)
subtitle.BackgroundTransparency = 1
subtitle.Text = "TOP TIPS · ALL-TIME"
subtitle.Font = Enum.Font.GothamSemibold
subtitle.TextScaled = true
subtitle.TextColor3 = CREAM
subtitle.Parent = pad

-- List area
local list = Instance.new("Frame")
list.Size = UDim2.new(1, -16, 0.74, -16)
list.Position = UDim2.new(0, 8, 0.24, 0)
list.BackgroundTransparency = 1
list.Parent = pad

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 4)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

local rowLabels = {}   -- index → TextLabel for live updates
for i = 1, 10 do
    local row = Instance.new("TextLabel")
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundTransparency = 1
    row.Text = ("#%d  ..."):format(i)
    row.Font = Enum.Font.Antique
    row.TextSize = 32
    row.TextXAlignment = Enum.TextXAlignment.Left
    row.TextColor3 = (i == 1) and DUTCH_YELLOW
        or (i == 2) and Color3.fromRGB(200, 210, 220)
        or (i == 3) and Color3.fromRGB(220, 160, 90)
        or CREAM
    row.LayoutOrder = i
    row.Parent = list
    rowLabels[i] = row
end

print("[LeaderboardWall] Mounted on back wall at (-15, 11, -19.2)")

-- ============================================================
-- Poll LeaderboardManager every 30s and refresh the rows.
-- Also refresh on PlayerAdded so a new player sees fresh data.
-- ============================================================
local function refresh()
    local top = LeaderboardManager:GetTopPlayers("Tips", 10)
    for i = 1, 10 do
        local entry = top[i]
        if entry then
            local username = entry.username or ("User" .. tostring(entry.userId))
            local score = entry.score or 0
            -- Truncate long usernames so the row fits on the chalkboard.
            if #username > 18 then username = username:sub(1, 18) .. "…" end
            rowLabels[i].Text = ("#%-2d  %-19s  %d BB"):format(i, username, score)
        else
            rowLabels[i].Text = ("#%-2d  ---"):format(i)
        end
    end
end

refresh()
task.spawn(function()
    while true do
        task.wait(30)
        refresh()
    end
end)
Players.PlayerAdded:Connect(function()
    -- Small delay so DataStore reads aren't slammed by every join.
    task.delay(2, refresh)
end)
