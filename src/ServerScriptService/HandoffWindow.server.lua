-- HandoffWindow.server.lua
-- Wires up parts tagged "HandoffWindow" to submit the player's lidded cup
-- against the OLDEST active order, then fires HandoffResult back to the
-- player so the client can show a popup + play a sound.
--
-- Cross-script glue: this script intentionally talks to StationInteraction
-- via the _G.GetPlayerCup / _G.ClearPlayerCup hooks rather than reaching into
-- its module table. OrderManager:SubmitDrink is monkey-patched in
-- RemotesSetup to award tips and Bro Bucks, so calling it here also fires
-- those side effects.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local OrderManager = require(script.Parent:WaitForChild("OrderManager"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local HandoffResult = Remotes:WaitForChild("HandoffResult")

local function setupWindow(part)
    local prompt = part:FindFirstChildOfClass("ProximityPrompt")
    if not prompt then
        prompt = Instance.new("ProximityPrompt")
        prompt.HoldDuration = 0.3
        prompt.MaxActivationDistance = 8
        prompt.ActionText = "Hand Off"
        prompt.ObjectText = "Drive-Thru Window"
        prompt.Parent = part
    end

    prompt.Triggered:Connect(function(player)
        local cup = _G.GetPlayerCup and _G.GetPlayerCup(player)
        if not cup then
            HandoffResult:FireClient(player, false, "No cup")
            return
        end
        if not cup.hasLid then
            HandoffResult:FireClient(player, false, "Add a lid first")
            return
        end

        local oldestId, oldestSpawn = nil, math.huge
        for id, order in pairs(OrderManager.ActiveOrders) do
            if order.spawnedAt < oldestSpawn then
                oldestId, oldestSpawn = id, order.spawnedAt
            end
        end
        if not oldestId then
            HandoffResult:FireClient(player, false, "No active orders")
            return
        end

        local success, payload = OrderManager:SubmitDrink(player, oldestId, cup:Serialize())
        if _G.ClearPlayerCup then _G.ClearPlayerCup(player) end
        HandoffResult:FireClient(player, success, payload)
    end)
end

for _, part in ipairs(CollectionService:GetTagged("HandoffWindow")) do
    setupWindow(part)
end
CollectionService:GetInstanceAddedSignal("HandoffWindow"):Connect(setupWindow)
