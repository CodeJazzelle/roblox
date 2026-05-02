-- MobileLabelFilter.client.lua
-- On phones, multiple station labels stack into an unreadable wall when
-- the player approaches the syrup wall. This script (mobile-only)
-- iterates every station BillboardGui every frame, finds the closest
-- station to the player, and disables every other label. Result: the
-- player only sees ONE label at a time, and it's always the one they're
-- about to interact with.
--
-- Also reduces every station-label BillboardGui to ~60% size so the
-- single visible label uses less screen real estate.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
if not isMobile then return end

local player = Players.LocalPlayer

-- Tags whose parts have a station BillboardGui that should be filtered.
-- HandoffWindow is intentionally excluded — it's a wayfinding label and
-- needs to stay visible across the room.
local STATION_TAGS = {
    "CupTower_Small", "CupTower_Medium", "CupTower_Large",
    "EspressoMachine", "RebelTap", "TeaBrewer",
    "LemonadeDispenser", "MilkSteamer",
    "SyrupPump", "ToppingStation",
    "LidStation", "SleeveStation", "TrashCan",
}

local NEAREST_RADIUS = 12   -- studs; outside this, hide everything

-- Cache: list of {part, gui} for fast per-frame iteration. Refreshed
-- whenever a tagged part is added (BuildStand spawns parts at runtime).
local entries = {}
local entriesById = {}  -- part → entry index

local function findGui(part)
    -- "StationLabel" is the name BuildStand's addLabel helper sets
    return part:FindFirstChild("StationLabel") or part:FindFirstChildOfClass("BillboardGui")
end

local function shrinkGui(gui)
    -- ~60% of original 240×76. Saves ~half the screen real estate per
    -- label without making text unreadable.
    gui.Size = UDim2.new(0, 144, 0, 46)
    -- Pull the label closer to the part since it's smaller now.
    gui.StudsOffset = Vector3.new(0, 3.5, 0)
end

local function addEntry(part)
    if not part:IsA("BasePart") then return end
    local gui = findGui(part)
    if not gui then return end
    if entriesById[part] then return end
    shrinkGui(gui)
    local entry = {part = part, gui = gui}
    table.insert(entries, entry)
    entriesById[part] = entry
end

for _, tag in ipairs(STATION_TAGS) do
    for _, part in ipairs(CollectionService:GetTagged(tag)) do
        addEntry(part)
    end
    CollectionService:GetInstanceAddedSignal(tag):Connect(addEntry)
end

-- Hide every NPC name BillboardGui on mobile entirely (cosmetic only;
-- gameplay doesn't need to see "Brad" floating over a pedestrian).
local function hideNPCLabel(gui)
    if gui:IsA("BillboardGui") then gui.Enabled = false end
end
for _, gui in ipairs(CollectionService:GetTagged("NPCNameLabel")) do
    hideNPCLabel(gui)
end
CollectionService:GetInstanceAddedSignal("NPCNameLabel"):Connect(hideNPCLabel)

-- Per-frame: pick the closest station within NEAREST_RADIUS, enable its
-- label, disable everyone else's. Iterating a couple-dozen parts per
-- frame is well within budget on phones.
RunService.RenderStepped:Connect(function()
    local character = player.Character
    if not character then
        for _, e in ipairs(entries) do e.gui.Enabled = false end
        return
    end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local origin = hrp.Position

    local nearest, nearestDist = nil, NEAREST_RADIUS
    for _, e in ipairs(entries) do
        if e.part.Parent then
            local d = (e.part.Position - origin).Magnitude
            if d < nearestDist then
                nearest = e
                nearestDist = d
            end
        end
    end

    for _, e in ipairs(entries) do
        e.gui.Enabled = (e == nearest)
    end
end)
