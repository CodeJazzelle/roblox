-- OrderManager.lua
-- Handles spawning customer orders and validating finished drinks.
--
-- Per-order timers removed for accessibility and shift-based scoring.
-- The only timer is the round timer. Orders persist for the entire
-- round and only leave the queue when the player completes them
-- (correctly served at the hand-off window) or when the round ends.
-- Wrong-drink submissions still fail the targeted order so the queue
-- card disappears; nothing else fails an order on its own.
--
-- Active order count is capped at MAX_ACTIVE_ORDERS to keep the queue
-- UI manageable. New orders past the cap are skipped until at least
-- one of the existing orders is completed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DrinkRecipes = require(ReplicatedStorage.Modules.DrinkRecipes)
local SecretMenuGenerator = require(ReplicatedStorage.Modules.SecretMenuGenerator)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local NewOrderEvent = Remotes:WaitForChild("NewOrder")
local OrderCompleteEvent = Remotes:WaitForChild("OrderComplete")
local OrderFailedEvent = Remotes:WaitForChild("OrderFailed")

local OrderManager = {}

OrderManager.ActiveOrders = {}
OrderManager.NextOrderID = 1
OrderManager.RoundActive = false
OrderManager.CurrentDifficulty = 1

-- Server-side signal fired when a drink is successfully submitted. Other
-- systems (DriveThruTraffic, NPCManager, etc.) connect to learn which
-- order finished so they can react (cars leave happy, NPCs cheer).
OrderManager.OrderCompleted = Instance.new("BindableEvent")

local SECRET_CHANCE = 0.15
local MAX_ACTIVE_ORDERS = 8

function OrderManager:StartRound(durationSeconds)
    self.RoundActive = true
    self.CurrentDifficulty = 1
    self.ActiveOrders = {}

    -- Difficulty rises with elapsed time; DriveThruTraffic / NPCManager
    -- read self.CurrentDifficulty to pace their spawn rates. We no longer
    -- spawn orders here — every order is driven by an arriving customer
    -- (car at the drive-thru, NPC at the walk-up window).
    task.spawn(function()
        local startTime = tick()
        while self.RoundActive and (tick() - startTime) < durationSeconds do
            self.CurrentDifficulty = 1 + math.floor((tick() - startTime) / 30)
            task.wait(1)
        end
        self.RoundActive = false
    end)
end

-- Returns the orderID so the caller (a customer system) can hold a
-- reference and know when their specific order completes.
function OrderManager:GetActiveOrderCount()
    local n = 0
    for _ in pairs(self.ActiveOrders) do n += 1 end
    return n
end

-- Round-end cleanup: clears every active order and dismisses the queue
-- cards client-side. This intentionally fires OrderFailedEvent (the
-- client uses it as a "remove card" signal) but does NOT route through
-- OrderManager:FailOrder, so no per-order failure consequences fire and
-- nothing affects player stats or any (future) combo system.
function OrderManager:ClearAllOrders(reason)
    for orderID in pairs(self.ActiveOrders) do
        OrderFailedEvent:FireAllClients(orderID, reason or "Round ended")
    end
    self.ActiveOrders = {}
end

function OrderManager:SpawnOrder()
    -- Honor the active-order cap. The caller (a customer system) can
    -- detect a nil return and skip-spawn the carrying car/NPC.
    if self:GetActiveOrderCount() >= MAX_ACTIVE_ORDERS then
        return nil
    end

    local orderID = self.NextOrderID
    self.NextOrderID += 1

    local isSecret = math.random() < SECRET_CHANCE
    local recipe, drinkID, displayName

    if isSecret then
        recipe = SecretMenuGenerator.Generate()
        drinkID = "SECRET_" .. orderID
        displayName = recipe.displayName
    else
        local allIDs = DrinkRecipes.GetAllRecipeIDs()
        drinkID = allIDs[math.random(1, #allIDs)]
        recipe = DrinkRecipes.GetRecipe(drinkID)
        displayName = recipe.displayName
    end

    -- Tier-based tip — fixed at order creation so the value displayed on
    -- the card matches what gets awarded on submit, regardless of how
    -- long the order sits in the queue.
    local tip = DrinkRecipes.GetTipForOrder(recipe, isSecret)

    self.ActiveOrders[orderID] = {
        recipe = recipe,
        size = recipe.defaultSize,
        isSecret = isSecret,
        drinkID = drinkID,
        spawnedAt = tick(),
        tip = tip,
    }

    NewOrderEvent:FireAllClients(orderID, {
        displayName = displayName,
        size = recipe.defaultSize,
        base = recipe.base,
        syrups = recipe.syrups,
        toppings = recipe.toppings,
        isSecret = isSecret,
        tip = tip,
        extraShots = recipe.extraShots,
    })
    return orderID
end

function OrderManager:SubmitDrink(player, orderID, cupData)
    local order = self.ActiveOrders[orderID]
    if not order then
        return false, "Order no longer exists"
    end

    local CupState = require(ReplicatedStorage.Modules.CupState)
    local cup = CupState.new(cupData.size)
    cup.base = cupData.base
    cup.syrups = cupData.syrups
    cup.toppings = cupData.toppings
    cup.hasLid = cupData.hasLid

    local success, accuracy, reason = cup:MatchesRecipe(order.recipe, order.size)

    if success then
        local tip = order.tip or DrinkRecipes.GetTipForOrder(order.recipe, order.isSecret)
        OrderCompleteEvent:FireAllClients(orderID, player.Name, tip)
        self.ActiveOrders[orderID] = nil
        -- Server-side signal: customer-system listeners (cars, NPCs) react.
        OrderManager.OrderCompleted:Fire(orderID, player, tip)
        return true, tip
    else
        OrderFailedEvent:FireAllClients(orderID, reason)
        self.ActiveOrders[orderID] = nil
        return false, reason
    end
end

function OrderManager:FailOrder(orderID, reason)
    OrderFailedEvent:FireAllClients(orderID, reason)
    self.ActiveOrders[orderID] = nil
end

return OrderManager
