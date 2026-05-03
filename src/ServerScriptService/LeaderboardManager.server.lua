-- LeaderboardManager.server.lua
-- Persistent global leaderboards via OrderedDataStore. Three categories:
--   * Tips    — total Bro Bucks tipped all-time
--   * Combo   — highest single-round combo achieved
--   * Drinks  — total drinks served all-time
--
-- Writes happen ONLY on RoundManager.EndRound (debounced — never per
-- drink) so we stay well under Roblox's 60-writes-per-minute-per-store
-- ceiling. Each write is wrapped in pcall — DataStore failures are
-- logged but never crash gameplay.
--
-- In Studio (PlaceId == 0 or RunService:IsStudio()) we never call
-- DataStore APIs — instead we serve a hardcoded MOCK_DATA table so the
-- leaderboard UI is testable without publishing.
--
-- Client interaction: the LeaderboardQuery RemoteFunction takes
-- ("top", category, count) or ("rank", category, userId) and returns
-- the result table. Created here on first run.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local IS_STUDIO = RunService:IsStudio() or game.PlaceId == 0

local LeaderboardManager = {}
LeaderboardManager.Categories = {
    Tips   = "TopBroistas_Tips",
    Combo  = "TopBroistas_Combo",
    Drinks = "TopBroistas_Drinks",
}
local CATEGORY_KEYS = {"Tips", "Combo", "Drinks"}

local stores = {}
if not IS_STUDIO then
    for cat, name in pairs(LeaderboardManager.Categories) do
        local ok, store = pcall(function() return DataStoreService:GetOrderedDataStore(name) end)
        if ok then stores[cat] = store end
    end
    print("[LeaderboardManager] OrderedDataStores ready")
else
    print("[LeaderboardManager] Studio detected — using MOCK_DATA, no DataStore writes")
end

-- Studio fallback: hardcoded fake players so the UI is testable.
local MOCK_DATA = {
    Tips = {
        {userId = 1001, username = "BroistaMax",     score = 4250},
        {userId = 1002, username = "CaffeineQueen",  score = 3890},
        {userId = 1003, username = "ShotPuller",     score = 3210},
        {userId = 1004, username = "SyrupSage",      score = 2900},
        {userId = 1005, username = "WindmillWayne",  score = 2540},
        {userId = 1006, username = "RebelRudy",      score = 2100},
        {userId = 1007, username = "FoamMaster",     score = 1850},
        {userId = 1008, username = "DriveThruDan",   score = 1610},
        {userId = 1009, username = "MochaMolly",     score = 1340},
        {userId = 1010, username = "LidLuther",      score = 1100},
    },
    Combo = {
        {userId = 1001, username = "BroistaMax",     score = 47},
        {userId = 1011, username = "FlowState",      score = 42},
        {userId = 1002, username = "CaffeineQueen",  score = 38},
        {userId = 1012, username = "ZenBarista",     score = 33},
        {userId = 1003, username = "ShotPuller",     score = 30},
        {userId = 1013, username = "ComboKid",       score = 28},
        {userId = 1004, username = "SyrupSage",      score = 25},
        {userId = 1014, username = "EspressoPete",   score = 22},
        {userId = 1015, username = "BobaBeth",       score = 20},
        {userId = 1005, username = "WindmillWayne",  score = 18},
    },
    Drinks = {
        {userId = 1001, username = "BroistaMax",     score = 1247},
        {userId = 1002, username = "CaffeineQueen",  score = 1108},
        {userId = 1003, username = "ShotPuller",     score = 962},
        {userId = 1016, username = "TipsterTilly",   score = 901},
        {userId = 1004, username = "SyrupSage",      score = 845},
        {userId = 1005, username = "WindmillWayne",  score = 778},
        {userId = 1017, username = "MorningMike",    score = 690},
        {userId = 1006, username = "RebelRudy",      score = 612},
        {userId = 1007, username = "FoamMaster",     score = 560},
        {userId = 1008, username = "DriveThruDan",   score = 487},
    },
}

-- ============================================================
-- Public API
-- ============================================================
function LeaderboardManager:UpdatePlayerScore(player, category, value)
    if IS_STUDIO then return end
    local store = stores[category]
    if not store or not value or value <= 0 then return end
    pcall(function()
        local current = store:GetAsync(tostring(player.UserId))
        if not current or value > current then
            store:SetAsync(tostring(player.UserId), value)
        end
    end)
end

function LeaderboardManager:GetTopPlayers(category, count)
    count = count or 100
    if IS_STUDIO then
        local list = MOCK_DATA[category] or {}
        local result = {}
        for i = 1, math.min(count, #list) do
            local e = list[i]
            table.insert(result, {userId = e.userId, username = e.username, score = e.score, rank = i})
        end
        return result
    end

    local store = stores[category]
    if not store then return {} end
    local result = {}
    local ok, pages = pcall(function() return store:GetSortedAsync(false, count) end)
    if not ok or not pages then return result end
    local data = pages:GetCurrentPage()
    for i, entry in ipairs(data) do
        local userId = tonumber(entry.key) or 0
        local username = "User" .. tostring(userId)
        pcall(function() username = Players:GetNameFromUserIdAsync(userId) end)
        table.insert(result, {userId = userId, username = username, score = entry.value, rank = i})
    end
    return result
end

function LeaderboardManager:GetPlayerRank(userId, category)
    if IS_STUDIO then
        local list = MOCK_DATA[category] or {}
        for i, e in ipairs(list) do
            if e.userId == userId then return i, e.score end
        end
        return -1, 0
    end

    local store = stores[category]
    if not store then return -1, 0 end
    -- OrderedDataStore has no native "rank of one player" — scan top 100
    -- and look for the userId. If outside top 100, return -1 with the
    -- player's stored score so the UI can show "100+" instead of a rank.
    local ok, pages = pcall(function() return store:GetSortedAsync(false, 100) end)
    if ok and pages then
        for i, entry in ipairs(pages:GetCurrentPage()) do
            if tonumber(entry.key) == userId then
                return i, entry.value
            end
        end
    end
    local _, score = pcall(function() return store:GetAsync(tostring(userId)) end)
    return -1, score or 0
end

-- ============================================================
-- RemoteFunction for client queries
-- ============================================================
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local query = Remotes:FindFirstChild("LeaderboardQuery")
if not query then
    query = Instance.new("RemoteFunction")
    query.Name = "LeaderboardQuery"
    query.Parent = Remotes
end

query.OnServerInvoke = function(player, op, category, arg)
    if op == "top" then
        return LeaderboardManager:GetTopPlayers(category, tonumber(arg) or 100)
    elseif op == "rank" then
        local rank, score = LeaderboardManager:GetPlayerRank(player.UserId, category)
        return {rank = rank, score = score}
    end
    return nil
end

-- ============================================================
-- Hook RoundManager.EndRound to push every present player's stats.
-- Single batch per round-end keeps DataStore writes well-bounded.
-- ============================================================
task.spawn(function()
    local RoundManager = require(script.Parent:WaitForChild("RoundManager"))
    local origEndRound = RoundManager.EndRound
    function RoundManager:EndRound(...)
        origEndRound(self, ...)
        -- After EndRound's existing logic, write each player's current
        -- profile stats to the leaderboards.
        for _, player in ipairs(Players:GetPlayers()) do
            local profile = PlayerData:Get(player)
            if profile then
                LeaderboardManager:UpdatePlayerScore(player, "Tips",   profile.totalTips or 0)
                LeaderboardManager:UpdatePlayerScore(player, "Combo",  profile.maxCombo or 0)
                LeaderboardManager:UpdatePlayerScore(player, "Drinks", profile.totalDrinks or 0)
            end
        end
    end
end)

-- Expose for other server scripts (e.g. wall display)
_G.LeaderboardManager = LeaderboardManager

return LeaderboardManager
