-- OrderManager.lua
-- Handles spawning customer orders and validating finished drinks.

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

local SECRET_CHANCE = 0.15

function OrderManager:StartRound(durationSeconds)
    self.RoundActive = true
    self.CurrentDifficulty = 1
    self.ActiveOrders = {}

    task.spawn(function()
        local startTime = tick()
        local nextSpawn = 0

        while self.RoundActive and (tick() - startTime) < durationSeconds do
            if tick() >= nextSpawn then
                self:SpawnOrder()
                local interval = math.max(4, 14 - self.CurrentDifficulty)
                nextSpawn = tick() + interval
            end

            self.CurrentDifficulty = 1 + math.floor((tick() - startTime) / 30)

            -- Per-order patience timeouts removed: orders persist for the
            -- full round. Only the main round timer matters. Orders leave
            -- the queue when the player completes them or when the round
            -- ends.

            task.wait(0.5)
        end

        self.RoundActive = false
    end)
end

function OrderManager:SpawnOrder()
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
        -- Tip was fixed at order spawn time via DrinkRecipes.GetTipForOrder.
        -- Recompute as a fallback for orders that predate the field.
        local tip = order.tip or DrinkRecipes.GetTipForOrder(order.recipe, order.isSecret)

        OrderCompleteEvent:FireAllClients(orderID, player.Name, tip)
        self.ActiveOrders[orderID] = nil
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
