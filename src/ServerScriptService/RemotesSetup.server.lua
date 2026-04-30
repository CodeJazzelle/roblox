-- RemotesSetup.server.lua
-- Bootstrap script. Three jobs:
--   1. Create ReplicatedStorage.Remotes and every RemoteEvent the game uses, so any
--      WaitForChild calls in other scripts (server or client) resolve immediately.
--   2. Require server modules in dependency order. Each module hooks its own events
--      on require, so this is what kicks Phase 2 systems to life.
--   3. Wire the round lifecycle (StartRound / EndRound / SubmitDrink) into stage
--      rotation, hazard spawning, and tip distribution. Done here as wrappers so
--      Phase 1 modules (RoundManager, OrderManager) stay untouched.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTE_EVENTS = {
    -- Phase 1: orders, round, cup
    "NewOrder",
    "OrderComplete",
    "OrderFailed",
    "RoundStarted",
    "RoundEnded",
    "TipsUpdated",
    "CupUpdated",
    -- Phase 2: profile + economy
    "ProfileLoaded",
    "BroBucksUpdated",
    "BuyMerch",
    "PurchaseResult",
    "EquipItem",
    "EquipResult",
    -- Phase 2: social
    "PingPlaced",
    "PingBroadcast",
    "QuickChat",
    "QuickChatBroadcast",
    -- Phase 2: world
    "StageChanged",
    "HazardStarted",
    "HazardEnded",
    -- Phase 3: spawn flow
    "StartShift",
}

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
    remotesFolder = Instance.new("Folder")
    remotesFolder.Name = "Remotes"
    remotesFolder.Parent = ReplicatedStorage
end

for _, eventName in ipairs(REMOTE_EVENTS) do
    if not remotesFolder:FindFirstChild(eventName) then
        local event = Instance.new("RemoteEvent")
        event.Name = eventName
        event.Parent = remotesFolder
    end
end

-- ============================================================================
-- Server-side broadcast handlers for QuickChat + Pings.
-- Kept inline (3 lines each) instead of in their own files.
-- ============================================================================
remotesFolder.QuickChat.OnServerEvent:Connect(function(player, phrase)
    if type(phrase) ~= "string" or #phrase > 64 then return end
    remotesFolder.QuickChatBroadcast:FireAllClients(player.Name, phrase)
end)

remotesFolder.PingPlaced.OnServerEvent:Connect(function(player, position)
    if typeof(position) ~= "Vector3" then return end
    remotesFolder.PingBroadcast:FireAllClients(player.Name, position)
end)

-- ============================================================================
-- Require server modules (each hooks its own events on require).
-- Order matters: PlayerData -> EconomyManager (depends on PlayerData) ->
-- StageManager / HazardSpawner -> RoundManager (kicks off auto round loop) ->
-- OrderManager (already required transitively).
-- ============================================================================
local PlayerData      = require(script.Parent:WaitForChild("PlayerData"))
local EconomyManager  = require(script.Parent:WaitForChild("EconomyManager"))
local StageManager    = require(script.Parent:WaitForChild("StageManager"))
local HazardSpawner   = require(script.Parent:WaitForChild("HazardSpawner"))
local OrderManager    = require(script.Parent:WaitForChild("OrderManager"))
local RoundManager    = require(script.Parent:WaitForChild("RoundManager"))

-- ============================================================================
-- Wrap RoundManager:StartRound and :EndRound so each round picks a fresh
-- stage + hazards and end-of-round tips get split among the players.
-- We patch *after* require so the module's internal task.spawn loop will see
-- the wrapped versions on its first tick.
-- ============================================================================
local origStartRound = RoundManager.StartRound
function RoundManager:StartRound()
    StageManager:NewRound()
    HazardSpawner:StartRound()
    origStartRound(self)
end

local origEndRound = RoundManager.EndRound
function RoundManager:EndRound()
    HazardSpawner:StopRound()
    EconomyManager:DistributeTips(self.TotalTips)
    origEndRound(self)
end

-- ============================================================================
-- Wrap OrderManager:SubmitDrink so a successful submit awards Bro Bucks +
-- contributes to round tips automatically. Phase 1 OrderManager doesn't call
-- AddTip on its own, so we glue it here.
-- ============================================================================
local origSubmit = OrderManager.SubmitDrink
function OrderManager:SubmitDrink(player, orderID, cupData)
    local success, payload = origSubmit(self, player, orderID, cupData)
    if success and type(payload) == "number" then
        EconomyManager:AwardTip(player, payload)
        RoundManager:AddTip(payload)
        PlayerData:IncrementStat(player, "totalDrinksMade", 1)
    end
    return success, payload
end
