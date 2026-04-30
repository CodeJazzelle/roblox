-- PlayerData.lua
-- Server-side DataStore wrapper for persistent player data: Bro Bucks, owned merch,
-- equipped slots, level/XP, achievements, lifetime stats.
--
-- Hooks PlayerAdded / PlayerRemoving on require, fires ProfileLoaded to the client,
-- auto-saves periodically and on game close.
--
-- Note: this is a basic DataStore implementation with retries but no cross-server
-- session locking. For production, consider swapping to ProfileService / Suphi
-- DataStore which handle session conflicts and reconciliation.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ProfileLoadedEvent = Remotes:WaitForChild("ProfileLoaded")
local BroBucksUpdatedEvent = Remotes:WaitForChild("BroBucksUpdated")

local PlayerData = {}
PlayerData.Profiles = {}

local STORE_NAME = "DutchBrosRush_PlayerData_v1"
local AUTOSAVE_INTERVAL = 60
local MAX_RETRIES = 3

-- DataStores are unavailable in Studio (and on unpublished places where PlaceId == 0),
-- so swap in an in-memory mock that mimics the GetAsync/SetAsync surface we use.
local IS_STUDIO = RunService:IsStudio() or game.PlaceId == 0

local store
if IS_STUDIO then
    print("[PlayerData] Studio detected — using in-memory mock DataStore (no persistence).")
    local mockData = {}
    store = {
        GetAsync = function(_, k)
            return mockData[k]
        end,
        SetAsync = function(_, k, v)
            mockData[k] = v
        end,
    }
else
    store = DataStoreService:GetDataStore(STORE_NAME)
end

local function defaultProfile()
    return {
        broBucks = 0,
        level = 1,
        xp = 0,
        ownedMerch = {},                -- [itemId] = true
        equipped = {                    -- slot -> itemId
            Shirt = nil,
            Pants = nil,
            Hat = nil,
            Shoes = nil,
            Accessory = nil,
            Hair = nil,
            Head = nil,
            Body = nil,
            Voice = nil,
        },
        achievements = {},              -- [achievementId] = true
        stats = {
            totalDrinksMade = 0,
            totalRoundsPlayed = 0,
            perfectRounds = 0,
            secretMenuOrders = 0,
        },
        lastLogin = 0,
        version = 1,
    }
end

local function key(userId)
    return "player_" .. tostring(userId)
end

local function safeLoad(userId)
    for attempt = 1, MAX_RETRIES do
        local ok, result = pcall(function()
            return store:GetAsync(key(userId))
        end)
        if ok then
            return result
        end
        warn(("[PlayerData] Load failed for %d (attempt %d): %s"):format(userId, attempt, tostring(result)))
        task.wait(2 ^ attempt)
    end
    return nil
end

local function safeSave(userId, data)
    for attempt = 1, MAX_RETRIES do
        local ok, err = pcall(function()
            store:SetAsync(key(userId), data)
        end)
        if ok then
            return true
        end
        warn(("[PlayerData] Save failed for %d (attempt %d): %s"):format(userId, attempt, tostring(err)))
        task.wait(2 ^ attempt)
    end
    return false
end

local function loadProfile(player)
    local raw = safeLoad(player.UserId)
    local profile = raw or defaultProfile()

    -- Backfill any new default fields onto older saved profiles
    local def = defaultProfile()
    for k, v in pairs(def) do
        if profile[k] == nil then profile[k] = v end
    end
    profile.lastLogin = os.time()
    PlayerData.Profiles[player] = profile

    ProfileLoadedEvent:FireClient(player, profile)
    return profile
end

local function saveProfile(player)
    local profile = PlayerData.Profiles[player]
    if not profile then return end
    safeSave(player.UserId, profile)
end

function PlayerData:Get(player)
    return self.Profiles[player]
end

function PlayerData:AddBroBucks(player, amount)
    local profile = self.Profiles[player]
    if not profile then return false end
    profile.broBucks = math.max(0, profile.broBucks + amount)
    BroBucksUpdatedEvent:FireClient(player, profile.broBucks)
    return true
end

function PlayerData:OwnsMerch(player, itemId)
    local profile = self.Profiles[player]
    if not profile then return false end
    return profile.ownedMerch[itemId] == true
end

function PlayerData:GrantMerch(player, itemId)
    local profile = self.Profiles[player]
    if not profile then return false end
    profile.ownedMerch[itemId] = true
    return true
end

function PlayerData:Equip(player, slot, itemId)
    local profile = self.Profiles[player]
    if not profile then return false, "No profile" end
    -- Allow nil to unequip
    if itemId ~= nil and not profile.ownedMerch[itemId] then
        return false, "Item not owned"
    end
    profile.equipped[slot] = itemId
    return true
end

function PlayerData:AddXP(player, amount)
    local profile = self.Profiles[player]
    if not profile then return end
    profile.xp += amount
    while profile.xp >= profile.level * 100 do
        profile.xp -= profile.level * 100
        profile.level += 1
    end
end

function PlayerData:GrantAchievement(player, achievementId)
    local profile = self.Profiles[player]
    if not profile then return false end
    if profile.achievements[achievementId] then return false end
    profile.achievements[achievementId] = true
    return true
end

function PlayerData:IncrementStat(player, statName, by)
    local profile = self.Profiles[player]
    if not profile or not profile.stats[statName] then return end
    profile.stats[statName] += (by or 1)
end

Players.PlayerAdded:Connect(loadProfile)
Players.PlayerRemoving:Connect(function(player)
    saveProfile(player)
    PlayerData.Profiles[player] = nil
end)

game:BindToClose(function()
    if IS_STUDIO then return end
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(saveProfile, player)
    end
    task.wait(3)
end)

task.spawn(function()
    while true do
        task.wait(AUTOSAVE_INTERVAL)
        for player, _ in pairs(PlayerData.Profiles) do
            task.spawn(saveProfile, player)
        end
    end
end)

return PlayerData
