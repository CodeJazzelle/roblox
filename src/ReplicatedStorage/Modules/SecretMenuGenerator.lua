-- SecretMenuGenerator.lua
-- Builds randomized "secret menu" drinks with silly names.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DrinkRecipes = require(ReplicatedStorage.Modules.DrinkRecipes)

local SecretMenuGenerator = {}

local NAME_ADJECTIVES = {
    "Galaxy", "Sunset", "Midnight", "Rainbow", "Cosmic", "Thunder",
    "Velvet", "Electric", "Frosted", "Wild", "Mystic", "Dreamy",
    "Funky", "Spicy", "Royal", "Sneaky",
}

local NAME_NOUNS = {
    "Goblin", "Stampede", "Marshmallow", "Rumble", "Dragon", "Wave",
    "Kraken", "Blaze", "Tornado", "Phoenix", "Mirage", "Storm",
    "Bandit", "Comet", "Whisper", "Mango",
}

local BASES = {"Espresso", "Blue Rebel", "Tea", "Lemonade", "Milk"}

function SecretMenuGenerator.Generate()
    local base = BASES[math.random(1, #BASES)]
    local syrupCount = math.random(2, 4)
    local syrups = {}
    local syrupPool = table.clone(DrinkRecipes.AllSyrups)

    for _ = 1, syrupCount do
        if #syrupPool == 0 then break end
        local idx = math.random(1, #syrupPool)
        table.insert(syrups, syrupPool[idx])
        table.remove(syrupPool, idx)
    end

    local toppings = {}
    if math.random() < 0.6 then
        table.insert(toppings, DrinkRecipes.AllToppings[math.random(1, #DrinkRecipes.AllToppings)])
    end
    if math.random() < 0.3 then
        table.insert(toppings, "Boba")
    end

    local sizes = {"Small", "Medium", "Large"}
    local size = sizes[math.random(1, #sizes)]

    local name = "The " ..
        NAME_ADJECTIVES[math.random(1, #NAME_ADJECTIVES)] .. " " ..
        NAME_NOUNS[math.random(1, #NAME_NOUNS)]

    return {
        displayName = name,
        base = base,
        syrups = syrups,
        toppings = toppings,
        defaultSize = size,
        basePrice = 8,
        category = "Secret",
    }
end

return SecretMenuGenerator
