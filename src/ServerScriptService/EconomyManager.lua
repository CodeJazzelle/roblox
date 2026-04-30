-- EconomyManager.lua
-- Owns currency: tips -> Bro Bucks, merch purchases, server-authoritative validation.
-- All Bro Bucks transactions go through here so we have one place to log/audit if needed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local MerchCatalog = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MerchCatalog"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BuyMerchEvent = Remotes:WaitForChild("BuyMerch")
local PurchaseResultEvent = Remotes:WaitForChild("PurchaseResult")
local EquipItemEvent = Remotes:WaitForChild("EquipItem")
local EquipResultEvent = Remotes:WaitForChild("EquipResult")

local EconomyManager = {}

-- Conversion rate: 1 in-game tip credit = 1 Bro Buck (recipe basePrice is already in
-- Bro Bucks-equivalent units in DrinkRecipes.lua)
local TIP_TO_BB = 1

function EconomyManager:AwardTip(player, tipAmount)
    if not player or not tipAmount or tipAmount <= 0 then return end
    PlayerData:AddBroBucks(player, math.floor(tipAmount * TIP_TO_BB))
    PlayerData:AddXP(player, tipAmount)
end

function EconomyManager:DistributeTips(totalTips)
    -- End-of-round split: every player in the server gets an equal share of round tips
    local players = Players:GetPlayers()
    if #players == 0 or not totalTips or totalTips <= 0 then return end
    local share = math.floor(totalTips / #players)
    if share <= 0 then return end
    for _, player in ipairs(players) do
        PlayerData:AddBroBucks(player, share)
    end
end

function EconomyManager:Purchase(player, itemId)
    local item = MerchCatalog.GetItem(itemId)
    if not item then
        return false, "Unknown item"
    end
    if not MerchCatalog.IsAvailable(item) then
        return false, "Not currently available (seasonal)"
    end
    if PlayerData:OwnsMerch(player, itemId) then
        return false, "Already owned"
    end
    local profile = PlayerData:Get(player)
    if not profile then
        return false, "Profile not loaded"
    end
    if profile.broBucks < item.price then
        return false, "Not enough Bro Bucks"
    end
    PlayerData:AddBroBucks(player, -item.price)
    PlayerData:GrantMerch(player, itemId)
    return true, item.price
end

BuyMerchEvent.OnServerEvent:Connect(function(player, itemId)
    if type(itemId) ~= "string" then return end
    local success, payload = EconomyManager:Purchase(player, itemId)
    PurchaseResultEvent:FireClient(player, success, itemId, payload)
end)

EquipItemEvent.OnServerEvent:Connect(function(player, slot, itemId)
    if type(slot) ~= "string" then return end
    if itemId ~= nil and type(itemId) ~= "string" then return end
    local ok, reason = PlayerData:Equip(player, slot, itemId)
    EquipResultEvent:FireClient(player, ok, slot, itemId, reason)
end)

return EconomyManager
