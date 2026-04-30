-- MerchCatalog.lua
-- Master database of Dutch Bros cosmetic merch. Visual-only: no gameplay effects, no pay-to-win.
-- Used by both client (MerchShopUI) and server (EconomyManager validates purchases).

local MerchCatalog = {}

MerchCatalog.Categories = {
    TOPS = "Tops",
    HEADWEAR = "Headwear",
    BOTTOMS = "Bottoms",
    FOOTWEAR = "Footwear",
    ACCESSORIES = "Accessories",
    SEASONAL = "Seasonal",
}

MerchCatalog.Rarities = {
    COMMON = "Common",
    UNCOMMON = "Uncommon",
    RARE = "Rare",
    EPIC = "Epic",
    LEGENDARY = "Legendary",
}

-- Slots map to PlayerData.equipped slots.
MerchCatalog.Slots = {
    SHIRT = "Shirt",
    PANTS = "Pants",
    HAT = "Hat",
    SHOES = "Shoes",
    ACCESSORY = "Accessory",
}

-- Item schema:
--   id (string), name, category, rarity, price (Bro Bucks), slot,
--   description, accessoryAssetId (Roblox Catalog asset; 0 = unassigned placeholder),
--   iconAssetId, seasonalMonth (optional, 1-12; only purchasable that month)
MerchCatalog.Items = {
    -- ===== TOPS (12) =====
    {id = "tee_classic_blue",     name = "Classic Blue Tee",     category = "Tops", rarity = "Common",    price = 50,   slot = "Shirt", accessoryAssetId = 0, iconAssetId = 0, description = "The OG. Goes with everything."},
    {id = "hoodie_windmill",      name = "Windmill Hoodie",      category = "Tops", rarity = "Uncommon",  price = 200,  slot = "Shirt", accessoryAssetId = 0, iconAssetId = 0, description = "Spinning windmill print on the back."},
    {id = "tee_bro_crew",         name = "Bro Crew Tee",         category = "Tops", rarity = "Common",    price = 75,   slot = "Shirt", accessoryAssetId = 0, iconAssetId = 0, description = "Soft cotton, soft vibes."},
    {id = "polo_stand_manager",   name = "Stand Manager Polo",   category = "Tops", rarity = "Rare",      price = 350,  slot = "Shirt", accessoryAssetId = 0, iconAssetId = 0, description = "Embroidered windmill. You're in charge now."},
    {id = "longsleeve_haul",      name = "Long-Haul Long Sleeve",category = "Tops", rarity = "Uncommon",  price = 175,  slot = "Shirt", accessoryAssetId = 0, iconAssetId = 0, description = "For early-morning drive-thru shifts."},
    {id = "tank_drive_thru",      name = "Drive-Thru Tank",      category = "Tops", rarity = "Common",    price = 60,   slot = "Shirt", accessoryAssetId = 0, iconAssetId = 0, description = "Sleeveless, breezy, ready."},
    {id = "raglan_rebel",         name = "Rebel Raglan",         category = "Tops", rarity = "Uncommon",  price = 150,  slot = "Shirt", accessoryAssetId = 0, iconAssetId = 0, description = "Blue Rebel splash on the chest."},
    {id = "tank_beach_day",       name = "Beach Day Tank",       category = "Tops", rarity = "Common",    price = 75,   slot = "Shirt", accessoryAssetId = 0, iconAssetId = 0, description = "Sun-faded blue, palm tree pocket."},
    {id = "jersey_gameday",       name = "Gameday Jersey",       category = "Tops", rarity = "Rare",      price = 400,  slot = "Shirt", accessoryAssetId = 0, iconAssetId = 0, description = "Mesh, numbered. Bro pride."},
    {id = "crewneck_brolight",    name = "Bro-Light Crewneck",   category = "Tops", rarity = "Uncommon",  price = 200,  slot = "Shirt", accessoryAssetId = 0, iconAssetId = 0, description = "Reflective trim — be seen on the late shift."},
    {id = "tee_sunset_stripe",    name = "Sunset Stripe Tee",    category = "Tops", rarity = "Common",    price = 80,   slot = "Shirt", accessoryAssetId = 0, iconAssetId = 0, description = "Horizontal sunset gradient."},
    {id = "tee_og_bro",           name = "OG Bro Tee",           category = "Tops", rarity = "Legendary", price = 1500, slot = "Shirt", accessoryAssetId = 0, iconAssetId = 0, description = "The first ever Dutch Bros tee. Vintage cut."},

    -- ===== HEADWEAR (10) =====
    {id = "hat_bro_snapback",     name = "Bro Snapback",         category = "Headwear", rarity = "Common",    price = 60,  slot = "Hat", accessoryAssetId = 0, iconAssetId = 0, description = "Flat brim, embroidered windmill."},
    {id = "hat_pom_beanie",       name = "Pom Beanie",           category = "Headwear", rarity = "Uncommon",  price = 175, slot = "Hat", accessoryAssetId = 0, iconAssetId = 0, description = "Fluffy pom on top."},
    {id = "hat_trucker",          name = "Trucker Cap",          category = "Headwear", rarity = "Common",    price = 70,  slot = "Hat", accessoryAssetId = 0, iconAssetId = 0, description = "Mesh back. Built for comfort."},
    {id = "hat_dad",              name = "Dad Hat",              category = "Headwear", rarity = "Common",    price = 65,  slot = "Hat", accessoryAssetId = 0, iconAssetId = 0, description = "Curved brim, low profile."},
    {id = "hat_bucket",           name = "Bucket of Bro",        category = "Headwear", rarity = "Uncommon",  price = 200, slot = "Hat", accessoryAssetId = 0, iconAssetId = 0, description = "Reversible, festival-ready."},
    {id = "hat_visor",            name = "Sun Visor",            category = "Headwear", rarity = "Common",    price = 50,  slot = "Hat", accessoryAssetId = 0, iconAssetId = 0, description = "Open-top, breezy."},
    {id = "hat_windmill_crown",   name = "Windmill Crown",       category = "Headwear", rarity = "Epic",      price = 800, slot = "Hat", accessoryAssetId = 0, iconAssetId = 0, description = "Slowly rotating windmill on top. Hypnotic."},
    {id = "hat_filter",           name = "Coffee Filter Hat",    category = "Headwear", rarity = "Rare",      price = 350, slot = "Hat", accessoryAssetId = 0, iconAssetId = 0, description = "It's a coffee filter. As a hat. We're not sorry."},
    {id = "hat_glow_phones",      name = "Glow Headphones",      category = "Headwear", rarity = "Rare",      price = 450, slot = "Hat", accessoryAssetId = 0, iconAssetId = 0, description = "RGB cans for the all-nighter shifts."},
    {id = "hat_galaxy_snap",      name = "Galaxy Snapback",      category = "Headwear", rarity = "Epic",      price = 750, slot = "Hat", accessoryAssetId = 0, iconAssetId = 0, description = "Animated nebula brim."},

    -- ===== BOTTOMS (6) =====
    {id = "pants_joggers",        name = "Bro Joggers",          category = "Bottoms",  rarity = "Uncommon",  price = 175, slot = "Pants", accessoryAssetId = 0, iconAssetId = 0, description = "Tapered, cuffed, comfy."},
    {id = "pants_stand_shorts",   name = "Stand Shorts",         category = "Bottoms",  rarity = "Common",    price = 75,  slot = "Pants", accessoryAssetId = 0, iconAssetId = 0, description = "Cargo-style, lots of pocket space."},
    {id = "pants_cozy_sweats",    name = "Cozy Sweats",          category = "Bottoms",  rarity = "Common",    price = 80,  slot = "Pants", accessoryAssetId = 0, iconAssetId = 0, description = "The off-shift uniform."},
    {id = "pants_drive_khaki",    name = "Drive-Thru Khakis",    category = "Bottoms",  rarity = "Uncommon",  price = 200, slot = "Pants", accessoryAssetId = 0, iconAssetId = 0, description = "Looks sharp on a window shift."},
    {id = "pants_rebel_cargo",    name = "Rebel Cargos",         category = "Bottoms",  rarity = "Rare",      price = 350, slot = "Pants", accessoryAssetId = 0, iconAssetId = 0, description = "Six pockets. Six. Pockets."},
    {id = "pants_galaxy_legs",    name = "Galaxy Leggings",      category = "Bottoms",  rarity = "Epic",      price = 700, slot = "Pants", accessoryAssetId = 0, iconAssetId = 0, description = "Animated star pattern."},

    -- ===== FOOTWEAR (6) =====
    {id = "shoes_slides",         name = "Bro Slides",           category = "Footwear", rarity = "Common",    price = 60,  slot = "Shoes", accessoryAssetId = 0, iconAssetId = 0, description = "Don't forget your socks."},
    {id = "shoes_stand_kicks",    name = "Stand Sneakers",       category = "Footwear", rarity = "Uncommon",  price = 200, slot = "Shoes", accessoryAssetId = 0, iconAssetId = 0, description = "Slip-resistant for syrup spills."},
    {id = "shoes_espresso_boot",  name = "Espresso Boots",       category = "Footwear", rarity = "Rare",      price = 400, slot = "Shoes", accessoryAssetId = 0, iconAssetId = 0, description = "Dark roast color, all-weather."},
    {id = "shoes_slippers",       name = "Cozy Slippers",        category = "Footwear", rarity = "Common",    price = 75,  slot = "Shoes", accessoryAssetId = 0, iconAssetId = 0, description = "Off-shift only. Maybe."},
    {id = "shoes_windmill_kicks", name = "Windmill Kicks",       category = "Footwear", rarity = "Epic",      price = 800, slot = "Shoes", accessoryAssetId = 0, iconAssetId = 0, description = "Spinning windmill on the heel."},
    {id = "shoes_glow_runners",   name = "Glow Sneakers",        category = "Footwear", rarity = "Rare",      price = 500, slot = "Shoes", accessoryAssetId = 0, iconAssetId = 0, description = "Soles glow when you walk."},

    -- ===== ACCESSORIES (10) =====
    {id = "acc_lanyard",          name = "Bro Lanyard",          category = "Accessories", rarity = "Common",   price = 40,  slot = "Accessory", accessoryAssetId = 0, iconAssetId = 0, description = "Holds your stand keys."},
    {id = "acc_pin_windmill",     name = "Windmill Pin",         category = "Accessories", rarity = "Common",   price = 30,  slot = "Accessory", accessoryAssetId = 0, iconAssetId = 0, description = "Tiny, mighty, iconic."},
    {id = "acc_bracelet",         name = "Bro Bracelet",         category = "Accessories", rarity = "Uncommon", price = 150, slot = "Accessory", accessoryAssetId = 0, iconAssetId = 0, description = "Braided cord, bro-blue accent."},
    {id = "acc_bean_necklace",    name = "Coffee Bean Necklace", category = "Accessories", rarity = "Uncommon", price = 175, slot = "Accessory", accessoryAssetId = 0, iconAssetId = 0, description = "Real-bean pendant. Smells faintly amazing."},
    {id = "acc_espresso_watch",   name = "Espresso Watch",       category = "Accessories", rarity = "Rare",     price = 400, slot = "Accessory", accessoryAssetId = 0, iconAssetId = 0, description = "Tracks your shots-pulled per shift."},
    {id = "acc_bro_backpack",     name = "Bro Backpack",         category = "Accessories", rarity = "Rare",     price = 450, slot = "Accessory", accessoryAssetId = 0, iconAssetId = 0, description = "Insulated drink pocket included."},
    {id = "acc_apron",            name = "Stand Apron",          category = "Accessories", rarity = "Uncommon", price = 200, slot = "Accessory", accessoryAssetId = 0, iconAssetId = 0, description = "Pockets, loops, syrup-stain-resistant."},
    {id = "acc_headset",          name = "Headset of the Day",   category = "Accessories", rarity = "Rare",     price = 350, slot = "Accessory", accessoryAssetId = 0, iconAssetId = 0, description = "Wireless. Crackles only sometimes."},
    {id = "acc_glasses",          name = "Bro Shades",           category = "Accessories", rarity = "Uncommon", price = 175, slot = "Accessory", accessoryAssetId = 0, iconAssetId = 0, description = "Polarized for sunset rushes."},
    {id = "acc_tip_jar_bag",      name = "Tip Jar Sidebag",      category = "Accessories", rarity = "Rare",     price = 400, slot = "Accessory", accessoryAssetId = 0, iconAssetId = 0, description = "Carry your tips in style."},

    -- ===== SEASONAL (8) =====
    {id = "seas_halloween_hood",  name = "Halloween Hoodie",     category = "Seasonal", rarity = "Epic",      price = 600,  slot = "Shirt",     accessoryAssetId = 0, iconAssetId = 0, seasonalMonth = 10, description = "Pumpkin windmill print. Spooky season only."},
    {id = "seas_reindeer_antlers",name = "Reindeer Antlers",     category = "Seasonal", rarity = "Epic",      price = 600,  slot = "Hat",       accessoryAssetId = 0, iconAssetId = 0, seasonalMonth = 12, description = "Light-up tips. December only."},
    {id = "seas_heartthrob_crop", name = "Heartthrob Crop",      category = "Seasonal", rarity = "Rare",      price = 400,  slot = "Shirt",     accessoryAssetId = 0, iconAssetId = 0, seasonalMonth = 2,  description = "All hearts, all February."},
    {id = "seas_clover_tee",      name = "Lucky Clover Tee",     category = "Seasonal", rarity = "Rare",      price = 350,  slot = "Shirt",     accessoryAssetId = 0, iconAssetId = 0, seasonalMonth = 3,  description = "Four-leaf clover hides a tiny bro logo."},
    {id = "seas_summer_survivor", name = "Summer Survivor Tank", category = "Seasonal", rarity = "Rare",      price = 400,  slot = "Shirt",     accessoryAssetId = 0, iconAssetId = 0, seasonalMonth = 6,  description = "Made it through the rush season."},
    {id = "seas_patriot_stripe",  name = "Patriotic Stripe",     category = "Seasonal", rarity = "Rare",      price = 400,  slot = "Shirt",     accessoryAssetId = 0, iconAssetId = 0, seasonalMonth = 7,  description = "Red, white, and Bro."},
    {id = "seas_pumpkin_card",    name = "Pumpkin Spice Cardi",  category = "Seasonal", rarity = "Epic",      price = 700,  slot = "Shirt",     accessoryAssetId = 0, iconAssetId = 0, seasonalMonth = 10, description = "Knit. Smells (visually) of pumpkin."},
    {id = "seas_galaxy_holiday",  name = "Galaxy Holiday Sweater",category= "Seasonal", rarity = "Legendary", price = 1500, slot = "Shirt",     accessoryAssetId = 0, iconAssetId = 0, seasonalMonth = 12, description = "Animated snow falls across a starfield. Once a year."},
}

-- Lazy id index
local idIndex = nil
local function buildIndex()
    if idIndex then return end
    idIndex = {}
    for _, item in ipairs(MerchCatalog.Items) do
        idIndex[item.id] = item
    end
end

function MerchCatalog.GetItem(id)
    buildIndex()
    return idIndex[id]
end

function MerchCatalog.GetByCategory(category)
    local list = {}
    for _, item in ipairs(MerchCatalog.Items) do
        if item.category == category then
            table.insert(list, item)
        end
    end
    return list
end

function MerchCatalog.GetAll()
    return MerchCatalog.Items
end

function MerchCatalog.IsValidItem(id)
    buildIndex()
    return idIndex[id] ~= nil
end

-- Returns true if a seasonal item is currently purchasable based on the server clock.
function MerchCatalog.IsAvailable(item, currentMonth)
    if not item then return false end
    if item.seasonalMonth then
        return item.seasonalMonth == (currentMonth or tonumber(os.date("!%m")))
    end
    return true
end

return MerchCatalog
