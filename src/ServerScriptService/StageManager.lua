-- StageManager.lua
-- Picks a stage variant + 0-2 chaos modifiers per round and broadcasts to clients.
-- Other systems (HazardSpawner, OrderManager, gameplay scripts) can query
-- StageManager:HasModifier("...") to alter their behavior.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local StageChangedEvent = Remotes:WaitForChild("StageChanged")

local StageManager = {}

StageManager.Stages = {
    {id = "ClassicStand",  name = "Classic Stand",   description = "The OG Dutch Bros stand. Your home base."},
    {id = "DriveThru",     name = "Drive-Thru",      description = "Cars stack up - keep that line moving."},
    {id = "FoodTruck",     name = "Food Truck",      description = "Tight quarters, festival vibes."},
    {id = "BeachPopUp",    name = "Beach Pop-Up",    description = "Sand, sun, and frozen Rebels."},
    {id = "WinterChalet",  name = "Winter Chalet",   description = "Cozy alpine cabin. Mind the snow."},
    {id = "RooftopBar",    name = "Rooftop Bar",     description = "Sunset shift. Watch the wind."},
}

StageManager.Modifiers = {
    {id = "BrokenPump",     name = "Broken Pump",      description = "One random syrup pump is jammed all round."},
    {id = "SlipperyFloor",  name = "Slippery Floor",   description = "Floor is wet - everyone slides on movement."},
    {id = "FastConveyor",   name = "Caffeinated Crew", description = "Walk speed +25%, customer patience halved."},
    {id = "FoggyWindows",   name = "Foggy Windows",    description = "Order tickets are slightly blurry."},
    {id = "NightShift",     name = "Night Shift",      description = "Lights dimmed, double tips on every drink."},
    {id = "DoubleDrinks",   name = "Combo Frenzy",     description = "Every order is a 2-drink combo."},
    {id = "GhostCustomer",  name = "Ghost Customer",   description = "Random orders disappear if not started in 10s."},
}

StageManager.ActiveStage = nil
StageManager.ActiveModifiers = {}

local function pickRandom(list)
    return list[math.random(1, #list)]
end

local function pickModifiers(count)
    local pool = table.clone(StageManager.Modifiers)
    local picked = {}
    for _ = 1, math.min(count, #pool) do
        local i = math.random(1, #pool)
        table.insert(picked, pool[i])
        table.remove(pool, i)
    end
    return picked
end

function StageManager:NewRound()
    self.ActiveStage = pickRandom(self.Stages)
    -- 0-2 modifiers, weighted toward 1 for moderate chaos
    local roll = math.random()
    local count = (roll < 0.25) and 0 or (roll < 0.85) and 1 or 2
    self.ActiveModifiers = pickModifiers(count)

    StageChangedEvent:FireAllClients({
        stage = self.ActiveStage,
        modifiers = self.ActiveModifiers,
    })
end

function StageManager:GetActiveStage()
    return self.ActiveStage
end

function StageManager:GetActiveModifiers()
    return self.ActiveModifiers
end

function StageManager:HasModifier(modifierId)
    for _, mod in ipairs(self.ActiveModifiers) do
        if mod.id == modifierId then return true end
    end
    return false
end

-- Set an initial stage at module load so other systems have something to query
-- before the first round starts.
StageManager:NewRound()

return StageManager
