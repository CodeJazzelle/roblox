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
        syrups = {"Caramel", "Chocolate Macchiato"},
        toppings = {"Caramel Drizzle"},
        defaultSize = "Medium",
        basePrice = 5,
        category = "Coffee",
    },
    Annihilator = {
        displayName = "Annihilator",
        base = "Espresso",
        syrups = {"Chocolate Macchiato", "Macadamia Nut"},
        toppings = {},
        defaultSize = "Medium",
        basePrice = 5,
        category = "Coffee",
    },
    ["911"] = {
        displayName = "911",
        base = "Espresso",
        syrups = {"Irish Cream", "Half and Half"},
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
        syrups = {"Lime", "Pomegranate", "Strawberry"},
        toppings = {},
        defaultSize = "Medium",
        basePrice = 5,
        category = "Rebel",
    },
    SharkAttack = {
        displayName = "Shark Attack",
        base = "Blue Rebel",
        syrups = {"Coconut", "Blue Raspberry"},
        toppings = {},
        defaultSize = "Medium",
        basePrice = 5,
        category = "Rebel",
    },
    Aftershock = {
        displayName = "Aftershock",
        base = "Blue Rebel",
        syrups = {"Peach", "Strawberry", "Lime"},
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

DrinkRecipes.AllSyrups = {
    "Vanilla", "White Chocolate", "Chocolate", "Chocolate Macchiato",
    "Caramel", "Salted Caramel", "Hazelnut", "Almond",
    "Macadamia Nut", "Irish Cream", "Half and Half",
    "Peach", "Strawberry", "Raspberry", "Blue Raspberry",
    "Lime", "Pomegranate", "Coconut", "Lavender",
    "Watermelon", "Marshmallow", "Cotton Candy", "Gingerbread",
}

DrinkRecipes.AllToppings = {
    "Whipped Cream", "Soft Top", "Caramel Drizzle",
    "Chocolate Drizzle", "White Chocolate Drizzle",
    "Boba", "Cinnamon", "Sprinkles",
}

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
