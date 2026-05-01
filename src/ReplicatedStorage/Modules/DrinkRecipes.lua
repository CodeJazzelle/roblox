-- DrinkRecipes.lua
-- The master database of all Dutch Bros drinks.
-- Each recipe is order-independent for syrups/toppings (we sort before comparing).

local DrinkRecipes = {}

-- Bases
DrinkRecipes.Bases = {
    ESPRESSO = "Espresso",
    REBEL = "Blue Rebel",
    TEA = "Tea",
    LEMONADE = "Lemonade",
    MILK = "Milk",
    WATER = "Water",
}

-- Cup Sizes
DrinkRecipes.Sizes = {
    SMALL = "Small",
    MEDIUM = "Medium",
    LARGE = "Large",
}

-- All recipes. Each has: base, syrups (array), toppings (array), defaultSize, basePrice
DrinkRecipes.Menu = {
    -- ===== COFFEE =====
    Caramelizer = {
        displayName = "Caramelizer",
        base = "Espresso",
        -- Was Chocolate Macchiato; substituted to Chocolate (on the wall).
        syrups = {"Caramel", "Chocolate"},
        toppings = {"Caramel Drizzle"},
        defaultSize = "Medium",
        basePrice = 5,
        category = "Coffee",
    },
    Annihilator = {
        displayName = "Annihilator",
        base = "Espresso",
        -- Was Chocolate Macchiato; substituted to Chocolate (on the wall).
        syrups = {"Chocolate", "Macadamia Nut"},
        toppings = {},
        defaultSize = "Medium",
        basePrice = 5,
        category = "Coffee",
    },
    ["911"] = {
        displayName = "911",
        base = "Espresso",
        -- Was Irish Cream + Half and Half; Half and Half is a dairy
        -- mixer, not a syrup pump on the wall — dropped. The 6 extra
        -- shots still make this a Tier 4 ($10) order.
        syrups = {"Irish Cream"},
        toppings = {},
        defaultSize = "Large",
        basePrice = 6,
        category = "Coffee",
        extraShots = 6,
    },
    Kicker = {
        displayName = "Kicker",
        base = "Espresso",
        syrups = {"Irish Cream"},
        toppings = {},
        defaultSize = "Medium",
        basePrice = 5,
        category = "Coffee",
    },
    GoldenEagle = {
        displayName = "Golden Eagle",
        base = "Espresso",
        syrups = {"Vanilla", "Caramel"},
        toppings = {"Whipped Cream", "Caramel Drizzle"},
        defaultSize = "Medium",
        basePrice = 5,
        category = "Coffee",
    },
    WhiteMocha = {
        displayName = "White Mocha",
        base = "Espresso",
        syrups = {"White Chocolate"},
        toppings = {},
        defaultSize = "Medium",
        basePrice = 5,
        category = "Coffee",
    },
    PictureMocha = {
        displayName = "Picture Mocha",
        base = "Espresso",
        syrups = {"Chocolate", "Raspberry"},
        toppings = {"Whipped Cream"},
        defaultSize = "Medium",
        basePrice = 5,
        category = "Coffee",
    },
    Cocomo = {
        displayName = "Cocomo",
        base = "Espresso",
        syrups = {"Chocolate", "Macadamia Nut", "Coconut"},
        toppings = {},
        defaultSize = "Medium",
        basePrice = 5,
        category = "Coffee",
    },

    -- ===== BLUE REBEL =====
    OGGummybear = {
        displayName = "OG Gummybear",
        base = "Blue Rebel",
        -- Was Lime + Pomegranate + Strawberry; Lime + Pomegranate aren't
        -- on the wall, swapped to Coconut + Raspberry as closest fruit-y
        -- substitutes.
        syrups = {"Coconut", "Raspberry", "Strawberry"},
        toppings = {},
        defaultSize = "Medium",
        basePrice = 5,
        category = "Rebel",
    },
    SharkAttack = {
        displayName = "Shark Attack",
        base = "Blue Rebel",
        -- Was Blue Raspberry; only regular Raspberry is on the wall.
        syrups = {"Coconut", "Raspberry"},
        toppings = {},
        defaultSize = "Medium",
        basePrice = 5,
        category = "Rebel",
    },
    Aftershock = {
        displayName = "Aftershock",
        base = "Blue Rebel",
        -- Was Peach + Strawberry + Lime; Lime not on the wall, swapped
        -- for Coconut.
        syrups = {"Peach", "Strawberry", "Coconut"},
        toppings = {},
        defaultSize = "Medium",
        basePrice = 5,
        category = "Rebel",
    },
    PalmBeach = {
        displayName = "Palm Beach",
        base = "Blue Rebel",
        syrups = {"Peach", "Strawberry", "Coconut"},
        toppings = {},
        defaultSize = "Medium",
        basePrice = 5,
        category = "Rebel",
    },
    DutchMafia = {
        displayName = "Dutch Mafia",
        base = "Blue Rebel",
        syrups = {"White Chocolate", "Macadamia Nut"},
        toppings = {},
        defaultSize = "Medium",
        basePrice = 5,
        category = "Rebel",
    },

    -- ===== TEA / LEMONADE =====
    Lemonberry = {
        displayName = "Lemonberry",
        base = "Lemonade",
        syrups = {"Strawberry"},
        toppings = {},
        defaultSize = "Medium",
        basePrice = 4,
        category = "Refresher",
    },
    PeachTea = {
        displayName = "Peach Tea",
        base = "Tea",
        syrups = {"Peach"},
        toppings = {},
        defaultSize = "Medium",
        basePrice = 4,
        category = "Refresher",
    },
    SoftTopLemonade = {
        displayName = "Soft Top Lemonade",
        base = "Lemonade",
        syrups = {},
        toppings = {"Soft Top"},
        defaultSize = "Medium",
        basePrice = 4,
        category = "Refresher",
    },
}

-- Must match the 12 pumps placed on the back wall in BuildStand.server.lua.
-- Order is left-to-right along the wall.
DrinkRecipes.AllSyrups = {
    "Vanilla", "Caramel", "Chocolate", "White Chocolate",
    "Macadamia Nut", "Hazelnut", "Irish Cream", "Peach",
    "Strawberry", "Coconut", "Raspberry", "Salted Caramel",
}

DrinkRecipes.AllToppings = {
    "Whipped Cream", "Soft Top", "Caramel Drizzle",
    "Chocolate Drizzle", "White Chocolate Drizzle",
    "Boba", "Cinnamon", "Sprinkles",
}

-- Returns the base tip for a recipe based on complexity.
--   Tier 1 ($3): 0-1 syrups AND 0 toppings
--   Tier 2 ($5): 2 syrups OR 1 topping
--   Tier 3 ($7): 3+ syrups OR 2+ toppings
--   Tier 4 ($10): drinks with extra-shot requirements (the player has to
--                 track an extra step beyond the base recipe)
-- Secret-menu drinks pay a flat $15 — see GetTipForOrder.
function DrinkRecipes.GetTipTier(recipe)
    if not recipe then return 3 end
    local syrupCount = recipe.syrups and #recipe.syrups or 0
    local toppingCount = recipe.toppings and #recipe.toppings or 0
    local extraShots = recipe.extraShots or 0

    if extraShots > 0 then return 10 end
    if syrupCount >= 3 or toppingCount >= 2 then return 7 end
    if syrupCount >= 2 or toppingCount >= 1 then return 5 end
    return 3
end

-- Tip amount actually awarded for an order. Secret-menu drinks always pay
-- $15 (the highest tier) regardless of their generated complexity.
function DrinkRecipes.GetTipForOrder(recipe, isSecret)
    if isSecret then return 15 end
    return DrinkRecipes.GetTipTier(recipe)
end

function DrinkRecipes.GetRecipe(drinkID)
    return DrinkRecipes.Menu[drinkID]
end

function DrinkRecipes.GetAllRecipeIDs()
    local ids = {}
    for id, _ in pairs(DrinkRecipes.Menu) do
        table.insert(ids, id)
    end
    return ids
end

return DrinkRecipes
