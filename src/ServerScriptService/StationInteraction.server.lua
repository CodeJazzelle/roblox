-- StationInteraction.server.lua
-- Wires up all station ProximityPrompts to modify the cup the player is holding.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local CupState = require(ReplicatedStorage.Modules.CupState)

local PlayerCups = {}

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CupUpdatedEvent = Remotes:WaitForChild("CupUpdated")

local function getOrCreateCup(player, size)
    if not PlayerCups[player] then
        PlayerCups[player] = CupState.new(size or "Medium")
    end
    return PlayerCups[player]
end

local function syncCupToClient(player)
    local cup = PlayerCups[player]
    if cup then
        CupUpdatedEvent:FireClient(player, cup:Serialize())
    end
end

local function setupStation(stationPart, action)
    local prompt = stationPart:FindFirstChildOfClass("ProximityPrompt")
    if not prompt then
        prompt = Instance.new("ProximityPrompt")
        prompt.HoldDuration = 0.3
        prompt.MaxActivationDistance = 8
        prompt.Parent = stationPart
    end

    prompt.Triggered:Connect(function(player)
        action(player, stationPart)
        syncCupToClient(player)
    end)
end

for _, part in ipairs(CollectionService:GetTagged("CupTower_Small")) do
    setupStation(part, function(player) PlayerCups[player] = CupState.new("Small") end)
end
for _, part in ipairs(CollectionService:GetTagged("CupTower_Medium")) do
    setupStation(part, function(player) PlayerCups[player] = CupState.new("Medium") end)
end
for _, part in ipairs(CollectionService:GetTagged("CupTower_Large")) do
    setupStation(part, function(player) PlayerCups[player] = CupState.new("Large") end)
end

local baseStations = {
    EspressoMachine = "Espresso",
    RebelTap = "Blue Rebel",
    TeaBrewer = "Tea",
    LemonadeDispenser = "Lemonade",
    MilkSteamer = "Milk",
}
for tag, baseName in pairs(baseStations) do
    for _, part in ipairs(CollectionService:GetTagged(tag)) do
        setupStation(part, function(player)
            local cup = getOrCreateCup(player)
            cup:SetBase(baseName)
        end)
    end
end

for _, part in ipairs(CollectionService:GetTagged("SyrupPump")) do
    local syrupName = part:GetAttribute("SyrupName")
    if syrupName then
        setupStation(part, function(player)
            local cup = getOrCreateCup(player)
            cup:AddSyrup(syrupName)
        end)
    end
end

for _, part in ipairs(CollectionService:GetTagged("ToppingStation")) do
    local toppingName = part:GetAttribute("ToppingName")
    if toppingName then
        setupStation(part, function(player)
            local cup = getOrCreateCup(player)
            cup:AddTopping(toppingName)
        end)
    end
end

for _, part in ipairs(CollectionService:GetTagged("LidStation")) do
    setupStation(part, function(player)
        local cup = getOrCreateCup(player)
        cup:ApplyLid()
    end)
end

for _, part in ipairs(CollectionService:GetTagged("TrashCan")) do
    setupStation(part, function(player)
        PlayerCups[player] = nil
    end)
end

_G.GetPlayerCup = function(player) return PlayerCups[player] end
_G.ClearPlayerCup = function(player) PlayerCups[player] = nil end

Players.PlayerRemoving:Connect(function(player)
    PlayerCups[player] = nil
end)
