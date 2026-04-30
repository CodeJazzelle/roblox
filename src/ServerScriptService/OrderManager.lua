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

            for orderID, order in pairs(self.ActiveOrders) do
                if tick() > order.expiresAt then
                    self:FailOrder(orderID, "Timeout")
                end
            end

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

    local patience = math.max(30, 75 - (self.CurrentDifficulty * 5))

    self.ActiveOrders[orderID] = {
        recipe = recipe,
        size = recipe.defaultSize,
        expiresAt = tick() + patience,
        isSecret = isSecret,
        drinkID = drinkID,
        spawnedAt = tick(),
    }

    NewOrderEvent:FireAllClients(orderID, {
        displayName = displayName,
        size = recipe.defaultSize,
        base = recipe.base,
        syrups = recipe.syrups,
        toppings = recipe.toppings,
        isSecret = isSecret,
        patience = patience,
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
        local timeBonus = math.max(0, (order.expiresAt - tick()) / 30)
        local tipMultiplier = order.isSecret and 2 or 1
        local tip = math.floor((order.recipe.basePrice + (timeBonus * 2)) * tipMultiplier)

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
